#!/usr/bin/env bash
set -euo pipefail
NS=ingress-lab
HOST=app.cks-lab.local

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

TMP=$(mktemp -d)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$TMP/tls.key" -out "$TMP/tls.crt" \
  -subj "/CN=${HOST}" -addext "subjectAltName=DNS:${HOST}" 2>/dev/null \
  || openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$TMP/tls.key" -out "$TMP/tls.crt" -subj "/CN=${HOST}"

kubectl -n "$NS" create secret tls app-tls --cert="$TMP/tls.crt" --key="$TMP/tls.key" --dry-run=client -o yaml | kubectl apply -f -
rm -rf "$TMP"

kubectl -n "$NS" create deployment web --image=nginx:alpine --port=80
kubectl -n "$NS" expose deployment web --port=80

kubectl -n "$NS" apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: ${HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF

echo "Lab ready: TLS secret app-tls exists; Ingress has NO tls block and redirect disabled (you fix)."
echo "Install ingress-nginx if missing: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml"
