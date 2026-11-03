# 0002. Authorise Kubernetes access with Azure RBAC, scoped to namespaces

Status: accepted

## Context

Hundreds of developers across many teams need access to their own workloads
and nothing else. Kubernetes RoleBindings for Entra groups work, but they live
inside the cluster, can be edited by anyone with enough rights there, and are
invisible to Azure access reviews.

## Decision

- Local accounts are disabled; every user and pipeline authenticates with Entra ID.
- Authorisation uses Azure RBAC for Kubernetes (`azure_rbac_enabled = true`).
- Each team's Entra group gets `Azure Kubernetes Service RBAC Writer` at the
  scope `<cluster-id>/namespaces/<team>` plus `Cluster User Role` to fetch a
  kubeconfig. Both are created by the tenant Terraform module.
- Only the platform team's group is in `admin_group_object_ids`.

## Consequences

- Access is reviewed and audited with the rest of the Azure estate (PIM,
  access reviews, activity log), and can't drift inside the cluster.
- Removing someone from the Entra group removes cluster access everywhere.
- Writer cannot change RBAC or resource quotas in its namespace. It can edit
  objects such as NetworkPolicies, so the tenant HelmRelease runs with drift
  detection: Flux puts the chart-owned guardrails back on the next reconcile.
- Azure RBAC role assignments take a few minutes to propagate, which shows up
  as a short delay during onboarding.
