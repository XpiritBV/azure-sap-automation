#!/usr/bin/env bash

. ${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/shared_functions.sh
. ${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/set-colors.sh

function check_deploy_inputs() {

    REQUIRED_VARS=(
        "CONFIG_REPO_PATH"
        "deployerfolder"
        "libraryfolder"
        "SAP_AUTOMATION_REPO_PATH"
        "ARM_SUBSCRIPTION_ID"
        "ARM_CLIENT_ID"
        "ARM_CLIENT_SECRET"
        "ARM_TENANT_ID"
    )

    case get_platform in
    github)
        REQUIRED_VARS+=("APP_TOKEN")
        REQUIRED_VARS+=("RUNNER_GROUP")
        ;;

    devops)
        REQUIRED_VARS+=("this_agent")
        REQUIRED_VARS+=("PAT")
        REQUIRED_VARS+=("POOL")
        REQUIRED_VARS+=("VARIABLE_GROUP_ID")
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
            echo "Missing required variable: ${var}"
        fi
    done

    return $success
}

start_group "Check all required inputs are set"
check_deploy_inputs
if [ $? == 0 ]; then
    echo "All required variables are set"
else
    exit_error "Missing required variables" 1
fi
end_group

set -euo pipefail

if [ -v TF_VAR_ansible_core_version ]; then
    export TF_VAR_ansible_core_version=2.15
fi

export TF_VAR_PLATFORM=$(get_platform)

export TF_VAR_use_webapp=${use_webapp}
storage_account_parameter=""

start_group "Setup deployer and library folders"
echo "Deploying the control plane defined in: ${deployerfolder} and ${libraryfolder}"
file_deployer_tfstate_key=${deployerfolder}.tfstate

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

if [[ ${force_reset,,} == "true" ]]; then # ,, = tolowercase
    start_group "Force reset"
    echo "Force reset: ${force_reset}"

    log_warning "Forcing a re-install"
    echo "running on ${this_agent}"
    set_config_key_with_value "step" "0"

    # TODO: Terraform should be platform agnostic and use the set methods for the environment: $(set_value_with_key)
    export REINSTALL_ACCOUNTNAME=$(get_value_with_key "Terraform_Remote_Storage_Account_Name")
    export REINSTALL_SUBSCRIPTION=$(get_value_with_key "Terraform_Remote_Storage_Subscription")
    export REINSTALL_RESOURCE_GROUP=$(get_value_with_key "Terraform_Remote_Storage_Resource_Group_Name")

    export FORCE_RESET=true
    var=$(get_value_with_key "Deployer_Key_Vault.value" | tr -d \")
    if [ -n "${var}" ]; then
        key_vault="${var}"
        echo 'Deployer Key Vault' ${key_vault}
    else
        echo "Reading key vault from environment file"
        key_vault=$(config_value_with_key "keyvault")
        echo 'Deployer Key Vault' ${key_vault}
    fi

    # az login --service-principal --username $ARM_CLIENT_ID --password=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none
    # return_code=$?
    # if [ 0 != $return_code ]; then
    #     echo -e "$boldred--- Login failed ---$reset"
    #     exit_error "az login failed." $return_code
    # fi

    key_vault_id=$(az resource list --name "${key_vault}" --resource-type Microsoft.KeyVault/vaults --query "[].id | [0]" -o tsv)
    export TF_VAR_deployer_kv_user_arm_id=${key_vault_id}
    if [ -n "${key_vault_id}" ]; then
        this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
        az keyvault network-rule add --name ${key_vault} --ip-address ${this_ip} --subscription ${Terraform_Remote_Storage_Subscription} --only-show-errors --output none
        ip_added=1
    fi

    tfstate_resource_id=$(az resource list --name ${Terraform_Remote_Storage_Account_Name} --subscription ${Terraform_Remote_Storage_Subscription} --resource-type Microsoft.Storage/storageAccounts --query "[].id | [0]" -o tsv)
    if [[ -v tfstate_resource_id ]]; then
        this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
        az storage account network-rule add --account-name ${Terraform_Remote_Storage_Account_Name} --resource-group ${Terraform_Remote_Storage_Resource_Group_Name} --ip-address ${this_ip} --only-show-errors --output none
    fi

    step=0
    end_group
else
    if [ -f ${deployer_environment_file_name} ]; then
        echo "Found environment file: ${deployer_environment_file_name}"
        cat ${deployer_environment_file_name}
        step=$(config_value_with_key "step")
        echo "Step: ${step}"
        if [ "0" != ${step} ]; then
            exit 0
        fi
    fi
fi

# TODO: Is this necessary on GitHub?
start_group "Update .sap_deployment_automation/config as SAP_AUTOMATION_REPO_PATH can change on devops agent"
echo "Current Directory: $(pwd)"
mkdir -p ${CONFIG_REPO_PATH}/.sap_deployment_automation
echo SAP_AUTOMATION_REPO_PATH=$SAP_AUTOMATION_REPO_PATH >${CONFIG_REPO_PATH}/.sap_deployment_automation/config
end_group
start_group "File Validations"
if [ ! -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} ]; then
    exit_error "File ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} was not found." 2
