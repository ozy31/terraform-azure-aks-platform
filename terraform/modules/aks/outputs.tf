output "id" {
  description = "Cluster resource ID. Namespace-scoped Azure RBAC assignments use \"<id>/namespaces/<name>\"."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "Cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "OIDC issuer for workload identity federated credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Kubelet identity object ID."
  value       = azurerm_user_assigned_identity.kubelet.principal_id
}

output "node_resource_group" {
  description = "Resource group AKS manages for nodes and load balancers."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
