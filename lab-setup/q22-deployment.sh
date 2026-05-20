#!/usr/bin/env bash
set -euo pipefail
NS=static-lab
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure
  template:
    metadata:
      labels:
        app: insecure
    spec:
      containers:
        - name: app
          image: nginx:1.25
          env:
            - name: DB_PASSWORD
              value: "P@ssw0rd123"
          securityContext:
            privileged: true
            allowPrivilegeEscalation: true
EOF
echo "Lab ready: insecure-deploy in static-lab — change exactly ONE line per brief."
