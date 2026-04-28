#!/bin/bash

echo "🚀 Setting up playground for Pod Security Admission task..."

# 1. Create the namespace
echo "Creating namespace 'secure-team'..."
kubectl create namespace secure-team --dry-run=client -o yaml | kubectl apply -f -

# 2. Enforce the 'restricted' Pod Security Standard on the namespace
echo "Labeling namespace to enforce the 'restricted' PSA profile..."
kubectl label namespace secure-team \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/warn-version=latest \
    --overwrite

# 3. Prepare the working directory
echo "Creating directory /home/masters/..."
sudo mkdir -p /home/masters/

# 4. Generate the insecure Deployment manifest
echo "Generating the insecure Deployment manifest..."
cat <<EOF | sudo tee /home/masters/insecure-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: secure-team
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app-container
        image: nginx:alpine
        ports:
        - containerPort: 80
        # The securityContext is intentionally missing to trigger PSA violations
EOF

echo ""
echo "✅ Playground setup complete!"
echo "If you run 'kubectl apply -f /home/masters/insecure-deployment.yaml' right now, the API server will reject it."
echo "Your task is to edit the YAML and add the necessary securityContext fields to satisfy the restricted profile!"