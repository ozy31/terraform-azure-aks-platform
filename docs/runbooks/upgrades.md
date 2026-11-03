# Upgrades

Order of risk, lowest first: node images, Kubernetes patches, platform charts,
Istio, Kubernetes minor versions.

## Node images and Kubernetes patches

Automatic. Node images roll on Saturdays (`node_os_upgrade_channel =
NodeImage`), Kubernetes patches on Sundays (`automatic_upgrade_channel =
patch`), both 02:00-06:00 UTC. Different days mean one cause per incident.
Node Auto-Provisioning nodes also expire after 30 days (`expireAfter`), so no
node runs an old image for long.

To skip a window (peak trading, a freeze), add a `not_allowed` block to the
maintenance windows in `terraform/modules/aks`.

## Kubernetes minor version

1. Read the AKS release notes and the upstream deprecation guide for the new
   minor. Check for removed APIs in what runs today:
   `kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis`.
2. Bump `kubernetes_version` for the non-production environment first, one
   minor at a time. Watch a full business day.
3. Bump it for production in a PR. The plan shows an in-place update of the
   cluster; the system pool surges by 33% and soaks each node for 5 minutes.
   NAP nodes are replaced through Karpenter drift, respecting the NodePool
   disruption budgets.
4. Bump `K8S_VERSION` in `hack/validate.sh` so manifests are validated
   against the new API.

## Platform charts

Change the chart version in the HelmRelease and run `make render manifests`.
`hack/render-platform.sh` renders the chart with the exact values from Git, so
removed or renamed values fail in CI. Diff the rendered output against `main`
before merging. Flux rolls back on a failed upgrade (`remediation.retries`).

## Istio (canary by revision)

Tenants and the gateway follow the `stable` revision tag, so istiod versions
can run side by side.

1. Add a second HelmRelease `istiod-1-31` (chart version 1.31.x,
   `revision: 1-31`, no `revisionTags`). Upgrade `istio-base` and `istio-cni`
   first if the release notes require it.
2. Test with one namespace: label it `istio.io/rev=1-31`, restart its
   deployments, check `istioctl proxy-status`.
3. Move the tag: `revisionTags: [stable]` on `istiod-1-31`, remove it from
   `istiod-1-30`, in the same PR.
4. Restart namespaces one by one (`kubectl rollout restart deploy -n <ns>`),
   gateway last. Rollback at any point is moving the tag back.
5. When `istioctl proxy-status` shows no proxies on `1-30`, delete
   `istiod-1-30`.

## Gatekeeper policies

Add or change cases in `gitops/policies/tests` first, then the template.
For a new constraint on existing workloads, start with `enforcementAction:
warn` and check the audit results (`kubectl get <kind> -o yaml`, field
`status.violations`) before switching to `deny`.
