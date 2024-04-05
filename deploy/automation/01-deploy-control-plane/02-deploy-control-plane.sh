#!/usr/bin/env bash

. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/shared_functions.sh
. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/set-colors.sh

function check_required_inputs() {
    REQUIRED_VARS=(
        "deployerconfig"
        "deployerfolder"
        "libraryconfig"
        "libraryfolder"
        "SAP_AUTOMATION_REPO_PATH"
        "ARM_SUBSCRIPTION_ID"
        "ARM_CLIENT_ID"
        "ARM_CLIENT_SECRET"
        "ARM_TENANT_ID"
    )

    case $(get_platform) in
    github)
        REQUIRED_VARS+=("APP_TOKEN")
        ;;

    devops)
        REQUIRED_VARS+=("CONFIG_REPO_PATH")
        # REQUIRED_VARS+=("this_agent")
        # REQUIRED_VARS+=("PAT")
        # REQUIRED_VARS+=("POOL")
        # REQUIRED_VARS+=("VARIABLE_GROUP_ID")
        ;;

    *) ;;
    esac

    if [[ ${use_webapp,,} == "true" ]]; then
        REQUIRED_VARS+=("APP_REGISTRATION_APP_ID")
        REQUIRED_VARS+=("WEB_APP_CLIENT_SECRET")
    fi

    success=0
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            success=1
            log_warning "Missing required variable: ${var}"
        fi
    done

    return $success
}

if [[ $(get_platform) = github ]]; then
    export CONFIG_REPO_PATH=${GITHUB_WORKSPACE}/WORKSPACES
fi

start_group "Check all required inputs are set"
check_required_inputs
if [ $? == 0 ]; then
    echo "All required variables are set"
else
    exit_error "Missing required variables" 1
fi
end_group

set -euo pipefail

export USE_MSI=false
export VARIABLE_GROUP_ID=${deployerfolder}

cd ${CONFIG_REPO_PATH}

start_group "Setup deployer and library folders"
echo "Deploying the control plane defined in: ${deployerfolder} and ${libraryfolder}"

ENVIRONMENT=$(echo ${deployerfolder} | awk -F'-' '{print $1}' | xargs)
echo Environment: ${ENVIRONMENT}
LOCATION=$(echo ${deployerfolder} | awk -F'-' '{print $2}' | xargs)
echo Location: ${LOCATION}
deployer_environment_file_name=${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}
echo "Deployer Environment File: ${deployer_environment_file_name}"
end_group

start_group "Setup platform dependencies"
# Will return vars which we need to export afterwards
eval "$(setup_dependencies | sed 's/^/export /')"
end_group

file_deployer_tfstate_key=${deployerfolder}.tfstate
# file_key_vault=""
# file_REMOTE_STATE_SA=""
# file_REMOTE_STATE_RG=${deployerfolder}

start_group "Variables"
var=$(get_value_with_key "Deployer_Key_Vault")
if [ -n "${var}" ]; then
    key_vault="${var}"
    echo 'Deployer Key Vault: ' ${key_vault}
else
    if [ -f ${deployer_environment_file_name} ]; then
        key_vault=$(config_value_with_key "keyvault")
        echo 'Deployer Key Vault: ' ${key_vault}
    fi
fi

var=$(get_value_with_key "Terraform_Remote_Storage_Subscription")
if [ -n "${var}" ]; then
    STATE_SUBSCRIPTION="${var}"
    echo 'Terraform state file subscription: ' $STATE_SUBSCRIPTION
else
    if [ -f ${deployer_environment_file_name} ]; then
        STATE_SUBSCRIPTION=$(config_value_with_key "STATE_SUBSCRIPTION")
        echo 'Terraform state file subscription: ' $STATE_SUBSCRIPTION
    fi
fi

var=$(get_value_with_key "Terraform_Remote_Storage_Account_Name")
if [ -n "${var}" ]; then
    REMOTE_STATE_SA="${var}"
    echo 'Terraform state file storage account: ' $REMOTE_STATE_SA
else
    if [ -f ${deployer_environment_file_name} ]; then
        REMOTE_STATE_SA=$(config_value_with_key "REMOTE_STATE_SA")
        echo 'Terraform state file storage account: ' $REMOTE_STATE_SA
    else
        REMOTE_STATE_SA=""
    fi
fi

storage_account_parameter=""
if [ -n "${REMOTE_STATE_SA}" ]; then
    storage_account_parameter="--storageaccountname ${REMOTE_STATE_SA}"
else
    set_config_key_with_value "step" "1"
fi

# TODO: Why?
# keyvault_parameter=""
# if [ -n "${keyvault}" ]; then
#     if [ "${keyvault}" != "${Deployer_Key_Vault}" ]; then
#         keyvault_parameter=" --vault ${keyvault} "
#     fi
# fi
end_group

start_group "Validations"

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

