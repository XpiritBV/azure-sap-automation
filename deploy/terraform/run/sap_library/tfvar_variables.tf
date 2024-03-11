#######################################4#######################################8
#                                                                              #
#                           Environment definitioms                            #
#                                                                              #
#######################################4#######################################8


variable "environment"                           {
                                                   description = "This is the environment name of the deployer"
                                                   type        = string
                                                   default     = ""
                                                 }

variable "codename"                              {
                                                   description = "Additional component for naming the resources"
                                                   default     = ""
                                                   type        = string
                                                 }

variable "location"                              {
                                                   description = "Defines the Azure location where the resources will be deployed"
                                                   type        = string
                                                 }

variable "name_override_file"                    {
                                                   description = "If provided, contains a json formatted file defining the name overrides"
                                                   default     = ""
                                                 }

variable "use_deployer"                          {
                                                   description = "Use deployer to deploy the resources"
                                                   default     = true
                                                 }

variable "place_delete_lock_on_resources"        {
                                                   description = "If defined, a delete lock will be placed on the key resources"
                                                   default     = false
                                                 }

variable "short_named_endpoints_nics"           {
                                                   description = "If defined, uses short names for private endpoints nics"
                                                   default     = false
                                                 }


#######################################4#######################################8
#                                                                              #
#                          Resource group definitioms                          #
#                                                                              #
#######################################4#######################################8

variable "resourcegroup_name"                   {
                                                  description = "If provided, the name of the resource group to be created"
                                                  default     = ""
                                                }

variable "resourcegroup_arm_id"                 {
                                                  description = "If provided, the Azure resource group id"
                                                  default     = ""
                                                }

variable "resourcegroup_tags"                   {
                                                  description = "Tags to be applied to the resource group"
                                                  default     = {}
                                                }


#########################################################################################
#                                                                                       #
#  SAPBits storage account                                                              #
#                                                                                       #
#########################################################################################


variable "library_sapmedia_arm_id"               {
                                                   description = "Optional Azure resource identifier for the storage account where the SAP bits will be stored"
                                                   default     = ""
                                                 }

variable "library_sapmedia_name"                 {
                                                   description = "If defined, the name of the storage account where the SAP bits will be stored"
                                                   default     = ""
                                                 }

variable "library_sapmedia_account_tier"         {
                                                   description = "The storage account tier"
                                                   default     = "Standard"
                                                 }

variable "library_sapmedia_account_replication_type" {
                                                        description = "The replication type for the storage account"
                                                        default     = "LRS"
                                                      }

variable "library_sapmedia_account_kind"         {
                                                   description = "The storage account kind"
                                                   default     = "StorageV2"
                                                 }

variable "library_sapmedia_file_share_enable_deployment" {
                                                            description = "If true, the file share will be created"
                                                            default     = true
                                                         }

variable "library_sapmedia_file_share_is_existing" {
                                                      description = "If defined use an existing file share"
                                                      default     = false
                                                    }

variable "library_sapmedia_file_share_name"      {
                                                   description = "If defined, the name of the file share"
                                                   default     = "sapbits"
                                                 }
variable "library_sapmedia_blob_container_enable_deployment" {
                                                               description = "If true, the blob container will be created"
                                                               default     = true
                                                             }

variable "library_sapmedia_blob_container_is_existing" {
                                                         description = "If defined use an existing blob container"
                                                         default     = false
                                                       }

variable "library_sapmedia_blob_container_name" {
                                                  description = "If defined, the name of the blob container"
                                                  default     = "sapbits"
}


#########################################################################################
#                                                                                       #
#  Terraform state storage account                                                              #
#                                                                                       #
#########################################################################################



variable "library_terraform_state_arm_id"        {
                                                   description = "Optional Azure resource identifier for the storage account where the terraform state will be stored"
                                                   default     = ""
                                                 }

variable "library_terraform_state_name"          {
                                                    description = "Optional name for the storage account where the terraform state will be stored"
                                                    default     = ""
                                                 }

variable "library_terraform_state_account_tier" {
                                                  description = "The storage account tier"
                                                  default     = "Standard"
}

variable "library_terraform_state_account_replication_type" {
                                                              description = "The replication type for the storage account"
                                                              default     = "LRS"
                                                            }

variable "library_terraform_state_account_kind"  {
                                                   description = "The storage account kind"
                                                   default     = "StorageV2"
                                                 }

variable "library_terraform_state_blob_container_is_existing" {
                                                                 description = "If defined use an existing blob container"
                                                                 default     = false
                                                              }

variable "library_terraform_state_blob_container_name" {
                                                          description = "If defined, the blob container name to create"
                                                          default     = "tfstate"
                                                       }

