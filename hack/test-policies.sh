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
