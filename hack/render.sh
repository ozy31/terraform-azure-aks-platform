#!/usr/bin/env bash
# Render the tenant chart once per tenant, with placeholder values for what
# Terraform injects at runtime, into .rendered/tenants/<name>.yaml.
set -euo pipefail

cd "$(dirname "$0")/.."
out=".rendered/tenants"
rm -rf "$out" && mkdir -p "$out"

for dir in gitops/tenants/*/; do
  name="$(basename "$dir")"
  helm template "tenant-$name" charts/tenant \
    --namespace "$name" \
    --values "$dir/tenant.yaml" \
    --set azure.tenantId=00000000-0000-0000-0000-000000000000 \
    --set azure.workloadClientId=00000000-0000-0000-0000-000000000000 \
    --set azure.keyVaultUri="https://kv-$name.vault.azure.net/" \
    > "$out/$name.yaml"
done
echo "rendered $(find "$out" -name '*.yaml' | wc -l | tr -d ' ') tenants"
