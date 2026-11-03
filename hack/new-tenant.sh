#!/usr/bin/env bash
# Scaffold a tenant: gitops/tenants/<name>/{tenant.yaml,kustomization.yaml,helmrelease.yaml},
# register it in gitops/tenants/kustomization.yaml and add sample Flux values
# for validation. Review the result and open a pull request.
#
#   hack/new-tenant.sh <name> <entra-group-object-id> <cost-center> [hostname...]
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 3 ]]; then
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

name="$1" group="$2" cost="$3"
shift 3
dir="gitops/tenants/$name"
var="$(tr 'a-z-' 'A-Z_' <<<"$name")"

[[ "$name" =~ ^[a-z][a-z0-9-]{1,18}[a-z0-9]$ ]] || { echo "invalid name: 3-20 lowercase letters, digits, hyphens" >&2; exit 1; }
[[ "$group" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || { echo "owner must be an Entra group object ID" >&2; exit 1; }
[[ ! -e "$dir" ]] || { echo "$dir already exists" >&2; exit 1; }

mkdir -p "$dir"

{
  echo "# Read by Terraform (Azure RBAC, workload identity, Key Vault) and by"
  echo "# charts/tenant (namespace, quota, network and mesh policy)."
  echo "name: $name"
  echo "displayName: $(awk -F- -v OFS=' ' '{for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)} 1' <<<"$name")"
  echo "ownerGroupId: $group"
  echo "costCenter: $cost"
  echo "serviceAccounts:"
  echo "  - app"
  echo "keyVault: true"
  if [[ $# -gt 0 ]]; then
    echo "hostnames:"
    for h in "$@"; do echo "  - $h"; done
  else
    echo "hostnames: []"
  fi
} > "$dir/tenant.yaml"

cat > "$dir/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources:
  - helmrelease.yaml
# tenant.yaml becomes the chart values. Terraform reads the same file.
configMapGenerator:
  - name: tenant-$name
    files:
      - values.yaml=tenant.yaml
generatorOptions:
  disableNameSuffixHash: true
  labels:
    # helm-controller reconciles the release when the ConfigMap changes.
    reconcile.fluxcd.io/watch: Enabled
YAML

cat > "$dir/helmrelease.yaml" <<YAML
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: tenant-$name
  namespace: flux-system
spec:
  interval: 30m
  targetNamespace: $name
  storageNamespace: flux-system
  # Teams have edit rights in their namespace; drift detection restores the
  # guardrails this chart owns (network policies, quota, mesh policy).
  driftDetection:
    mode: enabled
  releaseName: tenant-$name
  chart:
    spec:
      chart: ./charts/tenant
      reconcileStrategy: Revision
      sourceRef:
        kind: GitRepository
        name: platform
  valuesFrom:
    - kind: ConfigMap
      name: tenant-$name
      valuesKey: values.yaml
  values:
    azure:
      tenantId: \${AZURE_TENANT_ID}
      workloadClientId: \${TENANT_${var}_CLIENT_ID}
      keyVaultUri: \${TENANT_${var}_KEY_VAULT_URI}
YAML

yq -i ".resources += [\"$name\"] | .resources |= (unique)" gitops/tenants/kustomization.yaml

n="$(grep -c '^TENANT_.*_CLIENT_ID=' hack/flux-vars.env)"
printf 'TENANT_%s_CLIENT_ID=00000000-0000-0000-0001-%012d\nTENANT_%s_KEY_VAULT_URI=https://kv-plat-prod-%s.vault.azure.net/\n' \
  "$var" "$((n + 1))" "$var" "$name" >> hack/flux-vars.env

echo "created $dir; next: review tenant.yaml (quota), then run: make tenants tftest manifests"
