# Hands-on labs

Small, step-by-step labs I use to rehearse the building blocks this platform is made of,
one resource per script, against a personal pay-as-you-go subscription. Each script says
what the resource does, where to find it in the portal, and the AWS equivalent.

They are **not** part of the platform deployment in `terraform/`; the production-shaped
version of each idea lives there. Everything here was created by hand, checked in the
portal and with `kubectl`, and torn down again. Nothing runs permanently.

| Lab | What it shows |
|---|---|
| `00-budget.sh` | a budget alert before anything else is created |
| `network/` | hub and spoke VNets, an NSG with explicit priorities, a private endpoint subnet, peering in both directions |
| `storage/` | a storage account with shared keys off, a data-plane role, a private endpoint with its private DNS zone, then public access closed |
| `aks/terraform/` | a two-node AKS cluster: Entra ID only, Azure RBAC, CNI Overlay + Cilium, system and user pools, OIDC issuer, Istio add-on |
| `aks/connect.sh` | `kubectl` through kubelogin when local accounts are disabled |
| `workload-identity/` | a pod reads a blob through the private endpoint with no secret, and is refused when it tries to write |
| `istio/` | sidecar injection by revision label, STRICT mTLS, a 90/10 canary with a header override, fault injection, an authorization policy |
| `notes/` | short write-ups of things worth explaining in an interview |

## Run order

```bash
export LAB_SUBSCRIPTION="<lab subscription>" LAB_USER="<lab login>" LAB_BUDGET_EMAIL="<you>"
./00-budget.sh
./network/00-resource-group.sh && ./network/01-vnet-hub.sh && ./network/02-vnet-spoke.sh
./network/03-nsg-pe.sh && ./network/04-subnet-pe.sh && ./network/05-peering.sh
cp storage/.env.example storage/.env   # pick a globally unique storage account name
./storage/01-storage-account.sh && ./storage/02-rbac-data-role.sh
./storage/03-private-dns-zone.sh && ./storage/04-private-endpoint.sh
# while public access is still on: a container and a file for the workload identity lab
source storage/.env && az storage container create --account-name "$SA" -n docs --auth-mode login
echo hello > /tmp/hello.txt && az storage blob upload --account-name "$SA" -c docs -n hello.txt -f /tmp/hello.txt --auth-mode login
./storage/05-disable-public-access.sh
(cd aks/terraform && cp terraform.tfvars.example terraform.tfvars && terraform init && terraform apply)
./aks/connect.sh
./workload-identity/run.sh
kubectl --kubeconfig ~/.kube/azlab apply -f istio/00-namespaces.yaml
kubectl --kubeconfig ~/.kube/azlab -n shop apply -f istio/helloworld.yaml -f istio/curl.yaml
kubectl --kubeconfig ~/.kube/azlab -n legacy apply -f istio/curl.yaml
./istio/call.sh legacy 10            # works while mTLS is PERMISSIVE
kubectl --kubeconfig ~/.kube/azlab apply -f istio/01-strict-mtls.yaml
./istio/call.sh legacy 10            # now refused
```

## Clean up

```bash
az group delete -n rg-lab-aks --yes --no-wait
az group delete -n rg-lab-core --yes --no-wait
```

`az aks stop -g rg-lab-aks -n aks-lab` pauses the cluster between sessions.
