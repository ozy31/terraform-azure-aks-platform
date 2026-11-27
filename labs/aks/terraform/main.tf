# The cluster gets its own resource group; the network stays in rg-lab-core.
resource "azurerm_resource_group" "aks" {
  name     = "rg-lab-aks"
  location = var.location
  tags = {
    env     = "lab"
    purpose = "interview-prep"
  }
}

# Read (data) the subnet from the other resource group; nodes join rg-lab-core/vnet-spoke/snet-aks.
data "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  virtual_network_name = "vnet-spoke"
  resource_group_name  = "rg-lab-core"
}

data "azurerm_client_config" "me" {}
