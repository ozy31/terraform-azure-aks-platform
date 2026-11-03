#!/usr/bin/env bash
# Lint and unit-test the platform alert rules with promtool.
set -euo pipefail

cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

yq '.spec' gitops/monitoring/configs/platform-alerts.yaml > "$tmp/rules.yaml"
cp gitops/monitoring/tests/*.test.yaml "$tmp/"

promtool check rules "$tmp/rules.yaml"
promtool test rules "$tmp"/*.test.yaml
