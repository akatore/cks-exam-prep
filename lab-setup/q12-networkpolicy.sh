#!/usr/bin/env bash
set -euo pipefail

for ns in team-a team-b; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl label namespace team-b role=frontend --overwrite

kubectl -n team-a create deployment backend --image=nginx:alpine --replicas=1
kubectl -n team-a label deployment backend app=backend --overwrite
kubectl -n team-b create deployment frontend --image=busybox:1.36 --replicas=1 -- sleep infinity
kubectl -n team-b label deployment frontend role=frontend --overwrite
kubectl -n team-a expose deployment backend --port=80
kubectl -n team-b run tester --image=nicolaka/netshoot --restart=Never -- sleep 3600

echo "Lab ready: team-a/backend, team-b/frontend+tester. No NetworkPolicies yet — all traffic allowed."
kubectl get pods -n team-a
kubectl get pods -n team-b
