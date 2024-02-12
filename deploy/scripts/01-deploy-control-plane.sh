#!/usr/bin/env bash

. deploy/scripts/shared_functions.sh

  echo "Deploying the control plane defined in ${deployerfolder} ${libraryfolder}"
      green="\e[1;32m"
      reset="\e[0m"
      boldred="\e[1;31m"

      set -eu

      file_deployer_tfstate_key=${deployerfolder}.tfstate

      ENVIRONMENT=$(echo ${deployerfolder} | awk -F'-' '{print $1}' | xargs) ; echo Environment ${ENVIRONMENT}
      LOCATION=$(echo ${deployerfolder} | awk -F'-' '{print $2}' | xargs) ;    echo Location ${LOCATION}
      deployer_environment_file_name=${CONFIG_REPO_PATH}/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}

  start_group "Configure devops CLI extension"
      # az config set extension.use_dynamic_install=yes_without_prompt

    #  az extension add --name azure-devops --output none

    #   az devops configure --defaults organization=${System_CollectionUri} project='${System_TeamProject}' --output none
    #   export VARIABLE_GROUP_ID=$(az pipelines variable-group list --query "[?name=='${variable_group}'].id | [0]")
    #   echo "${variable_group} id: ${VARIABLE_GROUP_ID}"

      echo "Force reset: ${force_reset}"
      if [ ${force_reset,,} == "true" ]; then
        log_warning "Forcing a re-install"
        echo "running on ${this_agent}"
        sed -i 's/step=1/step=0/' $deployer_environment_file_name
        sed -i 's/step=2/step=0/' $deployer_environment_file_name
        sed -i 's/step=3/step=0/' $deployer_environment_file_name

        export FORCE_RESET=true
        az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "Deployer_Key_Vault.value" | tr -d \")
        if [ -n "${az_var}" ]; then
          key_vault="${az_var}" ; echo 'Deployer Key Vault' ${key_vault}
        else
          echo "Reading key vault from environment file"
          key_vault=$(cat ${deployer_environment_file_name} | grep keyvault= -m1 | awk -F'=' '{print $2}' | xargs) ; echo 'Deployer Key Vault' ${key_vault}
        fi

        az login --service-principal --username $ARM_CLIENT_ID --password=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none
        return_code=$?
        if [ 0 != $return_code ]; then
            echo -e "$boldred--- Login failed ---$reset"
            exit_error "az login failed." $return_code
        fi

        key_vault_id=$(az resource list --name "${key_vault}"  --resource-type Microsoft.KeyVault/vaults --query "[].id | [0]" -o tsv)
        export TF_VAR_deployer_kv_user_arm_id=${key_vault_id}
        if [ -n "${key_vault_id}" ]; then
          this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
          az keyvault network-rule add --name ${key_vault} --ip-address ${this_ip} --subscription ${Terraform_Remote_Storage_Subscription} --only-show-errors --output none
          ip_added=1
        fi

        tfstate_resource_id=$(az resource list --name ${Terraform_Remote_Storage_Account_Name} --subscription ${Terraform_Remote_Storage_Subscription} --resource-type Microsoft.Storage/storageAccounts --query "[].id | [0]" -o tsv)
        if [ -n "${tfstate_resource_id}" ]; then
          this_ip=$(curl -s ipinfo.io/ip) >/dev/null 2>&1
          az storage account network-rule add --account-name ${Terraform_Remote_Storage_Account_Name} --resource-group ${Terraform_Remote_Storage_Resource_Group_Name}  --ip-address ${this_ip} --only-show-errors --output none
        fi

        export REINSTALL_ACCOUNTNAME=${Terraform_Remote_Storage_Account_Name}
        export REINSTALL_SUBSCRIPTION=${Terraform_Remote_Storage_Subscription}
        export REINSTALL_RESOURCE_GROUP=${Terraform_Remote_Storage_Resource_Group_Name}
        step=0
      else
        if [ -f ${deployer_environment_file_name} ]; then
          step=$(cat ${deployer_environment_file_name}  | grep step= | awk -F'=' '{print $2}' | xargs) ; echo 'Step' ${step}
          if [ "0" != ${step} ]; then
            exit 0
          fi
        fi
      fi
      # echo "Agent: " ${this_agent}
      # if [ -z ${VARIABLE_GROUP_ID} ]; then
      #     exit_error "Variable group ${variable_group} could not be found." 2
      # fi
  end_group
  echo -e "$green--- Variables ---$reset"
      storage_account_parameter=""
  start_group "Validations"
      if [ -z ${TF_VAR_ansible_core_version} ]; then
          export TF_VAR_ansible_core_version=2.15
      fi
      if [ -z ${ARM_SUBSCRIPTION_ID} ]; then
          exit_error "Variable ARM_SUBSCRIPTION_ID was not defined." 2
      fi
      if [ -z ${ARM_CLIENT_ID} ]; then
          exit_error "Variable ARM_CLIENT_ID was not defined." 2
      fi
      if [ -z ${ARM_CLIENT_SECRET} ]; then
          exit_error "Variable ARM_CLIENT_SECRET was not defined." 2
      fi
      if [ -z ${ARM_TENANT_ID} ]; then
          exit_error "Variable ARM_TENANT_ID was not defined." 2
      fi
      export TF_VAR_use_webapp=${use_webapp}
  end_group
  # TODO: Is this necessary on GitHub?
  start_group "Update .sap_deployment_automation/config as SAP_AUTOMATION_REPO_PATH can change on devops agent"
      echo "Current Directory $(pwd)"
      ls -la
      
      mkdir -p .sap_deployment_automation
      echo SAP_AUTOMATION_REPO_PATH=$SAP_AUTOMATION_REPO_PATH >.sap_deployment_automation/config
  end_group
  start_group "File Validations"
      if [ ! -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} ]; then
          # echo -e "$boldred--- File ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} was not found ---$reset"
          exit_error "File ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} was not found." 2
      else
          echo "Deployer Config File found:" ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig}
      fi
      if [ ! -f ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} ]; then
          # echo -e "$boldred--- File ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}  was not found ---$reset"
          exit_error "File ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig} was not found." 2
      else
          echo "Library Config File found:" ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}
      fi
  end_group

  # Check if running on deployer
  if [ ! -f /etc/profile.d/deploy_server.sh ]; then
      echo -e "$green --- Install dos2unix ---$reset"
      sudo apt-get -qq install dos2unix

      echo -e "$green --- Install zip ---$reset"
      sudo apt -qq install zip

      echo -e "$green --- Install terraform ---$reset"
      # wget -q ${tf_url}
      # return_code=$?
      # if [ 0 != $return_code ]; then
      #     exit_error "Unable to download Terraform version ${tf_version}." 2
      # fi
      # unzip -qq terraform_${tf_version}_linux_amd64.zip ; sudo mv terraform /bin/
      # rm -f terraform_${tf_version}_linux_amd64.zip
      sudo apt -qq install terraform=${tf_version}
      
      az extension add --name storage-blob-preview >/dev/null
  fi
  start_group "Configure parameters"
      echo -e "$green--- Convert config files to UX format ---$reset"
      dos2unix -q ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig}
      dos2unix -q ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}
      echo -e "$green--- Configuring variables ---$reset"
      deployer_environment_file_name=$CONFIG_REPO_PATH/.sap_deployment_automation/${ENVIRONMENT}$LOCATION
  end_group
  start_group "Deployment"
  echo -e "$green--- az login ---$reset"
      az login --service-principal --username $ARM_CLIENT_ID --password=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none
      return_code=$?
      if [ 0 != $return_code ]; then
          echo -e "$boldred--- Login failed ---$reset"
          exit_error "az login failed." $return_code
      fi
      az account set --subscription $ARM_SUBSCRIPTION_ID
      echo -e "$green--- Deploy the Control Plane ---$reset"
      if [ -n ${PAT} ]; then
          echo 'Deployer Agent PAT is defined'
      fi
      if [ -n ${POOL} ]; then
          echo 'Deployer Agent Pool' ${POOL}
          POOL_NAME=$(az pipelines pool list --organization ${System_CollectionUri} --query "[?name=='${POOL}'].name | [0]")
          if [ ${#POOL_NAME} -eq 0 ]; then
              log_warning "Agent Pool ${POOL} does not exist." 2
          fi
          echo 'Deployer Agent Pool found' $POOL_NAME
          export TF_VAR_agent_pool=${POOL}
          export TF_VAR_agent_pat=${PAT}
      fi
      if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip ]; then
          pass=$(echo $ARM_CLIENT_SECRET | sed 's/-//g')
          # TODO: unzip with password is unsecure, use PGP Encrypt
          unzip -qq -o -P "${pass}" ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip -d ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}
      fi

    if [ ${use_webapp,,} == "true" ]; then
        echo "Use WebApp is selected"

        if [ -z ${APP_REGISTRATION_APP_ID} ]; then
            exit_error "Variable APP_REGISTRATION_APP_ID was not defined." 2
        fi

        if [ -z ${WEB_APP_CLIENT_SECRET} ]; then
            exit_error "Variable WEB_APP_CLIENT_SECRET was not defined." 2
        fi
        export TF_VAR_app_registration_app_id=${APP_REGISTRATION_APP_ID}; echo 'App Registration App ID' ${TF_VAR_app_registration_app_id}
        export TF_VAR_webapp_client_secret=${WEB_APP_CLIENT_SECRET}
        export TF_VAR_use_webapp=true

    fi

      export TF_LOG_PATH=$CONFIG_REPO_PATH/.sap_deployment_automation/terraform.log
      set +eu

      $SAP_AUTOMATION_REPO_PATH/deploy/scripts/deploy_controlplane.sh                               \
          --deployer_parameter_file ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/${deployerconfig} \
          --library_parameter_file ${CONFIG_REPO_PATH}/LIBRARY/${libraryfolder}/${libraryconfig}     \
          --subscription $ARM_SUBSCRIPTION_ID --spn_id $ARM_CLIENT_ID                                \
          --spn_secret $ARM_CLIENT_SECRET --tenant_id $ARM_TENANT_ID                                 \
          --auto-approve --ado --only_deployer
      return_code=$?
      echo "Return code from deploy_controlplane $return_code."

      set -eu

      echo -e "$green--- Adding deployment automation configuration to devops repository ---$reset"
      added=0
      cd $CONFIG_REPO_PATH
      git pull -q
      if [ -f ${deployer_environment_file_name} ]; then
          file_deployer_tfstate_key=$(cat ${deployer_environment_file_name} | grep deployer_tfstate_key | awk -F'=' '{print $2}' | xargs)
          if [ -z "$file_deployer_tfstate_key" ]; then
            file_deployer_tfstate_key=$DEPLOYER_TFSTATE_KEY
          fi
          echo 'Deployer State File' $file_deployer_tfstate_key
          file_key_vault=$(cat ${deployer_environment_file_name} | grep keyvault= | awk -F'=' '{print $2}' | xargs)
          echo 'Deployer Key Vault' ${file_key_vault}
          deployer_random_id=$(cat ${deployer_environment_file_name} | grep deployer_random_id= | awk -F'=' '{print $2}' | xargs)
          library_random_id=$(cat ${deployer_environment_file_name} | grep library_random_id= | awk -F'=' '{print $2}' | xargs)

      fi
  start_group "Update repo"
      if [ -f .sap_deployment_automation/${ENVIRONMENT}${LOCATION} ]; then
          git add .sap_deployment_automation/${ENVIRONMENT}${LOCATION}
          added=1
      fi
      if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate ]; then
        git add -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/.terraform/terraform.tfstate
        added=1
      fi
      if [ -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate ]; then
        sudo apt install zip
        pass=$(echo $ARM_CLIENT_SECRET | sed 's/-//g')
        # TODO: unzip with password is unsecure, use PGP Encrypt
        zip -j -P "${pass}" ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/terraform.tfstate
        git add -f ${CONFIG_REPO_PATH}/DEPLOYER/${deployerfolder}/state.zip
        added=1
      fi

      if [ 1 == $added ]; then
          if [ -z ${GITHUB_CONTEXT} ]; then
            git config --global user.email "${Build.RequestedForEmail}"
            git config --global user.name "${Build.RequestedFor}"
            git commit -m "Added updates from devops deployment ${Build.DefinitionName} [skip ci]"
            git -c http.extraheader="AUTHORIZATION: bearer ${System_AccessToken}" push --set-upstream origin ${Build.SourceBranchName}
          else
            git config --global user.email github-actions@github.com
            git config --global user.name github-actions
            git commit -m "Added updates from GitHub workflow $GITHUB_WORKFLOW [skip ci]"
            git push
          fi
      fi

      if [ -f $CONFIG_REPO_PATH/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md ]; then
          echo "##vso[task.uploadsummary]$CONFIG_REPO_PATH/.sap_deployment_automation/${ENVIRONMENT}${LOCATION}.md"
      fi
  end_group
  start_group "Adding variables to the variable group: ${variable_group}"
      if [ 0 == $return_code ]; then
          az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "Deployer_State_FileName.value")
          if [ -z ${az_var} ]; then
              az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name Deployer_State_FileName --value ${file_deployer_tfstate_key} --output none --only-show-errors
          else
              az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name Deployer_State_FileName --value ${file_deployer_tfstate_key} --output none --only-show-errors
          fi
          az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "Deployer_Key_Vault.value")
          if [ -z ${az_var} ]; then
              az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name Deployer_Key_Vault --value ${file_key_vault} --output none --only-show-errors
          else
              az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name Deployer_Key_Vault --value ${file_key_vault} --output none --only-show-errors
          fi
          az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "ControlPlaneEnvironment.value")
          if [ -z ${az_var} ]; then
              az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name ControlPlaneEnvironment --value ${ENVIRONMENT} --output none --only-show-errors
          else
              az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name ControlPlaneEnvironment --value ${ENVIRONMENT} --output none --only-show-errors
          fi

          az_var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "ControlPlaneLocation.value")
          if [ -z ${az_var} ]; then
              az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name ControlPlaneLocation --value ${LOCATION} --output none --only-show-errors
          else
              az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name ControlPlaneLocation --value ${LOCATION} --output none --only-show-errors
          fi
      fi
  end_group
  exit $return_code
