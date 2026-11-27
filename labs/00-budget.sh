#!/usr/bin/env bash
# Cost Management budget at subscription scope: $20/month, mail at 50% and 80% actual
# and 100% forecast. A budget only ALERTS; it never stops spending.
# Portal: search "Budgets" -> budget-lab.  AWS: AWS Budgets.
source "$(dirname "$0")/lib.sh"
: "${LAB_BUDGET_EMAIL:?set LAB_BUDGET_EMAIL}"
SUB=$(az account show --query id -o tsv)
START=$(date -u +%Y-%m-01T00:00:00Z)
notif() { printf '"%s":{"enabled":true,"operator":"GreaterThan","threshold":%s,"thresholdType":"%s","contactEmails":["%s"]}' "$1" "$2" "$3" "$LAB_BUDGET_EMAIL"; }
az rest --method put \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Consumption/budgets/budget-lab?api-version=2023-05-01" \
  --body "{\"properties\":{\"category\":\"Cost\",\"amount\":20,\"timeGrain\":\"Monthly\",
    \"timePeriod\":{\"startDate\":\"$START\",\"endDate\":\"2027-11-01T00:00:00Z\"},
    \"notifications\":{$(notif actual50 50 Actual),$(notif actual80 80 Actual),$(notif forecast100 100 Forecasted)}}}" -o none
echo "budget-lab ready"
