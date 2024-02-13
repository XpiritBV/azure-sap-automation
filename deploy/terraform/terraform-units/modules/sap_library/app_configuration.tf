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
