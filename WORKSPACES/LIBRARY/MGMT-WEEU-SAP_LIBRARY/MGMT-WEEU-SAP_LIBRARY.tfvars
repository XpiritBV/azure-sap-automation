# The environment value is a mandatory field, it is used for partitioning the environments, for example (PROD and NP)
environment="MGMT"

# The location valus is a mandatory field, it is used to control where the resources are deployed
location="northeurope"

# Defines the DNS suffix for the resources
dns_label = "azure.sapcontoso.com"

# use_private_endpoint defines that the storage accounts and key vaults have private endpoints enabled
use_private_endpoint = false
