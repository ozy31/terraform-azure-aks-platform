#!/usr/bin/env bash
# Run the Gatekeeper policy tests and make sure the test copies of the
# constraints still match gitops/policies/constraints (with Flux variables
# resolved to the test values).
set -euo pipefail

cd "$(dirname "$0")/.."
cases="gitops/policies/tests/cases"

python3 - "$cases" <<'PY'
import pathlib, re, sys

cases = pathlib.Path(sys.argv[1])
src = pathlib.Path("gitops/policies/constraints/constraints.yaml").read_text()
resolved = src.replace("${ACR_LOGIN_SERVER}", "acrtest.azurecr.io")
failed = False
for doc in resolved.split("\n---\n"):
    body = doc[doc.index("apiVersion"):].strip()
    kind = re.search(r"^kind: Platform(\w+)", body, re.M).group(1)
    name = re.sub(r"(?<!^)(?=[A-Z])", "-", kind).lower()
    copy = cases / f"constraint-{name}.yaml"
    text = "\n".join(l for l in copy.read_text().splitlines() if not l.startswith("#")).strip()
    if text != body:
        print(f"{copy} is out of date with constraints.yaml")
        failed = True
sys.exit(1 if failed else 0)
PY

gator verify -v gitops/policies/tests/suite.yaml

# Whole workloads through the real constraints, including ExpansionTemplates:
# the examples must pass, and every workloads/*-bad.yaml must be rejected at
# the controller level (Deployment, Job, ...), not only as a Pod.
policies="$(mktemp -d)"
trap 'rm -rf "$policies"' EXIT
# shellcheck disable=SC2016 # literal Flux variable
sed 's/${ACR_LOGIN_SERVER}/acrplatproduks.azurecr.io/' gitops/policies/constraints/constraints.yaml > "$policies/constraints.yaml"
cp gitops/policies/templates/*.yaml "$policies/"
rm "$policies/kustomization.yaml" "$policies/config.yaml"

gt() {
  # gator also reads stdin when it is not a terminal; give it nothing.
  gator test -f "$policies" -f "$cases/namespace-checkout.yaml" -f "$@" </dev/null 2> >(grep -v 'is already defined' >&2)
}

for example in examples/*/; do
  echo "--- $example (must pass)"
  kustomize build "$example" > "$policies/workload.yaml"
  gt "$policies/workload.yaml"
done

for bad in gitops/policies/tests/workloads/*-bad.yaml; do
  echo "--- $bad (must be denied)"
  if gt "$bad" >/dev/null; then
    echo "$bad was admitted"; exit 1
  fi
done
echo "workload policy tests OK"
