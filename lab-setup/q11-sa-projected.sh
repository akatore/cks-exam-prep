#!/usr/bin/env bash
set -euo pipefail
NS=sa-lab

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create serviceaccount my-sa --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: token-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: token-app
  template:
    metadata:
      labels:
        app: token-app
    spec:
      serviceAccountName: my-sa
      containers:
        - name: app
          image: nginx:alpine
          ports:
            - containerPort: 80
EOF

echo "Lab ready: Deployment token-app WITHOUT projected SA token volume (you add it)."
kubectl get deploy,sa -n "$NS"
