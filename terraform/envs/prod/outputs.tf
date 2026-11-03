output "cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.name
}

output "get_credentials" {
  description = "Command for humans to get an Entra-authenticated kubeconfig."
  value       = "az aks get-credentials -g ${azurerm_resource_group.platform.name} -n ${module.aks.name} && kubelogin convert-kubeconfig -l azurecli"
}

output "egress_ip_prefix" {
  description = "Egress IP prefix to give partners for allow-listing."
  value       = module.network.egress_ip_prefix
}

output "dns_name_servers" {
  description = "Delegate the DNS zone to these name servers."
  value       = azurerm_dns_zone.this.name_servers
}

output "tenants" {
  description = "Per-tenant namespace, workload identity client ID and Key Vault URI."
  value = {
    for k, t in module.tenant : k => {
      namespace          = t.namespace
      workload_client_id = t.workload_client_id
      key_vault_uri      = t.key_vault_uri
    }
  }
}

output "flux_substitution_keys" {
  description = "Variables available to manifests as $${VAR} (values are not secret but are omitted here to keep plans short)."
  value       = sort(keys(local.flux_substitutions))
}
