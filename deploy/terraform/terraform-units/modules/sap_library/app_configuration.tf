data "azurerm_app_configuration" "app_config" {
  provider            = azurerm.deployer
  resource_group_name = var.deployer_tfstate.created_resource_group_name
  name                = var.deployer_tfstate.deployer_app_config_name
}

resource "azurerm_app_configuration_key" "deployer_app_configuration_keys" {
  for_each               = local.pipeline_parameters
  provider               = azurerm.deployer
  configuration_store_id = data.azurerm_app_configuration.app_config.id
  key                    = each.key
  label                  = each.value.label
  value                  = each.value.value
}
