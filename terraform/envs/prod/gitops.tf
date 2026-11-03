# Flux is installed as the AKS cluster extension and configured through ARM.
# Terraform never talks to the Kubernetes API, so the API server can stay
# behind authorized IP ranges (or fully private) and the pipeline needs no
# kubeconfig.

locals {
  # Values only Terraform knows, injected into manifests with Flux
  # post-build substitution (${VAR} in gitops/). Nothing generated is committed.
  flux_substitutions = merge(
    {
      CLUSTER_NAME               = module.aks.name
      ACR_LOGIN_SERVER           = azurerm_container_registry.this.login_server
      AZURE_TENANT_ID            = var.entra_tenant_id
      AZURE_SUBSCRIPTION_ID      = var.subscription_id
      DNS_ZONE_NAME              = azurerm_dns_zone.this.name
      DNS_RESOURCE_GROUP         = azurerm_resource_group.platform.name
      ACME_EMAIL                 = var.acme_email
      PLATFORM_KEY_VAULT_URI     = azurerm_key_vault.platform.vault_uri
      CERT_MANAGER_CLIENT_ID     = module.platform_identities.client_ids["cert-manager"]
      EXTERNAL_DNS_CLIENT_ID     = module.platform_identities.client_ids["external-dns"]
      EXTERNAL_SECRETS_CLIENT_ID = module.platform_identities.client_ids["external-secrets"]
    },
    merge([
      for name, t in module.tenant : {
        "TENANT_${upper(replace(name, "-", "_"))}_CLIENT_ID"     = t.workload_client_id
        "TENANT_${upper(replace(name, "-", "_"))}_KEY_VAULT_URI" = t.key_vault_uri
      }
    ]...)
  )

  flux_kustomizations = {
    infra-controllers = { path = "./gitops/infrastructure/controllers", depends_on = [] }
    infra-configs     = { path = "./gitops/infrastructure/configs", depends_on = ["infra-controllers"] }
    monitoring        = { path = "./gitops/monitoring", depends_on = ["infra-configs"] }
    policy-templates  = { path = "./gitops/policies/templates", depends_on = ["infra-controllers"] }
    policies          = { path = "./gitops/policies/constraints", depends_on = ["policy-templates"] }
    tenants           = { path = "./gitops/tenants", depends_on = ["infra-configs", "policies"] }
  }
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "flux"
  cluster_id     = module.aks.id
  extension_type = "microsoft.flux"
  release_train  = "Stable"

  configuration_settings = {
    # Single trusted platform repository; tenant isolation is enforced by
    # Azure RBAC, Gatekeeper and network policy rather than by Flux tenancy.
    "multiTenancy.enforce"                = "false"
    "image-automation-controller.enabled" = "false"
    "image-reflector-controller.enabled"  = "false"
  }
}

resource "azurerm_kubernetes_flux_configuration" "platform" {
  name       = "platform"
  cluster_id = module.aks.id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url                      = var.gitops_repo_url
    reference_type           = "branch"
    reference_value          = var.gitops_branch
    sync_interval_in_seconds = 120
  }

  dynamic "kustomizations" {
    for_each = local.flux_kustomizations

    content {
      name                       = kustomizations.key
      path                       = kustomizations.value.path
      depends_on                 = kustomizations.value.depends_on
      garbage_collection_enabled = true
      wait                       = true
      sync_interval_in_seconds   = 600
      retry_interval_in_seconds  = 60
      timeout_in_seconds         = 900

      post_build {
        substitute = local.flux_substitutions
      }
    }
  }

  depends_on = [azurerm_kubernetes_cluster_extension.flux]
}
