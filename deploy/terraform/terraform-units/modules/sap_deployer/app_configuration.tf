resource "azurerm_app_configuration" "app_config" {
  count               = var.deployer.pipeline_parameters != null ? 1 : 0
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

resource "azurerm_app_configuration_key" "deployer_app_configuration_keys" {
  for_each               = var.deployer.pipeline_parameters != null ? var.deployer.pipeline_parameters : {}
  configuration_store_id = azurerm_app_configuration.app_config[0].id
  key                    = each.key
  label                  = each.value.label
  value                  = each.value.value

  depends_on = [
    time_sleep.wait_for_appconf_dataowner_assignment
  ]
}