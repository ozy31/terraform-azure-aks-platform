# Onboarding a team

Time: one pull request, about 15 minutes after merge (Terraform apply, then
the next Flux reconcile).

## 1. Pull request

Scaffold the tenant:

```bash
make tenant NAME=returns GROUP=<entra-group-object-id> COST=CC-3105 \
  HOSTS="returns.platform.example.co.uk"
```

This writes `gitops/tenants/returns/` (`tenant.yaml`, `kustomization.yaml`,
`helmrelease.yaml`), lists it in `gitops/tenants/kustomization.yaml` and adds
sample Flux values to `hack/flux-vars.env` so CI can validate it. Then adjust
`tenant.yaml` (quota, extra service accounts).

`tenant.yaml`:

| Key | Notes |
|---|---|
| `name` | Must equal the directory name; 3-20 characters, becomes the namespace |
| `ownerGroupId` | Object ID of the team's Entra group (not its name or e-mail) |
| `costCenter` | Becomes a namespace label and an Azure tag for cost reports |
| `serviceAccounts` | Each gets a federated credential for the team's workload identity |
| `hostnames` | Hostnames the team may use in HTTPRoutes; must be unique across teams |
| `quota` | Optional; defaults in `charts/tenant/values.yaml` |
| `keyVault` | `true` creates a Key Vault for the team (default) |

Run `make tenants tftest manifests` locally or let CI do it. The PR shows a
Terraform plan with the new role assignments, identity and Key Vault.

## 2. After merge

1. The `terraform` workflow applies (after environment approval). It creates
   the Azure side and adds `TENANT_RETURNS_*` to the Flux substitutions.
2. Flux reconciles `tenants`: namespace, quota, limit range, network
   policies, AuthorizationPolicy, service accounts, SecretStore.
3. Check:

```bash
kubectl get ns returns --show-labels
flux get helmreleases -n flux-system tenant-returns
kubectl -n returns get sa,quota,netpol,secretstore
```

## 3. Hand-over to the team

- `az aks get-credentials -g rg-plat-prod-uks -n aks-plat-prod-uks` then
  `kubelogin convert-kubeconfig -l azurecli`. Members of the Entra group get
  write access to their namespace only.
- Secrets: create them in the team Key Vault, then reference them with an
  `ExternalSecret` using `secretStoreRef: {kind: SecretStore, name: tenant-kv}`.
- Azure access from pods: add the label `azure.workload.identity/use: "true"`
  to the pod template and use one of the declared service accounts.
- Ingress: an `HTTPRoute` with `parentRefs: [{name: public, namespace:
  istio-ingress, sectionName: https}]` and one of the declared hostnames.
  DNS and the certificate are already handled.
- Images must come from the platform ACR with a version tag, and every
  container needs CPU/memory requests and a memory limit.

## Offboarding

Remove the directory and its line in `gitops/tenants/kustomization.yaml`.
Terraform removes the access and identity; the Key Vault is soft-deleted and
purge-protected for 90 days. The namespace is kept (`helm.sh/resource-policy:
keep`); delete it explicitly once the team confirms its data is gone.
