# Exercise 09 — Image Scanning with Trivy

> Related: [README — Supply Chain Security](../../README.md#domain-5--supply-chain-security-20)

Scan container images for vulnerabilities using Trivy. The CKS tests your ability to identify and fix insecure images.

## Tasks

1. Install Trivy on your machine (or use the Docker image)
2. Scan the following images and note Critical/High vulnerabilities:
   - `nginx:1.27`
   - `nginx:1.20`
   - `python:3.9`
   - `alpine:3.19`
3. Compare `python:3.9` vs `python:3.9-alpine` — note the difference in vulnerability count
4. Scan a running pod's image:
   ```bash
   k get pod <pod-name> -o jsonpath='{.spec.containers[0].image}' | xargs trivy image
   ```
5. Create a pod that uses an image with known Critical CVEs
6. Fix it by updating to the latest patched version
7. Scan a Dockerfile for misconfigurations: `trivy config Dockerfile`

## Hints

- `trivy image <image>` scans a container image
- `trivy image --severity HIGH,CRITICAL <image>` filters severity
- `trivy config <path>` scans IaC files (Dockerfile, Kubernetes YAML)
- Smaller base images = fewer vulnerabilities (alpine, distroless)
- On the exam they may ask you to identify which pods use vulnerable images

## Verify

```bash
# Should show vulnerability table
trivy image --severity CRITICAL nginx:1.20

# Alpine-based images have far fewer CVEs
trivy image python:3.9-alpine --severity HIGH,CRITICAL
trivy image python:3.9 --severity HIGH,CRITICAL
```

## Cleanup

```bash
# No cluster resources to clean up
```

<details>
<summary>Solution</summary>

```bash
# Install Trivy
sudo apt-get install -y trivy
# Or: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh

# Scan images
trivy image nginx:1.27
trivy image nginx:1.20
trivy image --severity HIGH,CRITICAL python:3.9
trivy image --severity HIGH,CRITICAL python:3.9-alpine
trivy image alpine:3.19

# Scan a running pod's image
IMAGE=$(k get pod <pod> -o jsonpath='{.spec.containers[0].image}')
trivy image --severity CRITICAL "$IMAGE"

# Scan Dockerfile
cat <<'EOF' > Dockerfile
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl wget
COPY app /app
USER root
CMD ["/app"]
EOF

trivy config Dockerfile
# Shows misconfigurations: running as root, outdated base image, etc.
```

Fix the Dockerfile:
```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*
COPY app /app
RUN useradd -r appuser
USER appuser
CMD ["/app"]
```

</details>
