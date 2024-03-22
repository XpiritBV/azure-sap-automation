#!/usr/bin/env bash

. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/shared_functions.sh
. ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/set-colors.sh

function check_deploy_inputs() {
    REQUIRED_VARS=(
        "deployerconfig"
        "deployerfolder"
        "SAP_AUTOMATION_REPO_PATH"
        "CP_ARM_SUBSCRIPTION_ID"
        "CP_ARM_CLIENT_ID"
        "CP_ARM_CLIENT_SECRET"
        "CP_ARM_TENANT_ID"
        "WL_ARM_SUBSCRIPTION_ID"
        "WL_ARM_CLIENT_ID"
        "WL_ARM_CLIENT_SECRET"
        "WL_ARM_TENANT_ID"
    )

    case $(get_platform) in
    github) ;;

    devops)
        REQUIRED_VARS+=("variable_group")
        REQUIRED_VARS+=("parent_variable_group")
        ;;

    *) ;;
    esac

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

if [[ $(get_platform) = github ]]; then
    export CONFIG_REPO_PATH=${GITHUB_WORKSPACE}/WORKSPACES
fi

# TODO:
export USE_MSI=false

start_group "Setup platform dependencies"
# Will return vars which we need to export afterwards
eval "$(setup_dependencies | sed 's/^/export /')"
end_group

echo "Deploying the SAP Workload zone defined in ${workload_zone_folder}"

if [ ! -f ${CONFIG_REPO_PATH}/LANDSCAPE/${workload_zone_folder}/${workload_zone_configuration_file} ]; then
    exit_error "${workload_zone_configuration_file} was not found" 2
fi

cd ${CONFIG_REPO_PATH}

start_group "Validations"

if [ -z $WL_ARM_SUBSCRIPTION_ID ]; then
    # TODO: Relocate this to the check_deploy_inputs function
    echo "##vso[task.logissue type=error]Variable ARM_SUBSCRIPTION_ID was not defined in the $(variable_group) variable group."
    exit 2
fi
if [ $USE_MSI != "true" ]; then
    # TODO: Relocate this to the check_deploy_inputs function
    if [ -z $WL_ARM_CLIENT_ID ]; then
        echo "##vso[task.logissue type=error]Variable ARM_CLIENT_ID was not defined in the $(variable_group) variable group."
        exit 2
    fi

    if [ -z $WL_ARM_CLIENT_SECRET ]; then
        echo "##vso[task.logissue type=error]Variable ARM_CLIENT_SECRET was not defined in the $(variable_group) variable group."
        exit 2
    fi

    if [ -z $WL_ARM_TENANT_ID ]; then
        echo "##vso[task.logissue type=error]Variable ARM_TENANT_ID was not defined in the $(variable_group) variable group."
        exit 2
    fi

    if [ -z $CP_ARM_SUBSCRIPTION_ID ]; then
        echo "##vso[task.logissue type=error]Variable CP_ARM_SUBSCRIPTION_ID was not defined in the $(parent_variable_group) variable group."
        exit 2
    fi

    if [ -z $CP_ARM_CLIENT_ID ]; then
        echo "##vso[task.logissue type=error]Variable CP_ARM_CLIENT_ID was not defined in the $(parent_variable_group) variable group."
        exit 2
    fi

    if [ -z $CP_ARM_CLIENT_SECRET ]; then
        echo "##vso[task.logissue type=error]Variable CP_ARM_CLIENT_SECRET was not defined in the $(parent_variable_group) variable group."
        exit 2
    fi

    if [ -z $CP_ARM_TENANT_ID ]; then
        echo "##vso[task.logissue type=error]Variable CP_ARM_TENANT_ID was not defined in the $(parent_variable_group) variable group."
        exit 2
    fi
fi

start_group "Convert config file to UX format"
dos2unix -q LANDSCAPE/${workload_zone_folder}/${workload_zone_configuration_file}
end_group

