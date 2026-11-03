#!/usr/bin/env bash
# Render every platform HelmRelease with the exact chart version and values
# from gitops/ (Flux variables resolved from hack/flux-vars.env), so a typo in
# values or an incompatible chart upgrade fails here instead of in the cluster.
# Output: .rendered/platform/<release>.yaml
set -euo pipefail

cd "$(dirname "$0")/.."
out=".rendered/platform"
rm -rf "$out" && mkdir -p "$out"

set -a
# shellcheck source=/dev/null
source hack/flux-vars.env
set +a

sources="$(kustomize build gitops/infrastructure/controllers | yq ea -o=json '[select(.kind == "HelmRepository")] | map({"key": .metadata.name, "value": .spec.url}) | from_entries')"

for dir in gitops/infrastructure/controllers gitops/monitoring; do
  kustomize build "$dir" | flux envsubst --strict | yq ea -o=json -I0 'select(.kind == "HelmRelease")' |
    while read -r hr; do
      name="$(jq -r '.spec.releaseName' <<<"$hr")"
      ns="$(jq -r '.spec.targetNamespace' <<<"$hr")"
      chart="$(jq -r '.spec.chart.spec.chart' <<<"$hr")"
      version="$(jq -r '.spec.chart.spec.version' <<<"$hr")"
      repo="$(jq -r --arg s "$(jq -r '.spec.chart.spec.sourceRef.name' <<<"$hr")" '.[$s]' <<<"$sources")"
      jq '.spec.values // {}' <<<"$hr" > "$out/$name.values.json"
      echo "--- $name ($chart $version)"
      helm template "$name" "$chart" --repo "$repo" --version "$version" \
        --namespace "$ns" --include-crds --values "$out/$name.values.json" > "$out/$name.yaml"
      rm "$out/$name.values.json"
    done
done
