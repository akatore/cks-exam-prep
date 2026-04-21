#!/bin/bash

# ==============================================================================
# Kubernetes Playground Solutions Script
# ==============================================================================
# This script contains automated solutions for various Kubernetes tasks.
# It is designed to be run in a Kubernetes playground environment.
# Ensure you are connected to the correct cluster context before running.

echo "Starting Kubernetes operations..."

# ==============================================================================
# Question 1 SETUP: AppArmor Profile Enforcement
# ==============================================================================
echo "--- Q1 SETUP: Preparing AppArmor environment ---"

# Dynamically find a worker node
# We filter out nodes labeled as control-plane or master.
WORKER_NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' -o jsonpath='{.items[0].metadata.name}')

# Fallback: If no dedicated worker is found (e.g., single-node cluster), just use the first available node.
if [ -z "$WORKER_NODE" ]; then
  WORKER_NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
fi

echo "Dynamically selected target node: $WORKER_NODE"

# 1. Create the AppArmor profile file on the selected node (but do NOT apply it)
echo "Creating AppArmor profile 'nginx-profile-2' on $WORKER_NODE..."
ssh -o StrictHostKeyChecking=no $WORKER_NODE "cat << 'PROFILE_EOF' | sudo tee /etc/apparmor.d/nginx-profile-2 > /dev/null
#include <tunables/global>

profile nginx-profile-2 flags=(attach_disconnected) {
  #include <abstractions/base>
  
  network,
  capability,
  file,
  umount,
  
  # Basic restrictions to make it a distinct profile
  deny @{PROC}/* w,
  deny /sys/[^f]*/** w,
  deny /sys/f[^s]*/** w,
  deny /sys/fs/[^c]*/** w,
  deny /sys/kernel/security/** w,
}
PROFILE_EOF"

# 2. Create the skeleton Pod manifest for the user to edit
echo "Creating skeleton Pod manifest at secure-nginx-pod.yaml..."
# Note: Using unquoted EOF here so the $WORKER_NODE variable gets evaluated inside the YAML text
cat << EOF > secure-nginx-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-nginx
  # TODO: Add the AppArmor annotation referencing 'nginx-profile-2'
spec:
  # TODO: Ensure the pod is scheduled on '$WORKER_NODE'
  containers:
  - name: nginx
    image: nginx
EOF

echo "Q1 Setup complete. The candidate must now load the profile on $WORKER_NODE and deploy the edited manifest."

# ==============================================================================

# ... Future tasks will be appended below ...

echo "All operations completed successfully!"

# ==============================================================================
# Question 2 SETUP: Default Deny NetworkPolicy
# ==============================================================================
echo "--- Q2 SETUP: Preparing NetworkPolicy environment ---"

# Ensure the testing namespace exists
echo "Creating namespace 'testing'..."
kubectl create namespace testing --dry-run=client -o yaml | kubectl apply -f -

echo "Q2 Setup complete. The candidate must now create the 'deny-all' NetworkPolicy in the 'testing' namespace."

# ==============================================================================

# ... Future tasks will be appended below ...