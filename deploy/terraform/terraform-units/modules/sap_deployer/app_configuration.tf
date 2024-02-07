resource "azurerm_app_configuration" "app_config" {
  count               = length(var.deployer.deployer_diagnostics_account_arm_id) > 0 ? 0 : 1
  name                = var.naming.appconfig_names.DEPLOYER
  resource_group_name = local.resourcegroup_name
  location = local.resource_group_exists ? (
    data.azurerm_resource_group.deployer[0].location) : (
    azurerm_resource_group.deployer[0].location
  )
}

resource "azurerm_role_assignment" "appconf_dataowner" {
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

resource "azurerm_app_configuration_key" "test" {
  configuration_store_id = azurerm_app_configuration.app_config[0].id
  key                    = "appConfKey1"
  label                  = "somelabel"
  value                  = "a test"

  depends_on = [
    time_sleep.wait_for_appconf_dataowner_assignment
  ]
}
