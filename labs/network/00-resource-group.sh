#!/usr/bin/env bash
# Resource group rg-lab-core: a folder for resources that live and die together.
# It is a management and lifecycle boundary, not a network boundary, and cannot be nested.
# Deleting it deletes everything inside: az group delete -n rg-lab-core
# Portal: search "Resource groups" -> rg-lab-core.  AWS: closest is a tagged CloudFormation stack.
source "$(dirname "$0")/../lib.sh"
az group create -n rg-lab-core -l "$LOCATION" \
  --tags env=lab purpose=interview-prep costCenter=personal -o table
