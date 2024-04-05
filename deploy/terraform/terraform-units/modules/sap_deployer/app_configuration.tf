resource "azurerm_app_configuration" "app_config" {
  provider = azurerm.main
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
  scope                = azurerm_app_configuration.app_config.id
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
  configuration_store_id = azurerm_app_configuration.app_config.id
  key                    = each.key
  label                  = each.value.label
  value                  = each.value.value
  content_type           = "text/plain"
  type                   = "kv"

  depends_on = [
    time_sleep.wait_for_appconf_dataowner_assignment
  ]

  lifecycle {
    ignore_changes = [
      configuration_store_id,
      etag,
      id
    ]
  }
}
