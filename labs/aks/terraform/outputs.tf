output "cluster_name" { value = azurerm_kubernetes_cluster.lab.name }
output "node_resource_group" { value = azurerm_kubernetes_cluster.lab.node_resource_group }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.lab.oidc_issuer_url }
output "kubernetes_version" { value = azurerm_kubernetes_cluster.lab.current_kubernetes_version }
