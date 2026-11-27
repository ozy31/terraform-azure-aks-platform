#!/usr/bin/env bash
# Sourced by every lab script. Refuses to run unless the CLI is pointed at the lab
# subscription and, optionally, the lab user, so nothing lands in a work tenant by mistake.
#   export LAB_SUBSCRIPTION="<subscription name or id>"
#   export LAB_USER="<the account you log in with>"   # optional
#   export LOCATION="swedencentral"                    # optional
set -euo pipefail
: "${LAB_SUBSCRIPTION:?set LAB_SUBSCRIPTION to the lab subscription name or id}"
LOCATION="${LOCATION:-swedencentral}"
az account set --subscription "$LAB_SUBSCRIPTION"
if [[ -n "${LAB_USER:-}" ]]; then
  current_user=$(az account show --query user.name -o tsv)
  if [[ "$current_user" != "$LAB_USER" ]]; then
    echo "STOP: logged in as $current_user, expected $LAB_USER" >&2
    exit 1
  fi
fi
step() { printf '\n\033[1;34m> %s\033[0m\n' "$*"; }
