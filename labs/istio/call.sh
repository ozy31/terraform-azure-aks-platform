#!/usr/bin/env bash
# Usage: ./call.sh <namespace> [count] [extra curl args, e.g. -H x-canary:true]
# Calls helloworld from the curl pod in <namespace> and counts versions / HTTP codes.
NS=${1:-shop}; N=${2:-20}; shift 2 2>/dev/null
kubectl --kubeconfig "$HOME/.kube/azlab" --context aks-lab -n "$NS" exec deploy/curl -c curl -- sh -c '
  n=$1; shift
  for i in $(seq "$n"); do
    out=$(curl -s -m 3 -w " HTTP%{http_code}" "$@" http://helloworld.shop:5000/hello)
    echo "$out" | grep -o "v[12]\|HTTP[0-9]*" | sort -u | tr "\n" " "; echo
  done' _ "$N" "$@" | sort | uniq -c
