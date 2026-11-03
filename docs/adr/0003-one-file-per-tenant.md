# 0003. One `tenant.yaml` per team drives both Azure and Kubernetes

Status: accepted

## Context

Onboarding a team touches two worlds: Azure (RBAC, workload identity, a Key
Vault) and the cluster (namespace, quota, network and mesh policy, service
accounts). Keeping them in two places means they drift, and onboarding needs
two tickets.

## Decision

A team is a directory `gitops/tenants/<name>/` with one `tenant.yaml`:

- Terraform reads every `*/tenant.yaml` with `fileset` + `yamldecode` and
  creates one `modules/tenant` instance per directory.
- Flux turns the same file into a ConfigMap (`configMapGenerator`) and passes
  it as values to `charts/tenant`.
- What only Terraform knows (the identity client ID, the Key Vault URI) is
  added by Flux substitution in the tenant's HelmRelease.

## Consequences

- Onboarding is one pull request, reviewed once, and CI checks both sides:
  the chart's JSON schema, the Terraform variable validation, unique
  hostnames and directory/name consistency (`hack/check-tenants.sh`).
- The namespace has `helm.sh/resource-policy: keep`, so removing a directory
  does not delete a team's workloads by accident. Offboarding is a runbook.
- The two consumers ignore each other's keys; the Terraform variable is an
  object type, so extra keys are dropped rather than rejected.
