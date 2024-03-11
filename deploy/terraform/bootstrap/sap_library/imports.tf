/*
    Description:
      Import deployer resources
*/

data "terraform_remote_state" "deployer"          {
                                                    backend      = "local"
                                                    count        = length(var.deployer_statefile_foldername) > 0 || var.use_deployer ? 1 : 0
                                                    config       = {
                                                                     path = length(var.deployer_statefile_foldername) > 0 ? (
                                                                              "${var.deployer_statefile_foldername}/terraform.tfstate") : (
                                                                              "${abspath(path.cwd)}/../../LOCAL/${local.deployer_rg_name}/terraform.tfstate"
                                                                            )
                                                                   }
                                                  }

data "azurerm_key_vault_secret" "subscription_id" {
                                                    provider     = azurerm.deployer
                                                    count        = var.use_deployer ? 1 : 0
                                                    name         = format("%s-subscription-id", upper(local.infrastructure.environment))
                                                    key_vault_id = local.spn_key_vault_arm_id
                                                  }

data "azurerm_key_vault_secret" "client_id"       {
                                                    provider     = azurerm.deployer
                                                    count        = var.use_deployer ? 1 : 0
                                                    name         = format("%s-client-id", upper(local.infrastructure.environment))
                                                    key_vault_id = local.spn_key_vault_arm_id
                                                  }

data "azurerm_key_vault_secret" "client_secret"   {
                                                    provider     = azurerm.deployer
                                                    count        = var.use_deployer ? 1 : 0
                                                    name         = format("%s-client-secret", upper(local.infrastructure.environment))
                                                    key_vault_id = local.spn_key_vault_arm_id
                                                  }

data "azurerm_key_vault_secret" "tenant_id"       {
                                                    provider     = azurerm.deployer
                                                    count        = var.use_deployer ? 1 : 0
                                                    name         = format("%s-tenant-id", upper(local.infrastructure.environment))
                                                    key_vault_id = local.spn_key_vault_arm_id
                                                  }

// Import current service principal
data "azuread_service_principal" "sp"             {
                                                    count        = var.use_deployer ? 1 : 0
                                                    client_id    = local.spn.client_id
                                                  }

data "azurerm_app_configuration" "app_config"     {
                                                    provider            = azurerm.deployer
                                                    count               = length(var.deployer.deployer_app_configuration_arm_id) > 0 ? 0 : 1
                                                    resource_group_name = local.deployer_rg_name
                                                    name                = var.naming.appconfig_names.LIBRARY
                                                  }