ENVIRONMENT=$(grep "^environment" LANDSCAPE/${workload_zone_folder}/${workload_zone_configuration_file} | awk -F'=' '{print $2}' | xargs)
LOCATION=$(grep "^location" LANDSCAPE/${workload_zone_folder}/${workload_zone_configuration_file} | awk -F'=' '{print $2}' | xargs | tr 'A-Z' 'a-z')
NETWORK=$(grep "^network_logical_name" LANDSCAPE/${workload_zone_folder}/${workload_zone_configuration_file} | awk -F'=' '{print $2}' | xargs)
echo Environment: ${ENVIRONMENT}
echo Location: ${LOCATION}
echo Network: ${NETWORK}

ENVIRONMENT_IN_FILENAME=$(echo ${workload_zone_folder} | awk -F'-' '{print $1}' | xargs)
LOCATION_CODE=$(echo ${workload_zone_folder} | awk -F'-' '{print $2}' | xargs)
LOCATION_IN_FILENAME=region_with_region_map ${LOCATION_CODE}

NETWORK_IN_FILENAME=$(echo ${workload_zone_folder} | awk -F'-' '{print $3}' | xargs)
echo "Environment(filename): $ENVIRONMENT_IN_FILENAME"
echo "Location(filename):    $LOCATION_IN_FILENAME"
echo "Network(filename):     $NETWORK_IN_FILENAME"

if [ $ENVIRONMENT != $ENVIRONMENT_IN_FILENAME ]; then
    echo "##vso[task.logissue type=error]The environment setting in ${workload_zone_configuration_file} '$ENVIRONMENT' does not match the ${workload_zone_configuration_file} file name '$ENVIRONMENT_IN_FILENAME'. Filename should have the pattern [ENVIRONMENT]-[REGION_CODE]-[NETWORK_LOGICAL_NAME]-INFRASTRUCTURE"
    exit 2
fi

if [ $LOCATION != $LOCATION_IN_FILENAME ]; then
    echo "##vso[task.logissue type=error]The location setting in ${workload_zone_configuration_file} '$LOCATION' does not match the ${workload_zone_configuration_file} file name '$LOCATION_IN_FILENAME'. Filename should have the pattern [ENVIRONMENT]-[REGION_CODE]-[NETWORK_LOGICAL_NAME]-INFRASTRUCTURE"
    exit 2
fi

if [ $NETWORK != $NETWORK_IN_FILENAME ]; then
    echo "##vso[task.logissue type=error]The network_logical_name setting in ${workload_zone_configuration_file} '$NETWORK' does not match the ${workload_zone_configuration_file} file name '$NETWORK_IN_FILENAME-. Filename should have the pattern [ENVIRONMENT]-[REGION_CODE]-[NETWORK_LOGICAL_NAME]-INFRASTRUCTURE"
    exit 2
fi

echo -e "$green--- Configure devops CLI extension ---${resetformatting}"
az config set extension.use_dynamic_install=yes_without_prompt --output none

az extension add --name azure-devops --output none

az devops configure --defaults organization=$(System.CollectionUri) project='$(System.TeamProject)' --output none

export PARENT_VARIABLE_GROUP_ID=$(az pipelines variable-group list --query "[?name=='$(parent_variable_group)'].id | [0]")
echo '$(parent_variable_group) id: ' $PARENT_VARIABLE_GROUP_ID
if [ -z ${PARENT_VARIABLE_GROUP_ID} ]; then
    echo "##vso[task.logissue type=error]Variable group $(parent_variable_group) could not be found."
    exit 2
fi

export VARIABLE_GROUP_ID=$(az pipelines variable-group list --query "[?name=='$(variable_group)'].id | [0]")
echo '$(variable_group) id: ' $VARIABLE_GROUP_ID
if [ -z ${VARIABLE_GROUP_ID} ]; then
    echo "##vso[task.logissue type=error]Variable group $(variable_group) could not be found."
    exit 2
fi

echo "Agent Pool: " $(this_agent)

echo -e "$green--- Set CONFIG_REPO_PATH variable ---${resetformatting}"

