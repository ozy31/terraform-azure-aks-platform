# Control-plane and data-plane audit logs go to the platform Log Analytics
# workspace. kube-audit-admin leaves out get/list/watch, which keeps the
# volume (and the bill) far below full kube-audit while still answering
# "who changed this". Resource-specific tables (AKSAuditAdmin, AKSControlPlane)
# are cheaper to query than AzureDiagnostics.

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                           = "diag-to-log-analytics"
  target_resource_id             = module.aks.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }

  enabled_log {
    category = "kube-controller-manager"
  }
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-to-log-analytics"
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }
}

resource "azurerm_monitor_diagnostic_setting" "platform_kv" {
  name                       = "diag-to-log-analytics"
  target_resource_id         = azurerm_key_vault.platform.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "audit"
  }
}
