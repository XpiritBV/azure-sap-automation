#!/usr/bin/env bash

. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/shared_functions.sh
. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/set-colors.sh

function check_deploy_inputs() {

    REQUIRED_VARS=(
        "deployerfolder"
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
            log_warning "Missing required variable: ${var}"
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

export USE_MSI=false
export VARIABLE_GROUP_ID=${deployerfolder}

if [[ $(get_platform) = github ]]; then
    export CONFIG_REPO_PATH=${GITHUB_WORKSPACE}/WORKSPACES
fi

cd ${CONFIG_REPO_PATH}

storage_account_parameter=""

start_group "Setup deployer and library folders"
echo "Deploying the control plane defined in: ${deployerfolder} and ${libraryfolder}"
ENVIRONMENT=$(echo ${deployerfolder} | awk -F'-' '{print $1}' | xargs)
echo Environment: ${ENVIRONMENT}
LOCATION=$(echo ${deployerfolder} | awk -F'-' '{print $2}' | xargs)
echo Location: ${LOCATION}

mkdir -p ${CONFIG_REPO_PATH}/.sap_deployment_automation
deployer_environment_file_name=${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}
echo "Deployer Environment File: ${deployer_environment_file_name}"
end_group

file_deployer_tfstate_key=${deployerfolder}.tfstate

start_group "Setup platform dependencies"
# Will return vars which we need to export afterwards
eval "$(setup_dependencies | sed 's/^/export /')"
end_group

if [[ ${force_reset,,} == "true" ]]; then # ,, = tolowercase
    start_group "Force reset"
    log_warning "Forcing a re-install"
    set_config_key_with_value "step" "0"

    # TODO: Terraform should be platform agnostic and use the set methods for the environment: $(set_value_with_key)
    export REINSTALL_ACCOUNTNAME=$(get_value_with_key "Terraform_Remote_Storage_Account_Name")
    export REINSTALL_SUBSCRIPTION=$(get_value_with_key "Terraform_Remote_Storage_Subscription")
    export REINSTALL_RESOURCE_GROUP=$(get_value_with_key "Terraform_Remote_Storage_Resource_Group_Name")

    export FORCE_RESET=true

    echo "Try reading key vault from GitHub Environment"
    var=$(get_value_with_key "Deployer_Key_Vault")
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
    #     echo -e "$boldred--- Login failed ---$resetformatting"
    #     exit_error "az login failed." $return_code
    # fi

    set +e
    key_vault_id=$(az resource list --name "${key_vault}" --resource-type Microsoft.KeyVault/vaults --query "[].id | [0]" -o tsv)
    export TF_VAR_deployer_kv_user_arm_id=${key_vault_id}
    if [ -n "${key_vault_id}" ]; then
        this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
        az keyvault network-rule add --name ${key_vault} --ip-address ${this_ip} --subscription ${REINSTALL_SUBSCRIPTION} --only-show-errors --output none
        ip_added=1
    fi

    tfstate_resource_id=$(az resource list --name ${REINSTALL_ACCOUNTNAME} --subscription ${REINSTALL_SUBSCRIPTION} --resource-type Microsoft.Storage/storageAccounts --query "[].id | [0]" -o tsv)
    if [[ -v tfstate_resource_id ]]; then
        this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
        az storage account network-rule add --account-name ${REINSTALL_ACCOUNTNAME} --resource-group ${REINSTALL_RESOURCE_GROUP} --ip-address ${this_ip} --only-show-errors --output none
    fi
    set -e

    step=0
    end_group
else
    if [ -f ${deployer_environment_file_name} ]; then
        start_group "Check if we are finished"
        echo "Found Deployer Environment File: ${deployer_environment_file_name}"
        cat ${deployer_environment_file_name}
        step=$(config_value_with_key "step")
        echo "Step: ${step}"

        if [[ "0" != ${step} ]] && [[ "" != ${step} ]]; then
            log_warning "Step is not 0, so we are finished here."
            exit 0
        fi
        end_group
    fi
fi

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
echo -e "$green--- Convert config files to UX format ---$resetformatting"
dos2unix -q ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig}
dos2unix -q ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}
end_group

# echo -e "$green--- az login ---$resetformatting"
# az login --service-principal --username $ARM_CLIENT_ID --password=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none
# return_code=$?
# if [ 0 != $return_code ]; then
#     echo -e "$boldred--- Login failed ---$resetformatting"
#     exit_error "az login failed." $return_code
# fi
# az account set --subscription $ARM_SUBSCRIPTION_ID

start_group "Set Terraform variables"
export TF_VAR_PLATFORM=$(get_platform)

