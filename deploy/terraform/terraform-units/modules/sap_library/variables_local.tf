
locals {

  #  storageaccount_names = var.naming.storageaccount_names.LIBRARY
  #  resource_suffixes    = var.naming.resource_suffixes


  // Region
  prefix                               = length(var.infrastructure.resource_group.name) > 0 ? (
                                           var.infrastructure.resource_group.name) : (
                                           trimspace(var.naming.prefix.LIBRARY)
                                         )

  // Resource group
  resource_group_exists                = length(var.infrastructure.resource_group.arm_id) > 0

  resource_group_name                  = local.resource_group_exists ? (
                                           try(split("/", var.infrastructure.resource_group.arm_id)[4], "")) : (
                                           length(var.infrastructure.resource_group.name) > 0 ? (
                                             var.infrastructure.resource_group.name) : (
                                             format("%s%s%s",
                                               var.naming.resource_prefixes.library_rg,
                                               local.prefix,
                                               var.naming.resource_suffixes.library_rg
                                             )
                                           )
                                         )
  resource_group_library_location      = local.resource_group_exists ? (
                                            data.azurerm_resource_group.library[0].location) : (
                                            azurerm_resource_group.library[0].location
                                          )

  // Storage account for sapbits
  sa_sapbits_exists                    = length(var.storage_account_sapbits.arm_id) > 0
  sa_sapbits_name                      = local.sa_sapbits_exists ? (
                                           split("/", var.storage_account_sapbits.arm_id)[8]) : (
                                           var.naming.storageaccount_names.LIBRARY.library_storageaccount_name
                                         )

  // Storage account for tfstate
  sa_tfstate_exists                    = length(var.storage_account_tfstate.arm_id) > 0


  // Comment out code with users.object_id for the time being.
  // deployer_users_id = try(local.deployer.users.object_id, [])

  // Current service principal
  service_principal                    = try(var.service_principal, {})

  deployer_public_ip_address           = try(var.deployer_tfstate.deployer_public_ip_address, "")

  enable_firewall_for_keyvaults_and_storage = try(var.deployer_tfstate.enable_firewall_for_keyvaults_and_storage, false)

  use_local_private_dns                = (length(var.dns_label) > 0 && !var.use_custom_dns_a_registration && length(trimspace(var.management_dns_resourcegroup_name)) == 0)

  keyvault_id                          = try(var.deployer_tfstate.deployer_kv_user_arm_id, "")

  virtual_additional_network_ids       = compact(
                                           flatten(
                                             [
                                               try(var.deployer_tfstate.subnet_mgmt_id, ""),
                                               try(var.deployer_tfstate.subnet_webapp_id, ""),
                                               try(var.deployer_tfstate.subnets_to_add_to_firewall_for_keyvaults_and_storage, [])
                                             ]
                                           )
                                         )

  pipeline_parameters                 = merge(var.deployer.pipeline_parameters != null ? var.deployer.pipeline_parameters : {},
                                            {
                                              "Deployer_State_FileName" = {
                                                label = var.deployer.deployer_parameter_group_name
                                                value = var.deployer.deployer_parameter_tf_state_filename
                                              }
                                              "Deployer_Key_Vault" = {
                                                label = var.deployer.deployer_parameter_group_name
                                                value = try(var.deployer_tfstate.deployer_kv_user_name, "")
                                              }
                                              "ControlPlaneEnvironment" = {
                                                label = var.deployer.deployer_parameter_group_name
                                                value = var.deployer.deployer_parameter_environment
                                              }
                                              "ControlPlaneLocation" = {
                                                label = var.deployer.deployer_parameter_group_name
                                                value = var.deployer.deployer_parameter_location
                                              }  
                                              "Terraform_Remote_Storage_Resource_Group_Name" = {
                                                label = var.deployer.deployer_parameter_group_name
                                                value = local.resource_group_name
                                              }   
                                              "Terraform_Remote_Storage_Account_Name" = {
                                                label = var.deployer.deployer_parameter_group_name
                                                value = local.sa_tfstate_exists ? (
                                                          split("/", var.storage_account_tfstate.arm_id)[8]) : (
                                                          length(var.storage_account_tfstate.name) > 0 ? (
                                                            var.storage_account_tfstate.name) : (
                                                            var.naming.storageaccount_names.LIBRARY.terraformstate_storageaccount_name
                                                          )
                                                        )
                                              }
                                              "Terraform_Remote_Storage_Subscription" = {
                                                label = var.deployer.deployer_parameter_group_name
                                                value = local.resource_group_exists ? (
                                                    split("/", data.azurerm_resource_group.library[0].id))[2] : (
                                                    split("/", azurerm_resource_group.library[0].id)[2]
                                                  )
                                              }                                                 
                                            })
}
