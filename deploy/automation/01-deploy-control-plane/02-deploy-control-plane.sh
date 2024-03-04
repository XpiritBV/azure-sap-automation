#!/usr/bin/env bash

. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/shared_functions.sh
. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/set-colors.sh

start_group "GitHub Context"
cat /tmp/github_context.json
echo "GITHUB_WORKSPACE: ${GITHUB_WORKSPACE}"
end_group

function check_required_inputs() {
    REQUIRED_VARS=(
        "CONFIG_REPO_PATH"
        "deployerconfig"
        "deployerfolder"
        "libraryconfig"
        "libraryfolder"
        "SAP_AUTOMATION_REPO_PATH"
        "CP_ARM_SUBSCRIPTION_ID"
        "CP_ARM_CLIENT_ID"
        "CP_ARM_CLIENT_SECRET"
        "CP_ARM_TENANT_ID"
    )

    success=0
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            success=1
            echo "Missing required variable: ${var}"
        fi
    done

    return $success
}

start_group "Check all required inputs are set"
check_required_inputs
if [ $? == 0 ]; then
    echo "All required variables are set"
else
    exit_error "Missing required variables" 1
fi
end_group

set -euo pipefail

start_group "Setup deployer and library folders"
echo "Deploying the control plane defined in: ${deployerfolder} and ${libraryfolder}"

ENVIRONMENT=$(echo ${deployerfolder} | awk -F'-' '{print $1}' | xargs)
echo Environment: ${ENVIRONMENT}
LOCATION=$(echo ${deployerfolder} | awk -F'-' '{print $2}' | xargs)
echo Location: ${LOCATION}
deployer_environment_file_name=${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}
echo "Deployer Environment File: ${deployer_environment_file_name}"
end_group

file_deployer_tfstate_key=${deployerfolder}.tfstate
file_key_vault=""
file_REMOTE_STATE_SA=""
file_REMOTE_STATE_RG=${deployerfolder}

