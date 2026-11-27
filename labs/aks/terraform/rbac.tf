# Local accounts are disabled, so without an Azure RBAC role even the creator can't use kubectl.
resource "azurerm_role_assignment" "me_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.lab.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.me.object_id
}
