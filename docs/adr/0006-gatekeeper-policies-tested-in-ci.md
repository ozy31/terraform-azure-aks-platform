# 0006. Gatekeeper policies as code, tested with gator in CI

Status: accepted

## Context

Guardrails are what make self-service safe: teams can deploy without a ticket
because the platform rejects what would hurt others. Azure Policy for AKS can
enforce built-in definitions, but custom policies are harder to write and test,
and results arrive in the Azure portal rather than at `kubectl apply`.

## Decision

Run OPA Gatekeeper from Git with platform-specific constraint templates:

| Policy | Why |
|---|---|
| Allowed registries + pinned tags | Only images from the platform ACR (or MCR); no `latest` |
| Required requests and memory limit | Node Auto-Provisioning and quotas depend on requests |
| No LoadBalancer / NodePort services | Traffic goes through the shared Gateway |
| HTTPRoute hostnames from `tenant.yaml` | One team cannot take another team's hostname |

- ExpansionTemplates evaluate pod policies against Deployments, StatefulSets,
  Jobs and CronJobs, so a bad manifest fails at apply time instead of leaving
  a ReplicaSet that cannot create pods.
- Constraints match only namespaces labelled as tenants.
- Every policy has allow and deny cases in `gitops/policies/tests`, run with
  `gator verify` in CI.

## Consequences

- A policy change is reviewed and tested like code before it reaches a
  cluster.
- The webhook fails closed; Gatekeeper runs three replicas with a PDB.
- Azure Policy can still be enabled for organisation-wide baselines; the two
  do not conflict.
