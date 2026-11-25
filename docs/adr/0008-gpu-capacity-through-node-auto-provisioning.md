# 0008. GPU capacity through Node Auto-Provisioning, scaled by KEDA

Status: accepted

## Context

Teams want to serve open-weight models (embeddings, rerankers, small
instruction models) next to their services instead of sending every call to
an external API. GPU VMs cost an order of magnitude more than the general
pool, are short on quota in most regions, and take minutes to become useful
because model weights have to load. A fixed GPU node pool is either idle and
expensive, or full when a second team arrives.

## Decision

- **One `gpu-inference` NodePool, empty by default.** Karpenter picks any
  NVIDIA SKU with one or two GPUs that the region has quota for, instead of a
  single hard-coded VM size that may be unavailable.
- **Tainted `nvidia.com/gpu=present:NoSchedule`.** Only pods that request a
  GPU and tolerate the taint land there; a stray CPU workload never keeps a
  GPU node alive.
- **A hard limit of 8 GPUs** on the NodePool. A Deployment scaled by mistake
  hits the limit and stays Pending, which alerts, instead of creating a bill.
- **Consolidation only when empty.** Moving a serving pod to pack nodes means
  reloading the model while traffic is waiting. Empty nodes are removed after
  10 minutes; busy ones stay until `expireAfter`.
- **KEDA, not the CPU HPA, scales inference.** GPU servers are often bound by
  queue depth or tokens per second while CPU sits idle. KEDA scales on the
  serving metrics in Prometheus (for example the number of waiting requests)
  and can scale a model to zero where a cold start is acceptable. The NodePool
  then follows the pods.
- **VPA in recommendation mode for the CPU side** (tokenizers, gateways,
  queue workers), so Karpenter sizes the general nodes from real requests.

## Consequences

- The NVIDIA device plugin has to run on GPU nodes before pods can request
  `nvidia.com/gpu`; it belongs in `gitops/infrastructure/controllers` with a
  toleration for the taint.
- First request after scale-to-zero waits for a node and a model load.
  Latency-sensitive models keep `minReplicaCount: 1` in their ScaledObject.
- GPU quota is per region and per VM family. A pod that stays Pending with a
  quota error in the NAP events needs a quota request, not a bigger limit.
