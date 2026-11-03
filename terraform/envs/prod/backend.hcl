# Placeholder values; replace with the outputs of terraform/bootstrap/github-oidc.
resource_group_name  = "rg-plat-tfstate"
storage_account_name = "stplattfstate0001"
container_name       = "tfstate"
key                  = "prod-uksouth.tfstate"
use_azuread_auth     = true
