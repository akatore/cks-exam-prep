#!/usr/bin/env bash
set -euo pipefail
NS=supply-chain
# Target libcrypto version to find (Alpine 3.19.x line — verify with bom in your environment)
TARGET_VER="3.3.0"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: triple-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: triple-app
  template:
    metadata:
      labels:
        app: triple-app
    spec:
      containers:
        - name: app-a
          image: alpine:3.18.5
          command: ["sleep", "infinity"]
        - name: app-b
          image: alpine:3.19.1
          command: ["sleep", "infinity"]
        - name: app-c
          image: alpine:3.20.3
          command: ["sleep", "infinity"]
EOF

kubectl -n "$NS" rollout status deployment/triple-app --timeout=120s
echo "Lab ready: Deployment triple-app with 3 containers (alpine tags 3.18.5 / 3.19.1 / 3.20.3)."
echo "Task: find container whose image has libcrypto ~$TARGET_VER (use bom + grep)."
kubectl get pod -n "$NS" -o jsonpath='{range .items[0].spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