deployer_environment_file_name=$CONFIG_REPO_PATH/.sap_deployment_automation/$(deployer_environment)$(deployer_region)
echo 'Deployer Environment File' $deployer_environment_file_name
workload_environment_file_name=$CONFIG_REPO_PATH/.sap_deployment_automation/${ENVIRONMENT}${LOCATION_CODE}${NETWORK}
echo 'Workload Environment File' $workload_environment_file_name
dos2unix -q ${deployer_environment_file_name}
dos2unix -q ${workload_environment_file_name}

if [ ! -f ${deployer_environment_file_name} ]; then
    echo -e "$boldred--- $(deployer_environment)$(deployer_region) was not found ---${resetformatting}"
    echo "##vso[task.logissue type=error]Control plane configuration file $(deployer_environment)$(deployer_region) was not found."
    exit 2
fi

echo -e "$green--- Read parameter values ---${resetformatting}"

if [ "true" == $(inherit) ]; then

    az_var=$(az pipelines variable-group variable list --group-id ${PARENT_VARIABLE_GROUP_ID} --query "Deployer_State_FileName.value" | tr -d \")
    if [ -z ${az_var} ]; then
        deployer_tfstate_key=$(cat ${deployer_environment_file_name} | grep deployer_tfstate_key | awk -F'=' '{print $2}' | xargs)
        echo 'Deployer State File' $deployer_tfstate_key
    else
        deployer_tfstate_key=${az_var}
        echo 'Deployer State File' $deployer_tfstate_key
    fi

    az_var=$(az pipelines variable-group variable list --group-id ${PARENT_VARIABLE_GROUP_ID} --query "Deployer_Key_Vault.value" | tr -d \")
    if [ -z ${az_var} ]; then
        key_vault=$(cat ${deployer_environment_file_name} | grep keyvault= | awk -F'=' '{print $2}' | xargs)
        echo 'Deployer Key Vault' ${key_vault}
    else
        key_vault=${az_var}
        echo 'Deployer Key Vault' ${key_vault}
    fi

    az_var=$(az pipelines variable-group variable list --group-id ${PARENT_VARIABLE_GROUP_ID} --query "Terraform_Remote_Storage_Account_Name.value" | tr -d \")
    if [ -z ${az_var} ]; then
        REMOTE_STATE_SA=$(cat ${deployer_environment_file_name} | grep REMOTE_STATE_SA | awk -F'=' '{print $2}' | xargs)
        echo 'Terraform state file storage account' $REMOTE_STATE_SA
    else
        REMOTE_STATE_SA=${az_var}
        echo 'Terraform state file storage account' $REMOTE_STATE_SA
    fi

    az_var=$(az pipelines variable-group variable list --group-id ${PARENT_VARIABLE_GROUP_ID} --query "Terraform_Remote_Storage_Subscription.value" | tr -d \")
    if [ -z ${az_var} ]; then
        STATE_SUBSCRIPTION=$(cat ${deployer_environment_file_name} | grep STATE_SUBSCRIPTION | awk -F'=' '{print $2}' | xargs)
        echo 'Terraform state file subscription' $STATE_SUBSCRIPTION
    else
        STATE_SUBSCRIPTION=${az_var}
        echo 'Terraform state file subscription' $STATE_SUBSCRIPTION
    fi

    az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "ARM_SUBSCRIPTION_ID.value" | tr -d \")
    if [ -z ${az_var} ]; then
        echo "##vso[task.logissue type=error]Variable ARM_SUBSCRIPTION_ID was not defined."
        exit 2
    else
        echo 'Target subscription' $WL_ARM_SUBSCRIPTION_ID
    fi

    az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "Workload_Key_Vault.value" | tr -d \")
    if [ -z ${az_var} ]; then
        if [ -f ${workload_environment_file_name} ]; then
            export workload_key_vault=$(cat ${workload_environment_file_name} | grep workload_key_vault | awk -F'=' '{print $2}' | xargs)
            echo 'Workload Key Vault' ${workload_key_vault}
        fi
    else
        export workload_key_vault=$(Workload_Key_Vault)
        echo 'Workload Key Vault' ${workload_key_vault}
    fi
else
    deployer_tfstate_key=$(cat ${workload_environment_file_name} | grep deployer_tfstate_key | awk -F'=' '{print $2}' | xargs)
    echo 'Deployer State File' $deployer_tfstate_key
    key_vault=$(cat ${workload_environment_file_name} | grep workload_key_vault= -m1 | awk -F'=' '{print $2}' | xargs)
    echo 'Deployer Key Vault' ${key_vault}
    REMOTE_STATE_SA=$(cat ${workload_environment_file_name} | grep REMOTE_STATE_SA | awk -F'=' '{print $2}' | xargs)
    echo 'Terraform state file storage account' $REMOTE_STATE_SA
    STATE_SUBSCRIPTION=$(cat ${workload_environment_file_name} | grep STATE_SUBSCRIPTION | awk -F'=' '{print $2}' | xargs)
    echo 'Terraform state file subscription' $STATE_SUBSCRIPTION
fi

secrets_set=1
if [ ! -f /etc/profile.d/deploy_server.sh ]; then
    echo -e "$green --- Install terraform ---${resetformatting}"

    wget -q $(tf_url)
    return_code=$?
    if [ 0 != $return_code ]; then
        echo "##vso[task.logissue type=error]Unable to download Terraform version $(tf_version)."
        exit 2
    fi
    unzip -qq terraform_$(tf_version)_linux_amd64.zip
    sudo mv terraform /bin/
    rm -f terraform_$(tf_version)_linux_amd64.zip

    if [ $USE_MSI != "true" ]; then
        export ARM_CLIENT_ID=$WL_ARM_CLIENT_ID
        export ARM_CLIENT_SECRET=$WL_ARM_CLIENT_SECRET
        export ARM_TENANT_ID=$WL_ARM_TENANT_ID
        export ARM_SUBSCRIPTION_ID=$WL_ARM_SUBSCRIPTION_ID
        export ARM_USE_MSI=false

        echo -e "$green--- az login ---${resetformatting}"
        az login --service-principal --username $CP_ARM_CLIENT_ID --password=$CP_ARM_CLIENT_SECRET --tenant $CP_ARM_TENANT_ID --output none
        return_code=$?
        if [ 0 != $return_code ]; then
            echo -e "$boldred--- Login failed ---${resetformatting}"
            echo "##vso[task.logissue type=error]az login failed."
            exit $return_code
        fi
    fi

else
    echo -e "$green--- az login ---${resetformatting}"

    if [ $LOGON_USING_SPN == "true" ]; then
        echo "Using SPN"
        az login --service-principal --username $CP_ARM_CLIENT_ID --password=$CP_ARM_CLIENT_SECRET --tenant $CP_ARM_TENANT_ID --output none
    else
        az login --identity --allow-no-subscriptions --output none
    fi

    return_code=$?
    if [ 0 != $return_code ]; then
        echo -e "$boldred--- Login failed ---${resetformatting}"
        echo "##vso[task.logissue type=error]az login failed."
        exit $return_code
    fi

    if [ $USE_MSI != "true" ]; then
        echo -e "$green --- Set secrets ---${resetformatting}"

        $SAP_AUTOMATION_REPO_PATH/deploy/scripts/set_secrets.sh --workload --vault "${key_vault}" --environment "${ENVIRONMENT}" \
            --region "${LOCATION}" --subscription $WL_ARM_SUBSCRIPTION_ID --spn_id $WL_ARM_CLIENT_ID --spn_secret "${WL_ARM_CLIENT_SECRET}" \
            --tenant_id $WL_ARM_TENANT_ID --keyvault_subscription $STATE_SUBSCRIPTION
        secrets_set=$?
        echo -e "$cyan Set Secrets returned $secrets_set ${resetformatting}"
        az keyvault set-policy --name "${key_vault}" --object-id $WL_ARM_OBJECT_ID --secret-permissions get list --output none
    fi
fi

debug_variable='--output none'
debug_variable=''

if [ $USE_MSI != "true" ]; then
    az login --service-principal --username $CP_ARM_CLIENT_ID --password=$CP_ARM_CLIENT_SECRET --tenant $CP_ARM_TENANT_ID --output none

    isUserAccessAdmin=$(az role assignment list --role "User Access Administrator" --subscription $STATE_SUBSCRIPTION --query "[?principalType=='ServicePrincipal'].principalId | [0] " --assignee $CP_ARM_CLIENT_ID)

    tfstate_resource_id=$(az resource list --name "${REMOTE_STATE_SA}" --subscription ${STATE_SUBSCRIPTION} --resource-type Microsoft.Storage/storageAccounts --query "[].id | [0]" -o tsv)

    if [ -n "${isUserAccessAdmin}" ]; then

        echo -e "$green--- Set permissions ---${resetformatting}"
        perms=$(az role assignment list --subscription ${STATE_SUBSCRIPTION} --role "Reader" --query "[?principalId=='$WL_ARM_CLIENT_ID'].principalId | [0]" -o tsv --only-show-errors)
        if [ -z "$perms" ]; then
            echo -e "$green --- Assign subscription permissions to $perms ---${resetformatting}"
            az role assignment create --assignee-object-id $WL_ARM_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Reader" --scope "/subscriptions/${STATE_SUBSCRIPTION}" --output none
        fi

        perms=$(az role assignment list --subscription ${STATE_SUBSCRIPTION} --role "Storage Account Contributor" --scope "${tfstate_resource_id}" --query "[?principalId=='$WL_ARM_OBJECT_ID'].principalName | [0]" -o tsv --only-show-errors)
        if [ -z "$perms" ]; then
            echo "Assigning Storage Account Contributor permissions for $WL_ARM_OBJECT_ID to ${tfstate_resource_id}"
            az role assignment create --assignee-object-id $WL_ARM_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Storage Account Contributor" --scope "${tfstate_resource_id}" --output none
        fi

        resource_group_name=$(az resource show --id "${tfstate_resource_id}" --query resourceGroup -o tsv)

        if [ -n ${resource_group_name} ]; then
            for scope in $(az resource list --resource-group "${resource_group_name}" --subscription ${STATE_SUBSCRIPTION} --resource-type Microsoft.Network/privateDnsZones --query "[].id" --output tsv); do
                perms=$(az role assignment list --subscription ${STATE_SUBSCRIPTION} --role "Private DNS Zone Contributor" --scope $scope --query "[?principalId=='$WL_ARM_OBJECT_ID'].principalId | [0]" -o tsv --only-show-errors)
                if [ -z "$perms" ]; then
                    echo "Assigning DNS Zone Contributor permissions for $WL_ARM_OBJECT_ID to ${scope}"
                    az role assignment create --assignee-object-id $WL_ARM_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Private DNS Zone Contributor" --scope $scope --output none
                fi
            done
        fi

        resource_group_name=$(az keyvault show --name "${key_vault}" --query resourceGroup --subscription ${STATE_SUBSCRIPTION} -o tsv)

        if [ -n ${resource_group_name} ]; then
            resource_group_id=$(az group show --name ${resource_group_name} --subscription ${STATE_SUBSCRIPTION} --query id -o tsv)

            vnet_resource_id=$(az resource list --resource-group "${resource_group_name}" --subscription ${STATE_SUBSCRIPTION} --resource-type Microsoft.Network/virtualNetworks -o tsv --query "[].id | [0]")
            if [ -n "${vnet_resource_id}" ]; then
                perms=$(az role assignment list --subscription ${STATE_SUBSCRIPTION} --role "Network Contributor" --scope $vnet_resource_id --only-show-errors --query "[].principalId | [0]" --assignee $WL_ARM_OBJECT_ID -o tsv --only-show-errors)

                if [ -z "$perms" ]; then
                    echo "Assigning Network Contributor rights for $WL_ARM_OBJECT_ID to ${vnet_resource_id}"
                    az role assignment create --assignee-object-id $WL_ARM_OBJECT_ID --assignee-principal-type ServicePrincipal --role "Network Contributor" --scope $vnet_resource_id --output none
                fi
            fi
        fi
    else
        echo "##vso[task.logissue type=warning]Service Principal $CP_ARM_CLIENT_ID does not have 'User Access Administrator' permissions. Please ensure that the service principal $WL_ARM_CLIENT_ID has permissions on the Terrafrom state storage account and if needed on the Private DNS zone and the source management network resource"
    fi
fi

echo -e "$green--- Deploy the workload zone ---${resetformatting}"
cd $CONFIG_REPO_PATH/LANDSCAPE/${workload_zone_folder}
if [ -f /etc/profile.d/deploy_server.sh ]; then
    if [ $LOGON_USING_SPN == "true" ]; then
        echo "Logon Using SPN"

        az logout --output none
        export ARM_CLIENT_ID=$WL_ARM_CLIENT_ID
        export ARM_CLIENT_SECRET=$WL_ARM_CLIENT_SECRET
        export ARM_TENANT_ID=$WL_ARM_TENANT_ID
        export ARM_SUBSCRIPTION_ID=$WL_ARM_SUBSCRIPTION_ID
        export ARM_USE_MSI=false
        az login --service-principal --username $WL_ARM_CLIENT_ID --password=$WL_ARM_CLIENT_SECRET --tenant $WL_ARM_TENANT_ID --output none
        return_code=$?
        if [ 0 != $return_code ]; then
            echo -e "$boldred--- Login failed ---${resetformatting}"
            echo "##vso[task.logissue type=error]az login failed."
            exit $return_code
        fi
    else
        export ARM_USE_MSI=true
        az login --identity --allow-no-subscriptions --output none
    fi
else
    if [ $USE_MSI != "true" ]; then
        az logout --output none
        export ARM_CLIENT_ID=$WL_ARM_CLIENT_ID
        export ARM_CLIENT_SECRET=$WL_ARM_CLIENT_SECRET
        export ARM_TENANT_ID=$WL_ARM_TENANT_ID
        export ARM_SUBSCRIPTION_ID=$WL_ARM_SUBSCRIPTION_ID
        export ARM_USE_MSI=false
        az login --service-principal --username $WL_ARM_CLIENT_ID --password=$WL_ARM_CLIENT_SECRET --tenant $WL_ARM_TENANT_ID --output none
        return_code=$?
        if [ 0 != $return_code ]; then
            echo -e "$boldred--- Login failed ---${resetformatting}"
            echo "##vso[task.logissue type=error]az login failed."
            exit $return_code
        fi
    fi

fi

if [ $USE_MSI != "true" ]; then
    $SAP_AUTOMATION_REPO_PATH/deploy/scripts/install_workloadzone.sh --parameterfile ${workload_zone_configuration_file} \
        --deployer_environment $(deployer_environment) --subscription $(ARM_SUBSCRIPTION_ID) \
        --spn_id $WL_ARM_CLIENT_ID --spn_secret $WL_ARM_CLIENT_SECRET --tenant_id $WL_ARM_TENANT_ID \
        --deployer_tfstate_key "${deployer_tfstate_key}" --keyvault "${key_vault}" --storageaccountname "${REMOTE_STATE_SA}" \
        --state_subscription "${STATE_SUBSCRIPTION}" --auto-approve --ado
else
    $SAP_AUTOMATION_REPO_PATH/deploy/scripts/install_workloadzone.sh --parameterfile ${workload_zone_configuration_file} \
        --deployer_environment $(deployer_environment) --subscription $(ARM_SUBSCRIPTION_ID) \
        --deployer_tfstate_key "${deployer_tfstate_key}" --keyvault "${key_vault}" --storageaccountname "${REMOTE_STATE_SA}" \
        --state_subscription "${STATE_SUBSCRIPTION}" --auto-approve --ado --msi
fi
return_code=$?

echo "Return code: ${return_code}"
if [ -f ${workload_environment_file_name} ]; then
    export workload_key_vault=$(cat ${workload_environment_file_name} | grep workloadkeyvault= | awk -F'=' '{print $2}' | xargs)
    echo 'Workload Key Vault' ${workload_key_vault}
    export workload_prefix=$(cat ${workload_environment_file_name} | grep workload_zone_prefix= | awk -F'=' '{print $2}' | xargs)
    echo 'Workload Prefix' ${workload_prefix}
    export landscape_tfstate_key=$(cat ${workload_environment_file_name} | grep landscape_tfstate_key= | awk -F'=' '{print $2}' | xargs)
    echo 'Workload Zone State File' $landscape_tfstate_key
fi

az logout --output none

az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "FENCING_SPN_ID.value")
if [ -z ${az_var} ]; then
    echo "##vso[task.logissue type=warning]Variable FENCING_SPN_ID is not set. Required for highly available deployments"
else
    export fencing_id=$(az keyvault secret list --vault-name $workload_key_vault --query [].name -o tsv | grep ${workload_prefix}-fencing-spn-id | xargs)
    if [ -z "$fencing_id" ]; then
        az keyvault secret set --name ${workload_prefix}-fencing-spn-id --vault-name $workload_key_vault --value $(FENCING_SPN_ID) --output none
        az keyvault secret set --name ${workload_prefix}-fencing-spn-pwd --vault-name $workload_key_vault --value=$FENCING_SPN_PWD --output none
        az keyvault secret set --name ${workload_prefix}-fencing-spn-tenant --vault-name $workload_key_vault --value $(FENCING_SPN_TENANT) --output none
    fi
fi

echo -e "$green--- Add & update files in the DevOps Repository ---${resetformatting}"
cd $(Build.Repository.LocalPath)
git pull

echo -e "$green--- Pull latest ---${resetformatting}"
cd $CONFIG_REPO_PATH
git pull

added=0
if [ -f ${workload_environment_file_name} ]; then
    git add ${workload_environment_file_name}
fi

if [ -f ${workload_environment_file_name}.md ]; then
    git add ${workload_environment_file_name}.md
fi

if [ -f $(Deployment_Configuration_Path)/LANDSCAPE/${workload_zone_folder}/.terraform/terraform.tfstate ]; then
    git add -f $(Deployment_Configuration_Path)/LANDSCAPE/${workload_zone_folder}/.terraform/terraform.tfstate
fi

set +e
git diff --cached --quiet
git_diff_return_code=$?
set -e

if [ 1 == $git_diff_return_code ]; then
    commit_changes "Added updates from deployment"
fi

if [ -f ${workload_environment_file_name}.md ]; then
    upload_summary ${workload_environment_file_name}.md
fi

start_group "Adding variables to platform variable group"

if [ -n $VARIABLE_GROUP_ID ]; then
    set_value_with_key "Terraform_Remote_Storage_Account_Name" ${REMOTE_STATE_SA}

    set_value_with_key "Terraform_Remote_Storage_Subscription" ${STATE_SUBSCRIPTION}

    set_value_with_key "Deployer_State_FileName" ${deployer_tfstate_key}

    set_value_with_key "Deployer_Key_Vault" ${key_vault}

    set_value_with_key "Workload_Key_Vault" ${workload_key_vault}

    set_value_with_key "${NETWORK}Workload_Secret_Prefix" ${workload_prefix}

    set_value_with_key "${NETWORK}Workload_Zone_State_FileName" ${landscape_tfstate_key}

    set_value_with_key "Workload_Zone_State_FileName" ${landscape_tfstate_key}

    set_secret_with_key "WZ_PAT" $AZURE_DEVOPS_EXT_PAT
fi

if [ 0 != $return_code ]; then
    echo "##vso[task.logissue type=error]Return code from install_workloadzone $return_code."
    if [ -f ${workload_environment_file_name}.err ]; then
        error_message=$(cat ${workload_environment_file_name}.err)
        echo "##vso[task.logissue type=error]Error message: $error_message."
    fi
fi

exit $return_code
