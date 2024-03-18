#######################################4#######################################8
#                                                                              #
#              Configures the Deployer after creation.                         #
#                                                                              #
#######################################4#######################################8


// Prepare deployer with pre-installed softwares if pip is created
resource "null_resource" "prepare-deployer" {
  count                                = local.enable_deployer_public_ip && var.configure ? 0 : 0
  depends_on                           = [azurerm_linux_virtual_machine.deployer]

  connection                             {
                                           type        = "ssh"
                                           host        = azurerm_public_ip.deployer[count.index].ip_address
                                           user        = local.username
                                           private_key = var.deployer.authentication.type == "key" ? local.private_key : null
                                           password    = lookup(var.deployer.authentication, "password", null)
                                           timeout     = var.ssh-timeout
                                         }

  provisioner "file"                     {
                                           content = templatefile(format("%s/templates/configure_deployer.sh.tmpl", path.module), {
                                             client_id            = length(var.deployer.user_assigned_identity_id) == 0 ? azurerm_user_assigned_identity.deployer[0].client_id : data.azurerm_user_assigned_identity.deployer[0].client_id ,
                                             subscription_id      = data.azurerm_subscription.primary.subscription_id,
                                             tenant_id            = data.azurerm_subscription.primary.tenant_id,
                                             local_user           = local.username
                                             agent_pool           = var.agent_pool
                                             agent_pat            = var.agent_pat
                                             agent_ado_url        = var.agent_ado_url
                                             platform             = var.platform
                                             app_token            = var.app_token
                                             repository           = var.repository
                                             server_url           = var.server_url
                                             api_url              = var.api_url
                                             use_webapp           = var.use_webapp
                                             }
                                           )

                                           destination = "/tmp/configure_deployer.sh"
                                         }

  provisioner "remote-exec"              {
                                           inline = var.deployer.os.source_image_id != "" ? [] : [
                                             //
                                             // Set useful shell options
                                             //
                                             "set -o xtrace",
                                             "set -o verbose",
                                             "set -o errexit",

                                             //
                                             // Make configure_deployer.sh executable and run it
                                             //
                                             "chmod +x /tmp/configure_deployer.sh",
                                             "/tmp/configure_deployer.sh"
                                           ]
                                         }

}

resource "local_file" "configure_deployer" {
  count                                = local.enable_deployer_public_ip ? 0 : 1
  content                              = templatefile(format("%s/templates/configure_deployer.sh.tmpl", path.module), {
                                           client_id            = length(var.deployer.user_assigned_identity_id) == 0 ? azurerm_user_assigned_identity.deployer[0].client_id : data.azurerm_user_assigned_identity.deployer[0].client_id,
                                           subscription_id      = data.azurerm_subscription.primary.subscription_id,
                                           tenant_id            = data.azurerm_subscription.primary.tenant_id,
                                           agent_pool           = var.agent_pool
                                           agent_pat            = var.agent_pat
                                           agent_ado_url        = var.agent_ado_url
                                           platform             = var.platform
                                           app_token            = var.app_token
                                           repository           = var.repository
                                           server_url           = var.server_url
                                           api_url              = var.api_url
                                           use_webapp           = var.use_webapp
                                           }
                                         )
  filename                             = format("%s/configure_deployer.sh", path.cwd)
  file_permission                      = "0660"
  directory_permission                 = "0770"
}
