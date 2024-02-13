data "azurerm_client_config" "current" {
  provider                             = azurerm.main
}

resource "azurerm_app_configuration" "app_config" {
  provider            = azurerm.main
  count               = length(var.deployer.deployer_app_configuration_arm_id) > 0 ? 0 : 1
  name                = var.naming.appconfig_names.LIBRARY
  resource_group_name = local.resource_group_name
  location            = local.resource_group_library_location
}

resource "azurerm_role_assignment" "appconf_dataowner" {
  provider             = azurerm.main
  scope                = azurerm_app_configuration.app_config[0].id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_appconf_dataowner_assignment" {
  create_duration = "60s"
  
  depends_on = [
    azurerm_role_assignment.appconf_dataowner
  ]
}

locals {
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

resource "azurerm_app_configuration_key" "deployer_app_configuration_keys" {
  for_each               = local.pipeline_parameters
  provider               = azurerm.main
  configuration_store_id = azurerm_app_configuration.app_config[0].id
  key                    = each.key
  label                  = each.value.label
  value                  = each.value.value

  depends_on = [
    time_sleep.wait_for_appconf_dataowner_assignment
  ]
}
