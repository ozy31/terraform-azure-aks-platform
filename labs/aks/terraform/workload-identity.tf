# Workload identity: a pod signs in to Azure with no secret.
# AWS: IRSA / EKS Pod Identity (service account -> IAM role).

# 1) The app's identity in Azure (the IAM role in AWS terms).
resource "azurerm_user_assigned_identity" "app_reader" {
  name                = "id-app-reader"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
}

# 2) Read-only data-plane role on this one storage account.
data "azurerm_storage_account" "lab" {
  name                = var.storage_account_name
  resource_group_name = "rg-lab-core"
}

resource "azurerm_role_assignment" "app_reader_blob" {
  scope                = data.azurerm_storage_account.lab.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app_reader.principal_id
}

# 3) Federated credential: Entra ID trusts tokens from THIS cluster's issuer
#    for THIS service account only (subject = system:serviceaccount:<namespace>:<name>).
resource "azurerm_federated_identity_credential" "app_reader" {
  name                = "fic-demo-blob-reader"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.app_reader.id
  issuer              = azurerm_kubernetes_cluster.lab.oidc_issuer_url
  subject             = "system:serviceaccount:demo:blob-reader"
  audience            = ["api://AzureADTokenExchange"]
}

output "app_reader_client_id" {
  value = azurerm_user_assigned_identity.app_reader.client_id
}
