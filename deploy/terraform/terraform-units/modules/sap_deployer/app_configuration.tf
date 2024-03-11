# data "azurerm_client_config" "current" {
#   provider = azurerm.main
# }

resource "azurerm_app_configuration" "app_config" {
  provider = azurerm.main
  count    = 1 # length(var.deployer.deployer_app_configuration_arm_id) > 0 ? 0 : 1
  name     = var.naming.appconfig_names.DEPLOYER
  resource_group_name = local.resource_group_exists ? (
    data.azurerm_resource_group.deployer[0].name) : (
    azurerm_resource_group.deployer[0].name
  )
  location = local.resource_group_exists ? (
    data.azurerm_resource_group.deployer[0].location) : (
    azurerm_resource_group.deployer[0].location
  )
  sku = "standard"
}

resource "azurerm_role_assignment" "appconf_dataowner" {
  provider             = azurerm.main
  scope                = azurerm_app_configuration.app_config[0].id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "appconf_dataowner2" {
  provider             = azurerm.main
  scope                = azurerm_app_configuration.app_config[0].id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = "47778390-c43d-4e18-a90f-d816301b569f" # Robert de Veen
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
