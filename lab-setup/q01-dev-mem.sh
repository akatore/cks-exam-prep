#!/usr/bin/env bash
set -euo pipefail
NS=workloads
IMG=busybox:1.36

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

for dep in cpu gpu nvidia; do
  ACCESS=""
  if [[ "$dep" == "cpu" ]]; then
    ACCESS='while true; do head -c 1 /dev/mem 2>/dev/null || true; sleep 5; done'
  else
    ACCESS='sleep infinity'
  fi
  kubectl -n "$NS" create deployment "$dep" \
    --image="$IMG" \
    --replicas=1 \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "$NS" patch deployment "$dep" --type=json -p='[
    {"op":"replace","path":"/spec/template/spec/containers/0/securityContext","value":{"privileged":true}},
    {"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c"]},
    {"op":"replace","path":"/spec/template/spec/containers/0/args","value":["'"$ACCESS"'"]}
  ]'
  kubectl -n "$NS" label deployment "$dep" app="$dep" --overwrite
done

kubectl -n "$NS" rollout status deployment/cpu deployment/gpu deployment/nvidia --timeout=120s
echo "Lab ready: three privileged Deployments (cpu/gpu/nvidia), same image. Only cpu touches /dev/mem."
kubectl get pods -n "$NS" -o wide