start_group "Variables"
var=$(get_value_with_key "Deployer_Key_Vault" | tr -d \")
if [ -n "${var}" ]; then
    key_vault="${var}"
    echo 'Deployer Key Vault: ' ${key_vault}
else
    if [ -f ${deployer_environment_file_name} ]; then
        key_vault=$(config_value_with_key "keyvault")
        echo 'Deployer Key Vault: ' ${key_vault}
    fi
fi

var=$(get_value_with_key "Deployer_Terraform_Remote_Storage_Subscription" | tr -d \")
if [ -n "${var}" ]; then
    STATE_SUBSCRIPTION="${var}"
    echo 'Terraform state file subscription: ' $STATE_SUBSCRIPTION
else
    if [ -f ${deployer_environment_file_name} ]; then
        STATE_SUBSCRIPTION=$(config_value_with_key "STATE_SUBSCRIPTION")
        echo 'Terraform state file subscription: ' $STATE_SUBSCRIPTION
    fi
fi

var=$(get_value_with_key "Terraform_Remote_Storage_Account_Name.value" | tr -d \")
if [ -n "${var}" ]; then
    REMOTE_STATE_SA="${var}"
    echo 'Terraform state file storage account: ' $REMOTE_STATE_SA
else
    if [ -f ${deployer_environment_file_name} ]; then
        REMOTE_STATE_SA=$(config_value_with_key "REMOTE_STATE_SA")
        echo 'Terraform state file storage account: ' $REMOTE_STATE_SA
    fi
fi

storage_account_parameter=""
if [ -n "${REMOTE_STATE_SA}" ]; then
    storage_account_parameter="--storageaccountname ${REMOTE_STATE_SA}"
else
    set_config_key_with_value "step" "1"
fi

keyvault_parameter=""
if [ -n "${keyvault}" ]; then
    if [ "${keyvault}" != "${Deployer_Key_Vault}" ]; then
        keyvault_parameter=" --vault ${keyvault} "
    fi
fi
end_group

echo -e "$green--- Validations ---$reset"

if [[ ${use_webapp,,} == "true" ]]; then
    echo 'App Registration App ID' ${TF_VAR_app_registration_app_id}
    export TF_VAR_app_registration_app_id=${APP_REGISTRATION_APP_ID}
    export TF_VAR_webapp_client_secret=${WEB_APP_CLIENT_SECRET}
    export TF_VAR_use_webapp=true
fi

bootstrapped=0

if [ ! -f $deployer_environment_file_name ]; then
    var=$(get_value_with_key "Terraform_Remote_Storage_Account_Name")
    if [[ ${#var} -ne 0 ]]; then
        echo "REMOTE_STATE_SA="${var}
        set_config_key_with_value "REMOTE_STATE_SA" "${var}"
        set_config_key_with_value "STATE_SUBSCRIPTION" "${ARM_SUBSCRIPTION_ID}"
        set_config_key_with_value "step" "3"
    fi

    var=$(get_value_with_key "Terraform_Remote_Storage_Resource_Group_Name")
    if [[ ${#var} -ne 0 ]]; then
        echo "REMOTE_STATE_RG="${var}
        set_config_key_with_value "REMOTE_STATE_RG" "${var}"
    fi

    var=$(get_value_with_key "Deployer_State_FileName")
    if [[ ${#var} -ne 0 ]]; then
        set_config_key_with_value "deployer_tfstate_key" "${var}"
    fi

    var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "Deployer_Key_Vault.value")
    if [[ ${#var} -ne 0 ]]; then
        set_config_key_with_value "keyvault" "${var}"
        bootstrapped=1
    fi
fi

echo -e "$green--- Update .sap_deployment_automation/config as SAP_AUTOMATION_REPO_PATH can change on devops agent ---$reset"
cd ${CONFIG_REPO_PATH}
mkdir -p .sap_deployment_automation
echo SAP_AUTOMATION_REPO_PATH=$SAP_AUTOMATION_REPO_PATH >.sap_deployment_automation/config

echo -e "$green--- File Validations ---$reset"
if [ ! -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} ]; then
    echo -e "$boldred--- File ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} was not found ---$reset"
    echo "##vso[task.logissue type=error]File ${CONFIG_REPO_PATH}/${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} was not found."
    exit 2
fi

if [ ! -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} ]; then
    echo -e "$boldred--- File ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}  was not found ---$reset"
    echo "##vso[task.logissue type=error]File ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} was not found."
    exit 2
fi

# Check if running on deployer
if [[ ! -f /etc/profile.d/deploy_server.sh ]]; then
    echo -e "$green --- Install dos2unix ---$reset"
    sudo apt-get -qq install dos2unix

    sudo apt -qq install zip

    echo -e "$green --- Install terraform ---$reset"

    wget -q $(tf_url)
    return_code=$?
    if [ 0 != $return_code ]; then
        echo "##vso[task.logissue type=error]Unable to download Terraform version $(tf_version)."
        exit 2
    fi
    unzip -qq terraform_$(tf_version)_linux_amd64.zip
    sudo mv terraform /bin/
    rm -f terraform_$(tf_version)_linux_amd64.zip

    az extension add --name storage-blob-preview >/dev/null
    echo -e "$green--- az login ---$reset"
    az login --service-principal --username $CP_ARM_CLIENT_ID --password=$CP_ARM_CLIENT_SECRET --tenant $CP_ARM_TENANT_ID --output none
    return_code=$?
    if [ 0 != $return_code ]; then
        echo -e "$boldred--- Login failed ---$reset"
        echo "##vso[task.logissue type=error]az login failed."
        exit $return_code
    fi

    az account set --subscription $CP_ARM_SUBSCRIPTION_ID

else
    if [ $LOGON_USING_SPN == "true" ]; then
        echo "Login using SPN"
        export ARM_CLIENT_ID=$CP_ARM_CLIENT_ID
        export ARM_CLIENT_SECRET=$CP_ARM_CLIENT_SECRET
        export ARM_TENANT_ID=$CP_ARM_TENANT_ID
        export ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID
        export ARM_USE_MSI=false
        az login --service-principal --username $CP_ARM_CLIENT_ID --password=$CP_ARM_CLIENT_SECRET --tenant $CP_ARM_TENANT_ID --output none
        return_code=$?
        if [ 0 != $return_code ]; then
            echo -e "$boldred--- Login failed ---$reset"
            echo "##vso[task.logissue type=error]az login failed."
            exit $return_code
        fi
    else
        source /etc/profile.d/deploy_server.sh
    fi
fi

echo -e "$green--- Configure parameters ---$reset"

echo -e "$green--- Convert config files to UX format ---$reset"
dos2unix -q ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig}
dos2unix -q ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}

echo -e "$green--- Configuring variables ---$reset"

deployer_environment_file_name=${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}$LOCATION

export key_vault=""
ip_added=0

if [ -f ${deployer_environment_file_name} ]; then
    if [ 0 == $bootstrapped ]; then
        export key_vault=$(cat ${deployer_environment_file_name} | grep key_vault | awk -F'=' '{print $2}' | xargs)
        echo "Key Vault: $key_vault"
        if [ -n "${key_vault}" ]; then
            echo 'Deployer Key Vault' ${key_vault}
            key_vault_id=$(az resource list --name "${key_vault}" --resource-type Microsoft.KeyVault/vaults --query "[].id | [0]" -o tsv)
            if [ -n "${key_vault_id}" ]; then

                if [ "azure pipelines" = "$(this_agent)" ]; then
                    this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
                    az keyvault network-rule add --name ${key_vault} --ip-address ${this_ip} --only-show-errors --output none
                    ip_added=1
                fi
            fi
        fi
    fi
fi

echo -e "$green--- Deploy the Control Plane ---$reset"

if [ -n $(PAT) ]; then
    echo 'Deployer Agent PAT is defined'
fi

if [ -n $(POOL) ]; then
    echo 'Deployer Agent Pool' $(POOL)
    POOL_NAME=$(az pipelines pool list --query "[?name=='$(POOL)'].name | [0]")

    if [ ${#POOL_NAME} -eq 0 ]; then
        echo "##vso[task.logissue type=warning]Agent Pool $TF_VAR_agent_pool does not exist."
    fi

    export TF_VAR_agent_pool=$(POOL)
    export TF_VAR_agent_pat=$(PAT)

fi

if [ -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state.zip ]; then
    pass=$(echo $CP_ARM_CLIENT_SECRET | sed 's/-//g')
    unzip -qq -o -P "${pass}" ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state.zip -d ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}
fi

if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip ]; then
    pass=$(echo $CP_ARM_CLIENT_SECRET | sed 's/-//g')
    unzip -qq -o -P "${pass}" ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip -d ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}
fi

export TF_LOG_PATH=${CONFIG_REPO_PATH}/.sap_deployment_automation/terraform.log

export TF_VAR_deployer_parameter_group_name=$(variable_group)
export TF_VAR_deployer_parameter_environment=${ENVIRONMENT}
export TF_VAR_deployer_parameter_location=${LOCATION}
export TF_VAR_deployer_tf_state_filename=$(basename "${deployerconfig}")

sudo chmod +x $SAP_AUTOMATION_REPO_PATH/deploy/scripts/deploy_controlplane.sh

$SAP_AUTOMATION_REPO_PATH/deploy/scripts/deploy_controlplane.sh \
    --deployer_parameter_file ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} \
    --library_parameter_file ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} \
    --subscription $CP_ARM_SUBSCRIPTION_ID --spn_id $CP_ARM_CLIENT_ID \
    --spn_secret $CP_ARM_CLIENT_SECRET --tenant_id $CP_ARM_TENANT_ID \
    --auto-approve --ado \
    ${storage_account_parameter} ${keyvault_parameter}
return_code=$?

if [ 0 != $return_code ]; then
    echo "##vso[task.logissue type=error]Return code from deploy_controlplane $return_code."
    if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.err ]; then
        error_message=$(cat .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.err)
        echo "##vso[task.logissue type=error]Error message: $error_message."
    fi
fi

start_group "Adding deployment automation configuration to git repository"

cd ${CONFIG_REPO_PATH}
git fetch -q --all
git pull -q

if [ -f ${deployer_environment_file_name} ]; then
    file_deployer_tfstate_key=$(config_value_with_key "deployer_tfstate_key")
    echo 'Deployer State File' $file_deployer_tfstate_key

    file_key_vault=$(config_value_with_key "keyvault")
    echo 'Deployer Key Vault' ${file_key_vault}

    file_REMOTE_STATE_SA=$(config_value_with_key "REMOTE_STATE_SA")
    echo 'Terraform state file storage account' $file_REMOTE_STATE_SA

    file_REMOTE_STATE_RG=$(config_value_with_key "REMOTE_STATE_RG")
    echo 'Terraform state file resource group' $file_REMOTE_STATE_RG
fi

echo -e "$green--- Update repo ---$reset"
if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION} ]; then
    git add .sap_deployment_automation/${ENVIRONMENT}${LOCATION}
fi

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md ]; then
    git add .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md
fi

if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate ]; then
    git add -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate
fi

backend=$(jq '.backend.type' -r ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate)
if [ -n "${backend}" ]; then
    echo "Local Terraform state"
    if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate ]; then
        sudo apt install zip
        echo "Compressing the deployer state file"
        pass=$(echo $CP_ARM_CLIENT_SECRET | sed 's/-//g')
        zip -j -P "${pass}" ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate
        git add -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip
    fi
else
    echo "Remote Terraform state"
    if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate ]; then
        git rm -q --ignore-unmatch -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate
    fi
    if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip ]; then
        git rm -q --ignore-unmatch -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip
    fi
