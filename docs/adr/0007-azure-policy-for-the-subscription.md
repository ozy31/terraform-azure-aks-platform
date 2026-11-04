# 0007. Azure Policy for Azure resources, Gatekeeper for Kubernetes objects

Status: accepted

## Context

Gatekeeper (ADR 0006) only sees Kubernetes objects. The Azure resources around
the cluster (Key Vaults, identities, disks, anything a team or another pipeline
creates in the subscription) need their own guardrails, and those must hold
even for resources this repository does not manage.

## Decision

Assign built-in Azure Policy definitions at subscription scope from
`terraform/modules/policy`:

| Assignment | Effect | Why |
|---|---|---|
| Allowed locations / allowed locations for resource groups | Deny | Data stays in UK South and UK West |
| Require `cost-center` on resource groups | Deny | Every resource group has an owner who pays for it |
| Inherit `cost-center` from the resource group | Modify | Cost reports split by team without tagging every resource by hand |

- Built-ins are looked up by display name, so a plan shows what is assigned
  instead of a GUID.
- `enforce = false` switches every assignment to `DoNotEnforce`: new
  guardrails go out audit-only first, and are enforced once the compliance
  view is clean.
- The modify assignments get their own identities with `Tag Contributor` only.
  The apply pipeline gets `Resource Policy Contributor`, and `Tag Contributor`
  is added to the roles its ABAC condition lets it grant.
- Azure Policy for AKS (the add-on) is not enabled: Gatekeeper already runs
  from Git, and two admission controllers would give two sources of truth.

## Consequences

- A resource group created without `cost-center`, by anyone, is denied. Tag
  changes are therefore made on the resource group, not on single resources.
- Existing non-compliant resources are not changed by a modify policy until a
  remediation task runs: `az policy remediation create --policy-assignment inherit-rg-tag-cost-center`.
- In a larger estate these assignments belong at a management group in the
  landing zone, and this module would only add platform-specific ones.
