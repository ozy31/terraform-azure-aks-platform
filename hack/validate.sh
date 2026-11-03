#!/usr/bin/env bash
# Validate every Kubernetes manifest against the Kubernetes and CRD schemas
# (run hack/schemas.sh, hack/render.sh and hack/render-platform.sh first).
set -euo pipefail

cd "$(dirname "$0")/.."
K8S_VERSION="${K8S_VERSION:-1.34.0}"

# Resolve Flux substitutions the way kustomize-controller does, failing on any
# variable that has no value.
set -a
# shellcheck source=/dev/null
source hack/flux-vars.env
set +a

build() {
  kustomize build "$1" | flux envsubst --strict
}

kc() {
  kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" \
    -schema-location default \
    -schema-location '.schemas/{{.Group}}_{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' "$@"
}

for k in gitops/infrastructure/controllers gitops/infrastructure/configs gitops/monitoring gitops/monitoring/configs gitops/policies/templates gitops/tenants; do
  echo "--- $k"
  build "$k" | kc -
done

# Constraint kinds are generated from the templates at runtime, so they have
# no schema here; gator (hack/test-policies.sh) checks them instead.
echo "--- gitops/policies/constraints"
build gitops/policies/constraints | kc -ignore-missing-schemas -

for example in examples/*/; do
  echo "--- $example"
  build "$example" | kc -
done

echo "--- rendered tenant chart"
kc .rendered/tenants

# Charts ship their own CRDs, which have no schema here.
echo "--- rendered platform charts"
kc -ignore-missing-schemas .rendered/platform