fi

backend=$(jq '.backend.type' -r ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/.terraform/terraform.tfstate)
if [ -n "${backend}" ]; then
    echo "Local Terraform state"
    if [ -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/terraform.tfstate ]; then
        sudo apt install zip
        echo "Compressing the library state file"
        pass=$(echo $CP_ARM_CLIENT_SECRET | sed 's/-//g')
        zip -j -P "${pass}" ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/terraform.tfstate
        git add -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state.zip
    fi
else
    echo "Remote Terraform state"
    if [ -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/terraform.tfstate ]; then
        git rm -q -f --ignore-unmatch ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/terraform.tfstate
    fi
    if [ -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state.zip ]; then
        git rm -q --ignore-unmatch -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state.zip
    fi
fi

if [ -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/.terraform/terraform.tfstate ]; then
    git add -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/.terraform/terraform.tfstate
fi

set +e
git diff --cached --quiet
git_diff_return_code=$?
set -e
if [ 1 == $git_diff_return_code ]; then
    commit_changes "Updated control plane deployment configuration."
fi

if [ -f ${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md ]; then
    echo "##vso[task.uploadsummary]${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md"
fi

if [ 0 == $return_code ]; then
    start_group "Saving variables"
    set_value_with_key "Terraform_Remote_Storage_Account_Name"
    set_value_with_key "Terraform_Remote_Storage_Resource_Group_Name"
    set_value_with_key "Terraform_Remote_Storage_Subscription"
    set_value_with_key "Deployer_State_FileName"
    set_value_with_key "Deployer_Key_Vault"
    set_value_with_key "ControlPlaneEnvironment"
    set_value_with_key "ControlPlaneLocation"
    end_group
fi
exit $return_code
