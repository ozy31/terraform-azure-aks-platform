output "github_variables" {
  description = "Set these as GitHub Actions variables (not secrets: none of them are sensitive)."
  value = {
    AZURE_TENANT_ID       = var.entra_tenant_id
    AZURE_SUBSCRIPTION_ID = var.subscription_id
    AZURE_CLIENT_ID_PLAN  = azuread_application.github["plan"].client_id
    AZURE_CLIENT_ID_APPLY = azuread_application.github["apply"].client_id
  }
}

output "backend_config" {
  description = "Contents for terraform/envs/<env>/backend.hcl."
  value = {
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.state.name
  }
}

output "azure_devops_service_connections" {
  description = "Create these Azure Resource Manager service connections (workload identity federation, manual) in Azure DevOps."
  value = var.azure_devops == null ? null : {
    for id in ["plan", "apply"] : "azure-plat-${id}" => {
      client_id       = azuread_application.github[id].client_id
      tenant_id       = var.entra_tenant_id
      subscription_id = var.subscription_id
    }
  }
}
