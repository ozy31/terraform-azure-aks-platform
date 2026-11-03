# 0005. Node Auto-Provisioning (Karpenter) instead of fixed node pools

Status: accepted

## Context

With many teams and workload shapes, fixed node pools with the cluster
autoscaler end up as either many pools (operational overhead, fragmentation)
or a few oversized ones (waste). Each new VM size is a Terraform change.

## Decision

- The default node pool is a small, zonal system pool with
  `only_critical_addons_enabled`, sized for CoreDNS, Cilium, Flux, Gatekeeper
  and istiod.
- Application capacity comes from Node Auto-Provisioning (`mode = "Auto"`),
  the managed Karpenter on AKS. NodePools are Kubernetes objects in Git
  (`gitops/infrastructure/configs/nodepools.yaml`): `general` for on-demand D
  and E series across three zones, `spot` (tainted) for interruptible work.
- Disruption budgets cap voluntary disruption at 10% of nodes and block
  consolidation during UK trading hours.

## Consequences

- New VM families or limits are a reviewed YAML change, not a Terraform apply.
- Pods must declare requests, because NAP sizes nodes from them; Gatekeeper
  enforces this for tenant namespaces.
- NAP requires Azure CNI Overlay with the Cilium data plane, which this
  platform uses anyway.
