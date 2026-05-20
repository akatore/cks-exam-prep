#!/usr/bin/env bash
set -euo pipefail
NS=psa-lab

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NS" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
        - name: app
          image: nginx:latest
          securityContext:
            privileged: true
            allowPrivilegeEscalation: true
          ports:
            - containerPort: 80
EOF

echo "Lab ready: namespace psa-lab enforce=restricted; broken-app should NOT become Running."
kubectl get pods -n "$NS" -w &
sleep 8
kill %1 2>/dev/null || true
kubectl get pods -n "$NS"
