#!/bin/bash

echo "🚀 Setting up v1.30+ playground for modern kube-bench security task..."

# Define file paths
API_SERVER="/etc/kubernetes/manifests/kube-apiserver.yaml"
ETCD="/etc/kubernetes/manifests/etcd.yaml"
KUBELET_CONF="/var/lib/kubelet/config.yaml"

# 1. Create Backups
echo "Creating backups of critical manifests..."
sudo cp $API_SERVER "${API_SERVER}.bak"
sudo cp $ETCD "${ETCD}.bak"
sudo cp $KUBELET_CONF "${KUBELET_CONF}.bak"

# 2. Misconfigure ETCD (Still a valid check in 1.30)
echo "Injecting vulnerabilities into ETCD..."
sudo sed -i '/--auto-tls/d' $ETCD
sudo sed -i '/--peer-auto-tls/d' $ETCD
sudo sed -i '/- etcd/a \    - --auto-tls=true\n    - --peer-auto-tls=true' $ETCD

# 3. Misconfigure Kubelet (Still a valid check in 1.30)
echo "Injecting vulnerabilities into Kubelet config..."
sudo sed -i '/anonymous:/,+1 s/enabled: false/enabled: true/' $KUBELET_CONF
sudo sed -i 's/mode: Webhook/mode: AlwaysAllow/' $KUBELET_CONF

echo "Restarting Kubelet service..."
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 4. Misconfigure API Server (Updated for PSA/NodeRestriction)
echo "Stripping secure flags from API Server..."
sudo sed -i '/--kubelet-certificate-authority/d' $API_SERVER
sudo sed -i '/RotateKubeletServerCertificate/d' $API_SERVER

# If enable-admission-plugins exists, remove PodSecurity and NodeRestriction
if grep -q "enable-admission-plugins" $API_SERVER; then
    sudo sed -i 's/,NodeRestriction//g' $API_SERVER
    sudo sed -i 's/NodeRestriction,//g' $API_SERVER
    sudo sed -i 's/,PodSecurity//g' $API_SERVER
    sudo sed -i 's/PodSecurity,//g' $API_SERVER
else
    # If it doesn't exist, we add a dummy one so the user has to append to it
    sudo sed -i '/- kube-apiserver/a \    - --enable-admission-plugins=MutatingAdmissionWebhook' $API_SERVER
fi

echo ""
echo "✅ Playground setup complete!"
echo "Note: The API server and ETCD static pods will take about 30-60 seconds to restart."
echo "You can monitor them with: watch crictl ps"