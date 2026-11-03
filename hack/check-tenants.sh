#!/usr/bin/env bash
# Checks Terraform and Helm cannot express on their own:
#   - tenant.yaml "name" matches its directory (Terraform uses the directory)
#   - every tenant directory is listed in gitops/tenants/kustomization.yaml
#   - no hostname is claimed by two tenants
#   - every ${VAR} used in gitops/ is provided by terraform/envs/prod/gitops.tf
#     and has a sample value in hack/flux-vars.env
set -euo pipefail

cd "$(dirname "$0")/.."
fail=0

for dir in gitops/tenants/*/; do
  name="$(basename "$dir")"
  declared="$(yq '.name' "$dir/tenant.yaml")"
  if [[ "$declared" != "$name" ]]; then
    echo "gitops/tenants/$name/tenant.yaml: name is \"$declared\", expected \"$name\""; fail=1
  fi
  if ! yq -e ".resources[] | select(. == \"$name\")" gitops/tenants/kustomization.yaml >/dev/null; then
    echo "gitops/tenants/$name is not listed in gitops/tenants/kustomization.yaml"; fail=1
  fi
done

dupes="$(yq -N '.hostnames[]' gitops/tenants/*/tenant.yaml | sort | uniq -d)"
if [[ -n "$dupes" ]]; then
  echo "hostnames claimed by more than one tenant:"; echo "$dupes"; fail=1
fi

# shellcheck disable=SC2016 # the pattern is a literal ${VAR}
for var in $(grep -rhoE '\$\{[A-Z_]+\}' gitops | tr -d '${}' | sort -u); do
  if [[ "$var" =~ ^TENANT_(.+)_(CLIENT_ID|KEY_VAULT_URI)$ ]]; then
    dir="$(echo "${BASH_REMATCH[1]}" | tr 'A-Z_' 'a-z-')"
    [[ -d "gitops/tenants/$dir" ]] || { echo "\${$var} refers to missing tenant $dir"; fail=1; }
  elif ! grep -qE "^\s+$var\s+=" terraform/envs/prod/gitops.tf; then
    echo "\${$var} is used in gitops/ but not set in terraform/envs/prod/gitops.tf"; fail=1
  fi
  grep -q "^$var=" hack/flux-vars.env || { echo "\${$var} has no sample value in hack/flux-vars.env"; fail=1; }
done

[[ $fail -eq 0 ]] && echo "tenants and Flux variables OK"
exit $fail
