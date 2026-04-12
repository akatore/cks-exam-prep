# Exercise 03 — Ingress with TLS

> Related: [Ingress TLS skeleton](../../skeletons/ingress-tls.yaml) | [README — Cluster Setup](../../README.md#domain-1--cluster-setup-15)

Set up an Ingress with TLS termination. The CKS tests proper TLS configuration.

## Tasks

1. Create a namespace called `exercise-03`
2. Create a self-signed TLS certificate:
   - CN: `secure.example.com`
   - Valid for 365 days
3. Create a Kubernetes Secret of type `kubernetes.io/tls` named `tls-secret` in namespace `exercise-03`
4. Create a Deployment named `secure-app` with image `nginx:1.27` and 2 replicas
5. Expose the Deployment as a ClusterIP Service named `secure-svc` on port 80
6. Create an Ingress named `secure-ingress` that:
   - Uses `ingressClassName: nginx`
   - Routes `secure.example.com` to `secure-svc` on port 80
   - Terminates TLS using `tls-secret`
7. Verify the Ingress is created with TLS configured

## Hints

- Generate cert: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=secure.example.com"`
- Create secret: `k create secret tls tls-secret --cert=tls.crt --key=tls.key -n exercise-03`
- TLS block goes under `spec.tls` in the Ingress

## Verify

```bash
k get ingress secure-ingress -n exercise-03
k describe ingress secure-ingress -n exercise-03 | grep -A5 TLS
# Should show tls-secret and secure.example.com
```

## Cleanup

```bash
k delete ns exercise-03
rm -f tls.crt tls.key
```

<details>
<summary>Solution</summary>

```bash
k create ns exercise-03

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.example.com"

# Create TLS secret
k create secret tls tls-secret \
  --cert=tls.crt --key=tls.key \
  -n exercise-03

# Create deployment and service
k create deployment secure-app -n exercise-03 --image=nginx:1.27 --replicas=2
k expose deployment secure-app -n exercise-03 --port=80 --target-port=80 --name=secure-svc
```

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: exercise-03
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.example.com
    secretName: tls-secret
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-svc
            port:
              number: 80
```

```bash
k apply -f ingress.yaml
k get ingress secure-ingress -n exercise-03
k describe ingress secure-ingress -n exercise-03
```

</details>