echo -e "$green--- Update .sap_deployment_automation/config as SAP_AUTOMATION_REPO_PATH can change on devops agent ---$resetformatting"
mkdir -p .sap_deployment_automation
echo SAP_AUTOMATION_REPO_PATH=${SAP_AUTOMATION_REPO_PATH} > .sap_deployment_automation/config

echo -e "$green--- File Validations ---$resetformatting"
if [ ! -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} ]; then
    echo -e "$boldred--- File ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} was not found ---$resetformatting"
    exit_error "File ${CONFIG_REPO_PATH}/${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} was not found." 2
fi

if [ ! -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} ]; then
    echo -e "$boldred--- File ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}  was not found ---$resetformatting"
    exit_error "File ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} was not found." 2
fi

# Check if running on deployer
if [[ ! -f /etc/profile.d/deploy_server.sh ]]; then
    echo -e "$green--- az login ---$resetformatting"
    az login --service-principal --username $ARM_CLIENT_ID --password=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none
    return_code=$?
    if [ 0 != $return_code ]; then
        echo -e "$boldred--- Login failed ---$resetformatting"
        exit_error "az login failed." $return_code
    fi
    az account set --subscription $ARM_SUBSCRIPTION_ID
else
    if [ $USE_MSI != "true" ]; then
        echo -e "$cyan--- Using SPN ---$resetformatting"
        export ARM_USE_MSI=false
        az login --service-principal --username $ARM_CLIENT_ID --password=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none

        return_code=$?
        if [ 0 != $return_code ]; then
            echo -e "$boldred--- Login failed ---$resetformatting"
            exit_error "az login failed." $return_code
            exit $return_code
        fi
        az account set --subscription $ARM_SUBSCRIPTION_ID
    else
        echo -e "$cyan--- Using MSI ---$resetformatting"
        source /etc/profile.d/deploy_server.sh
        unset ARM_TENANT_ID
        export ARM_USE_MSI=true
    fi
fi

start_group "Configure parameters"
echo -e "$green--- Convert config files to UX format ---$resetformatting"
dos2unix -q ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig}
dos2unix -q ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}
echo -e "$green--- Configuring variables ---$resetformatting"
deployer_environment_file_name=${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}$LOCATION
end_group

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

start_group "Set Terraform variables"
export TF_VAR_PLATFORM=$(get_platform)

if [[ ${use_webapp,,} == "true" ]]; then # ,, = tolowercase
    echo "Use WebApp is selected"
    export TF_VAR_app_registration_app_id=${APP_REGISTRATION_APP_ID}
    echo 'App Registration App ID' ${TF_VAR_app_registration_app_id}
    export TF_VAR_webapp_client_secret=${WEB_APP_CLIENT_SECRET}
    export TF_VAR_use_webapp=true
fi

if [[ $(get_platform) = devops ]]; then
    if [[ -v PAT ]]; then
        echo "Deployer Agent PAT is defined"
    fi
    if [[ -v POOL ]]; then
        echo "Deployer Agent Pool: " ${POOL}
        POOL_NAME=$(az pipelines pool list --organization ${System_CollectionUri} --query "[?name=='${POOL}'].name | [0]")
        if [ ${#POOL_NAME} -eq 0 ]; then
            log_warning "Agent Pool ${POOL} does not exist."
        fi
        echo "Deployer Agent Pool found: ${POOL_NAME}"
        export TF_VAR_agent_pool=${POOL}
        export TF_VAR_agent_pat=${PAT}
    fi
elif [[ $(get_platform) = github ]]; then
    export TF_VAR_SERVER_URL=${GITHUB_SERVER_URL}
    export TF_VAR_API_URL=${GITHUB_API_URL}
    export TF_VAR_REPOSITORY=${GITHUB_REPOSITORY}
    export TF_VAR_APP_TOKEN=${APP_TOKEN}
fi
end_group

start_group "Decrypting state files"
if [ -f ${CONFIG_REPO_PATH}/private.pgp ]; then
    set +e
    gpg --list-keys sap-azure-deployer@example.com
    return_code=$?
    set -e

    if [ ${return_code} != 0 ]; then
        echo ${ARM_CLIENT_SECRET} | gpg --batch --passphrase-fd 0 --import ${CONFIG_REPO_PATH}/private.pgp
    fi
else
    exit_error "Private PGP key not found." 3
fi

git pull -q

if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.gpg ]; then
    echo "Decrypting deployer state file"
    echo ${ARM_CLIENT_SECRET} | \
        gpg --batch \
        --passphrase-fd 0 \
        --output ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate \
        --decrypt ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.gpg
fi

if [ -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state.gpg ]; then
    echo "Decrypting library state file"
    echo ${ARM_CLIENT_SECRET} | \
        gpg --batch \
        --passphrase-fd 0 \
        --output ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/terraform.tfstate \
        --decrypt ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/state.gpg
fi
end_group

start_group "Deploy the Control Plane"

set +eu

if [ "$USE_MSI" = "true" ]; then
    echo -e "$cyan--- Using MSI ---$resetformatting"
    ${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/deploy_controlplane.sh \
        --deployer_parameter_file ${CONFIG_REPO_PATH}/DEPLOYER/$(deployerfolder)/$(deployerconfig) \
        --library_parameter_file ${CONFIG_REPO_PATH}/LIBRARY/$(libraryfolder)/$(libraryconfig) \
        --subscription $STATE_SUBSCRIPTION \
        --auto-approve \
        --msi \
        ${storage_account_parameter} ${keyvault_parameter} # TODO: --ado
else
    echo -e "$cyan--- Using SPN ---$resetformatting"
    ${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/deploy_controlplane.sh \
        --deployer_parameter_file ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} \
        --library_parameter_file ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} \
        --subscription $STATE_SUBSCRIPTION \
        --spn_id $ARM_CLIENT_ID \
        --spn_secret $ARM_CLIENT_SECRET \
        --tenant_id $ARM_TENANT_ID \
        --auto-approve \
        ${storage_account_parameter} ${keyvault_parameter} # TODO: --ado
fi

return_code=$?
echo "Return code from deploy_controlplane $return_code."

set -euo pipefail

if [ 0 != $return_code ]; then
    if [ -f ${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}.err ]; then
        error_message=$(cat ${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}.err)
        exit_error "Error message: $error_message." $return_code
    fi
fi
end_group

start_group "Adding deployment automation configuration to git repository"

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION} ]; then
    git add .sap_deployment_automation/${ENVIRONMENT}${LOCATION}