variable "library_ansible_blob_container_is_existing" {
                                                        description = "If defined use an existing blob container"
                                                        default     = false
                                                      }

variable "library_ansible_blob_container_name"   {
                                                    description = "If defined, the blob container name to create"
                                                    default     = "ansible"
                                                 }

variable "library_terraform_vars_blob_container_is_existing"  {
                                                                description = "If defined use an existing blob container for terraform vars"
                                                                default     = false
                                                              }

variable "library_terraform_vars_blob_container_name" {
                                                        description = "If defined, the blob container name to create"
                                                        default     = "tfvars"
                                                      }

variable "use_private_endpoint"                  {
                                                   description = "Boolean value indicating if private endpoint should be used for the deployment"
                                                   default     = false
                                                   type        = bool
                                                 }

#########################################################################################
#                                                                                       #
#  Miscallaneous definitioms                                                            #
#                                                                                       #
#########################################################################################

variable "spn_keyvault_id"                      {
                                                  description = "Azure resource identifier for the keyvault where the spn will be stored"
                                                  default = ""
                                                }

#########################################################################################
#                                                                                       #
#  Web App definitioms                                                                  #
#                                                                                       #
#########################################################################################

variable "use_webapp"                            {
                                                   description = "Boolean value indicating if a webapp should be created"
                                                   default     = false
                                                 }


variable "Agent_IP"                              {
                                                   description = "If provided, contains the IP address of the agent"
                                                   type        = string
                                                   default     = ""
                                                 }


variable "tfstate_resource_id"                       {
                                                       description = "Resource id of tfstate storage account"
                                                       validation {
                                                                    condition = (
                                                                      length(split("/", var.tfstate_resource_id)) == 9
                                                                    )
                                                                    error_message = "The Azure Resource ID for the storage account containing the Terraform state files must be provided and be in correct format."
                                                                  }

                                                     }

#########################################################################################
#                                                                                       #
#  DNS settings                                                                         #
#                                                                                       #
#########################################################################################

variable "use_custom_dns_a_registration"         {
                                                   description = "Boolean value indicating if a custom dns a record should be created when using private endpoints"
                                                   default     = false
                                                   type        = bool
                                                 }

variable "management_dns_subscription_id"        {
                                                   description = "String value giving the possibility to register custom dns a records in a separate subscription"
                                                   default     = ""
                                                   type        = string
                                                 }

variable "management_dns_resourcegroup_name"     {
                                                   description = "String value giving the possibility to register custom dns a records in a separate resourcegroup"
                                                   default     = ""
                                                   type        = string
                                                 }


variable "dns_zone_names"                        {
                                                   description = "Private DNS zone names"
                                                   type        = map(string)
                                                   default = {
                                                     "file_dns_zone_name"  = "privatelink.file.core.windows.net"
                                                     "blob_dns_zone_name"  = "privatelink.blob.core.windows.net"
                                                     "vault_dns_zone_name" = "privatelink.vaultcore.azure.net"
                                                   }
                                                 }

#########################################################################################
#                                                                                       #
#  App Configuration settings                                                           #
#                                                                                       #
#########################################################################################

variable "deployer_app_configuration_arm_id"         {
                                                       description = "Azure resource identifier for the app configuration"
                                                       type        = string
                                                       default     = ""
                                                     }

variable "deployer_pipeline_parameters"              {
                                                       description = "Values to define the pipeline parameters for the deployer and store them in app configuration"
                                                       type = map(object({
                                                         label = string
                                                         value = string
                                                       }))
                                                       default = null
                                                     }
variable "deployer_parameter_group_name"            {
                                                      type = string
                                                      description = "Group name for the app config key based on environment"
                                                      default = ""
                                                    }

variable "deployer_parameter_environment"           {
                                                      type = string
                                                      description = "Environment parameter value for the app config"
                                                      default = ""
                                                    }

variable "deployer_parameter_location"              {
                                                      type = string
                                                      description = "Location parameter value for the app config"
                                                      default = ""
                                                    }

variable "deployer_parameter_tf_state_filename"     {
                                                      type = string
                                                      description = "Terraform state file name after moving to remote state"
                                                      default = ""
                                                    }
variable "deployer_parameter_webapp_url_base"       {
                                                      type = string
                                                      description = "The URL of the configuration Web Application"
                                                      default = ""
                                                    }
variable "deployer_parameter_webapp_identity"       {
                                                      type = string
                                                      description = "The identity of the configuration Web Application"
                                                      default = ""
                                                    }
variable "deployer_parameter_webapp_id"             {
                                                      type = string
                                                      description = "The Azure resource ID of the configuration Web Application"
                                                      default = ""
                                                    }
