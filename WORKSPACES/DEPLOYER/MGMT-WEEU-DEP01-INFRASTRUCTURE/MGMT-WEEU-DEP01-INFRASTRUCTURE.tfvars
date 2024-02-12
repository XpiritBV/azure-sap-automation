{
  "infrastructure": {
    "environment"                         : "DEMO",
    "region"                              : "westeurope",
    "vnets": {
      "management": {
        "name"                            : "DEP01",
        "address_space"                   : "10.0.0.0/25",
        "subnet_mgmt": {
          "prefix"                        : "10.0.0.64/28"
        },
        "subnet_fw": {
          "prefix"                        : "10.0.0.0/26"
        }
      }
    }
  },
  "options": {
    "enable_deployer_public_ip"           : true
  },
  "firewall_deployment"                   : false
}