fi

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md ]; then
    git add .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md
fi

if [ -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate ]; then
    git add -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate
fi

backend=$(jq '.backend.type' -r DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate)
if [ "local" == "${backend}" ]; then
    echo "Local deployer Terraform state"
    if [ -f DEPLOYER/${deployerfolder}/terraform.tfstate ]; then
        rm DEPLOYER/${deployerfolder}/state.gpg || true

        gpg --batch \
            --output DEPLOYER/${deployerfolder}/state.gpg \
            --encrypt \
            --disable-dirmngr\
            --recipient sap-azure-deployer@example.com \
            --trust-model always \
            DEPLOYER/${deployerfolder}/terraform.tfstate
        git add -f DEPLOYER/${deployerfolder}/state.gpg
        if [ -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate ]; then
            git add -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate
        fi
    fi
elif [ "azurerm" == "${backend}" ]; then
    echo "Remote deployer Terraform state"
    if [ -f DEPLOYER/${deployerfolder}/terraform.tfstate ]; then
        git rm -q --ignore-unmatch -f DEPLOYER/${deployerfolder}/terraform.tfstate
    fi
    if [ -f DEPLOYER/${deployerfolder}/state.gpg ]; then
        git rm -q --ignore-unmatch -f DEPLOYER/${deployerfolder}/state.gpg
    fi
else
    exit_error "Unknown backend type: ${backend}" 4
fi

if [ -f LIBRARY/${libraryfolder}/.terraform/terraform.tfstate ]; then
    git add -f LIBRARY/${libraryfolder}/.terraform/terraform.tfstate
fi
backend=$(jq '.backend.type' -r LIBRARY/${libraryfolder}/.terraform/terraform.tfstate)
if [ "local" == "${backend}" ]; then
    echo "Local library Terraform state"
    if [ -f LIBRARY/${libraryfolder}/terraform.tfstate ]; then
        rm LIBRARY/${libraryfolder}/state.gpg || true

        gpg --batch \
            --output LIBRARY/${libraryfolder}/state.gpg \
            --encrypt \
            --disable-dirmngr\
            --recipient sap-azure-deployer@example.com \
            --trust-model always \
            LIBRARY/${libraryfolder}/terraform.tfstate
        git add -f LIBRARY/${libraryfolder}/state.gpg
    fi
elif [ "azurerm" == "${backend}" ]; then
    echo "Remote library Terraform state"
    if [ -f LIBRARY/${libraryfolder}/terraform.tfstate ]; then
        git rm -q -f --ignore-unmatch LIBRARY/${libraryfolder}/terraform.tfstate
    fi
    if [ -f LIBRARY/${libraryfolder}/state.gpg ]; then
        git rm -q --ignore-unmatch -f LIBRARY/${libraryfolder}/state.gpg
    fi
else
    exit_error "Unknown backend type: ${backend}" 4
fi

set +e
git diff --cached --quiet
git_diff_return_code=$?
set -e
if [ 1 == $git_diff_return_code ]; then
    commit_changes "Updated control plane deployment configuration."
fi

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md ]; then
    upload_summary ".sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md"
fi
end_group

exit $return_code