if [[ ${use_webapp,,} == "true" ]]; then # ,, = tolowercase
    echo "Use WebApp is selected"

    export TF_VAR_app_registration_app_id=${APP_REGISTRATION_APP_ID}
    echo "App Registration App ID: ${TF_VAR_app_registration_app_id}"
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

git pull -q

start_group "Decrypting state files"
# Import PGP key if it exists, otherwise generate it
if [ -f ${CONFIG_REPO_PATH}/private.pgp ]; then
    set +e
    gpg --list-keys sap-azure-deployer@example.com
    return_code=$?
    set -e

    if [ ${return_code} != 0 ]; then
        echo ${ARM_CLIENT_SECRET} | gpg --batch --passphrase-fd 0 --import ${CONFIG_REPO_PATH}/private.pgp
    fi
else
    echo ${ARM_CLIENT_SECRET} | ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/generate-pgp-key.sh
    gpg --output ${CONFIG_REPO_PATH}/private.pgp --armor --export-secret-key sap-azure-deployer@example.com
    git add ${CONFIG_REPO_PATH}/private.pgp
    commit_changes "Adding PGP key for encryption of state file" true
fi

if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.gpg ]; then
    echo "Decrypting state file"
    echo ${ARM_CLIENT_SECRET} | \
        gpg --batch \
        --passphrase-fd 0 \
        --output ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate \
        --decrypt ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.gpg
fi
end_group

start_group "Deploy the Control Plane"
set +eu

if [ "$USE_MSI" = "true" ]; then
    export ARM_CLIENT_SECRET=$servicePrincipalKey

    ${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/deploy_controlplane.sh \
        --deployer_parameter_file ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} \
        --library_parameter_file ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}     \
        --subscription $ARM_SUBSCRIPTION_ID \
        --auto-approve \
        --only_deployer \
        --msi \
        # TODO: --ado \
else
    ${SAP_AUTOMATION_REPO_PATH}/deploy/scripts/deploy_controlplane.sh \
        --deployer_parameter_file ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} \
        --library_parameter_file ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} \
        --subscription $ARM_SUBSCRIPTION_ID \
        --spn_id $ARM_CLIENT_ID \
        --spn_secret $ARM_CLIENT_SECRET \
        --tenant_id $ARM_TENANT_ID \
        --auto-approve \
        --only_deployer \
         # TODO: --ado \
fi

return_code=$?
echo "Return code from deploy_controlplane $return_code."

set -euo pipefail
end_group

start_group "Update deployment configuration to repo"

# Not needed anymore???
# if [ -f ${deployer_environment_file_name} ]; then
#     file_deployer_tfstate_key=$(config_value_with_key "deployer_tfstate_key")
#     if [ -z "$file_deployer_tfstate_key" ]; then
#         file_deployer_tfstate_key=${deployerfolder}/.terraform.tfstate
#     fi
#     echo "Deployer State File: $file_deployer_tfstate_key"

#     file_key_vault=$(config_value_with_key "keyvault")
#     echo "Deployer Key Vault: ${file_key_vault}"

#     deployer_random_id=$(config_value_with_key "deployer_random_id")
#     library_random_id=$(config_value_with_key "library_random_id")
# fi

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION} ]; then
    git add .sap_deployment_automation/${ENVIRONMENT}${LOCATION}
fi

if [ -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate ]; then
    git add -f DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate
fi

if [ -f DEPLOYER/${deployerfolder}/terraform.tfstate ]; then
    rm DEPLOYER/${deployerfolder}/state.gpg > /dev/null 2>&1 || true

    gpg --batch \
        --output DEPLOYER/${deployerfolder}/state.gpg \
        --encrypt \
        --disable-dirmngr\
        --recipient sap-azure-deployer@example.com \
        --trust-model always \
        DEPLOYER/${deployerfolder}/terraform.tfstate
    git add -f DEPLOYER/${deployerfolder}/state.gpg
fi

set +e
git diff --cached --quiet
git_diff_return_code=$?
set -e
if [ 1 == $git_diff_return_code ]; then
    commit_changes "Added updates for deployment."
fi

if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md ]; then
    upload_summary .sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md
fi

start_group "Adding variables to platform variable group"
if [ 0 == $return_code ]; then
    APP_CONFIGURATION_NAME_VALUE=$(config_value_with_key "deployer_app_config_name")
    set_value_with_key "APP_CONFIGURATION_NAME" ${APP_CONFIGURATION_NAME_VALUE}
    APP_CONFIGURATION_RESOURCE_GROUP_VALUE=$(config_value_with_key "created_resource_group_name")
    set_value_with_key "APP_CONFIGURATION_RESOURCE_GROUP" ${APP_CONFIGURATION_RESOURCE_GROUP_VALUE}
fi
end_group

exit $return_code
