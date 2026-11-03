# 0004. Upstream Istio with revision tags instead of the AKS Istio add-on

Status: accepted

## Context

AKS offers a managed Istio add-on (`service_mesh_profile`). It removes the
work of running istiod, but versions follow the AKS support calendar, only a
subset of `MeshConfig` is supported, and some features (for example ambient
mode and custom CNI settings) arrive later than upstream.

## Decision

Install upstream Istio from the official Helm charts with Flux:

- `istiod` is installed per revision (`1-30`) and exposes the `stable`
  revision tag. Namespaces select `istio.io/rev: stable`, never a version.
- The Istio CNI node agent is chained after the AKS-managed Cilium CNI, so
  injected pods need no privileged init container and tenant namespaces can
  enforce the `baseline` Pod Security level.
- Ingress uses the Gateway API (`gatewayClassName: istio`); teams write
  `HTTPRoute`s, not `VirtualService`s.
- mTLS is `STRICT` mesh-wide; each tenant namespace allows traffic only from
  itself and the gateway.

## Consequences

- Upgrades are canaries: install the new revision next to the old one, move
  the tag, restart namespaces one at a time, remove the old revision
  (docs/runbooks/upgrades.md). Rollback is moving the tag back.
- The platform team owns istiod's availability and CVE patching. The add-on
  would be the better choice for a team without that capacity, and moving to
  it later only changes the installation, not the tenant-facing API.
