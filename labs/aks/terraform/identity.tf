# Control-plane identity: AKS creates load balancers, public IPs and disks with it.
# User-assigned, so the role below can be granted BEFORE the cluster exists.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-lab"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
}

# The subnet lives in another resource group, so the cluster needs rights on it,
# scoped to that one subnet only, not the VNet or the subscription.
resource "azurerm_role_assignment" "aks_subnet" {
  scope                = data.azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}
