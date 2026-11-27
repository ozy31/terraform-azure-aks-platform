#!/usr/bin/env bash
# kubectl with Entra ID.
# 1) get-credentials into a SEPARATE kubeconfig (~/.kube/azlab), so no other cluster is touched.
#    Local accounts are disabled, so there is no --admin kubeconfig, only the user one.
# 2) kubelogin convert-kubeconfig -l azurecli: kubectl takes its token from the `az login` session.
# Then: export KUBECONFIG=~/.kube/azlab   (or pass --kubeconfig every time)
source "$(dirname "$0")/../lib.sh"
az aks get-credentials -g rg-lab-aks -n aks-lab --file ~/.kube/azlab --overwrite-existing
KUBECONFIG=~/.kube/azlab kubelogin convert-kubeconfig -l azurecli
KUBECONFIG=~/.kube/azlab kubectl config current-context
