# 0001. Install Flux as the AKS extension and configure it through ARM

Status: accepted

## Context

The platform needs GitOps for everything inside the cluster, and Terraform for
everything in Azure. The common approach is to bootstrap Flux or Argo CD from
the Terraform pipeline with the `kubernetes`/`helm` providers, which means the
pipeline needs a kubeconfig and network access to the API server.

## Decision

Flux is installed with `azurerm_kubernetes_cluster_extension` (`microsoft.flux`)
and configured with `azurerm_kubernetes_flux_configuration`. Both are ARM
resources: Terraform talks only to Azure Resource Manager, never to the
Kubernetes API.

Values that only Terraform knows (identity client IDs, Key Vault URIs, the ACR
login server, the DNS zone) are passed to manifests through Flux post-build
substitution. Nothing generated is committed to Git.

## Consequences

- The API server can be locked down to office ranges or made fully private
  without breaking the pipeline.
- The pipeline identity has no Kubernetes permissions at all.
- Microsoft ships the Flux version with the extension, so it can lag upstream.
  Manifests use only the GA APIs (`source/v1`, `helm/v2`, `kustomize/v1`).
- `hack/check-tenants.sh` and a Terraform test make sure every `${VAR}` in
  `gitops/` is actually provided, since a missing variable only fails at
  reconcile time.
