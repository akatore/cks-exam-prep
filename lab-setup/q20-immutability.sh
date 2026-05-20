#!/usr/bin/env bash
set -euo pipefail
NS=immutability-lab

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create deployment mutable-app --image=nginx:alpine --port=80
kubectl -n "$NS" patch deployment mutable-app --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"privileged":false}}
]'
echo "Lab ready: Deployment mutable-app without readOnlyRootFilesystem (you harden it)."