else
    echo "Deployer Config File found: ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig}"
fi
if [ ! -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} ]; then
    exit_error "File ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} was not found." 2
else
    echo "Library Config File found: ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}"
fi
end_group

start_group "Configure parameters"
echo -e "$green--- Convert config files to UX format ---$reset"
dos2unix -q ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig}
dos2unix -q ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}
echo -e "$green--- Configuring variables ---$reset"
deployer_environment_file_name=$CONFIG_REPO_PATH/.sap_deployment_automation/${ENVIRONMENT}$LOCATION
end_group
start_group "Deployment"
#echo -e "$green--- az login ---$reset"
#az login --service-principal --username $ARM_CLIENT_ID --password=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none
# return_code=$?
# if [ 0 != $return_code ]; then
#     echo -e "$boldred--- Login failed ---$reset"
#     exit_error "az login failed." $return_code
# fi
#az account set --subscription $ARM_SUBSCRIPTION_ID
echo -e "$green--- Deploy the Control Plane ---$reset"

if [[ -v PAT ]]; then
    echo 'Deployer Agent PAT is defined'
fi
if [[ -v POOL ]]; then
    echo 'Deployer Agent Pool' ${POOL}
    POOL_NAME=$(az pipelines pool list --organization ${System_CollectionUri} --query "[?name=='${POOL}'].name | [0]")
    if [ ${#POOL_NAME} -eq 0 ]; then
        log_warning "Agent Pool ${POOL} does not exist." 2
    fi
    echo "Deployer Agent Pool found: $POOL_NAME"
    export TF_VAR_agent_pool=${POOL}
    export TF_VAR_agent_pat=${PAT}
fi

if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip ]; then
    pass=$(echo $ARM_CLIENT_SECRET | sed 's/-//g')
    # TODO: unzip with password is unsecure, use PGP Encrypt
    unzip -qq -o -P "${pass}" ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip -d ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}
fi

if [[ ${use_webapp,,} == "true" ]]; then # ,, = tolowercase
    echo "Use WebApp is selected"

    export TF_VAR_app_registration_app_id=${APP_REGISTRATION_APP_ID}
    echo "App Registration App ID: ${TF_VAR_app_registration_app_id}"
    export TF_VAR_webapp_client_secret=${WEB_APP_CLIENT_SECRET}
    export TF_VAR_use_webapp=true
fi

touch ${CONFIG_REPO_PATH}/.sap_deployment_automation/terraform.log
export TF_LOG_PATH=${CONFIG_REPO_PATH}/.sap_deployment_automation/terraform.log

set +eu

${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/deploy_controlplane.sh \
    --deployer_parameter_file ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} \
    --library_parameter_file ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} \
    --subscription $ARM_SUBSCRIPTION_ID --spn_id $ARM_CLIENT_ID \
    --spn_secret $ARM_CLIENT_SECRET --tenant_id $ARM_TENANT_ID \
    --auto-approve --only_deployer # TODO: --ado
return_code=$?
echo "Return code from deploy_controlplane $return_code."

set -euo pipefail

start_group "Update deployment configuration to repo"
cd $CONFIG_REPO_PATH
git pull -q

if [ -f ${deployer_environment_file_name} ]; then
    file_deployer_tfstate_key=$(config_value_with_key "deployer_tfstate_key")
    if [ -z "$file_deployer_tfstate_key" ]; then
        file_deployer_tfstate_key=${deployerfolder}/.terraform.tfstate
    fi
    echo "Deployer State File: $file_deployer_tfstate_key"

    file_key_vault=$(config_value_with_key "keyvault")
    echo "Deployer Key Vault: ${file_key_vault}"

    deployer_random_id=$(config_value_with_key "deployer_random_id")
    library_random_id=$(config_value_with_key "library_random_id")
fi

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION} ]; then
    git add .sap_deployment_automation/${ENVIRONMENT}${LOCATION}
fi

if [ -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate ]; then
    git add -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate
fi

if [ -f DEPLOYER/${deployerfolder}/terraform.tfstate ]; then
    pass=$(echo $ARM_CLIENT_SECRET | sed 's/-//g')
    # TODO: unzip with password is unsecure, use PGP Encrypt
    zip -j -P "${pass}" DEPLOYER/${deployerfolder}/state DEPLOYER/${deployerfolder}/terraform.tfstate
    git add -f DEPLOYER/${deployerfolder}/state.zip
fi

git diff --cached
git diff --cached --quiet
GIT_DIFF_RETURN_CODE=$?
if [ 1 == $GIT_DIFF_RETURN_CODE ]; then
    commit_changes
fi

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md ]; then
    upload_summary .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md
fi
end_group

start_group "Adding variables to platform variable group"
if [ 0 == $return_code ]; then
    set_value_with_key "Deployer_State_FileName" "${file_deployer_tfstate_key}"
    set_value_with_key "Deployer_Key_Vault" "${file_key_vault}"
    set_value_with_key "ControlPlaneEnvironment" "${ENVIRONMENT}"
    set_value_with_key "ControlPlaneLocation" "${LOCATION}"
fi
end_group
exit $return_code
