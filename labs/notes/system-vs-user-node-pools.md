# System vs user node pools, compared with tainted node groups on EKS

## In short
- **System pool**: Kubernetes' own components (CoreDNS, metrics-server, konnectivity).
  - Every cluster must have at least one.
  - It can't scale to zero, can't be Spot, Linux only.
- **User pool**: applications.
  - Can scale to zero; can be Spot, GPU or Windows.
- **On EKS** we built the same thing ourselves: a dedicated node group (ASG) with a taint, and
  tolerations on CoreDNS. That is a **convention**: change the taint or the launch template and
  those become ordinary nodes.
- **On AKS** the pool has a **mode**. AKS places its components on `kubernetes.azure.com/mode=system`
  nodes itself, and the API enforces the rules: a **platform guarantee**.
- I still add the `CriticalAddonsOnly` taint on AKS (Terraform: `only_critical_addons_enabled = true`),
  so application pods stay off the system pool.

## Interview answer
> On EKS we did this ourselves: a dedicated node group with taints, and tolerations on CoreDNS
> and the other critical add-ons. It worked, but it was a convention — if someone changed the
> launch template or dropped the taint, those became normal nodes and nothing stopped it.
> On AKS it's a first-class concept: the node pool has a mode, AKS places its own components on
> system nodes, and the API enforces the rules — you can't scale the system pool to zero, delete
> the last one, or run it on Spot. So the separation we maintained by discipline on EKS is
> guaranteed by the platform on AKS. I still add the CriticalAddonsOnly taint so application
> pods stay off it.

## Follow-up questions
| Question | Answer |
|---|---|
| How many system nodes in production? | 3 nodes across 3 availability zones; a zone failure doesn't take DNS down. |
| What size? | At least 4 vCPU; too small and CoreDNS/konnectivity get squeezed. |
| Upgrade order? | Control plane → system pool → user pools, each with surge and PDBs. |
| Doesn't EKS have this? | Not as a mode. You build it with tainted node groups; EKS Auto Mode has a built-in system NodePool. |

## Seen in the lab
- `labs/aks/terraform/aks.tf`: `default_node_pool` (system, tainted) + `azurerm_kubernetes_cluster_node_pool.user`.
- `kubectl get nodes -o wide` and `kubectl describe node`: the system node carries the
  `CriticalAddonsOnly` taint, and test nginx pods only scheduled on the user node.
