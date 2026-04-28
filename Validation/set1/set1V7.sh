# ==============================================================================
# Question 7 VALIDATION: Kube-bench Security Fixes (v1.30+)
# ==============================================================================
# Define colors if not already defined
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "--- Q7 VALIDATION: Cluster Security Posture ---"
Q7_SCORE=0
Q7_TOTAL=7

API_SERVER="/etc/kubernetes/manifests/kube-apiserver.yaml"
ETCD="/etc/kubernetes/manifests/etcd.yaml"
KUBELET_CONF="/var/lib/kubelet/config.yaml"

# ------------------------------------------------------------------------------
# 1. ETCD Validations
# ------------------------------------------------------------------------------
echo ">> Checking ETCD..."
if [ -f "$ETCD" ]; then
    if ! grep -q "\-\-auto-tls=true" "$ETCD"; then
        echo -e "${GREEN}[PASS]${NC} ETCD --auto-tls is NOT set to true."
        ((Q7_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} ETCD --auto-tls is still set to true."
    fi

    if ! grep -q "\-\-peer-auto-tls=true" "$ETCD"; then
        echo -e "${GREEN}[PASS]${NC} ETCD --peer-auto-tls is NOT set to true."
        ((Q7_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} ETCD --peer-auto-tls is still set to true."
    fi
else
    echo -e "${RED}[FAIL]${NC} ETCD manifest not found at $ETCD."
fi

# ------------------------------------------------------------------------------
# 2. Kubelet Validations
# ------------------------------------------------------------------------------
echo ">> Checking Kubelet..."
if [ -f "$KUBELET_CONF" ]; then
    # Check if anonymous auth is disabled (looks at the 2 lines following 'anonymous:')
    if grep -A 2 "anonymous:" "$KUBELET_CONF" | grep -q "enabled: false"; then
        echo -e "${GREEN}[PASS]${NC} Kubelet anonymous authentication is disabled."
        ((Q7_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Kubelet anonymous authentication is still enabled."
    fi

    if grep -q "mode: Webhook" "$KUBELET_CONF"; then
        echo -e "${GREEN}[PASS]${NC} Kubelet authorization-mode is set to Webhook."
        ((Q7_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Kubelet authorization-mode is not set to Webhook."
    fi
else
    echo -e "${RED}[FAIL]${NC} Kubelet config not found at $KUBELET_CONF."
fi

# ------------------------------------------------------------------------------
# 3. API Server Validations
# ------------------------------------------------------------------------------
echo ">> Checking API Server..."
if [ -f "$API_SERVER" ]; then
    if grep -q "RotateKubeletServerCertificate" "$API_SERVER"; then
        echo -e "${GREEN}[PASS]${NC} API Server has RotateKubeletServerCertificate enabled."
        ((Q7_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} API Server is missing RotateKubeletServerCertificate."
    fi

    if grep -q "\-\-kubelet-certificate-authority" "$API_SERVER"; then
        echo -e "${GREEN}[PASS]${NC} API Server has --kubelet-certificate-authority configured."
        ((Q7_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} API Server is missing --kubelet-certificate-authority."
    fi

    # Check admission plugins for PodSecurity and NodeRestriction
    ADMISSION_PLUGINS=$(grep -oP '(?<=--enable-admission-plugins=)[^\s]+' "$API_SERVER")
    if [[ "$ADMISSION_PLUGINS" == *"NodeRestriction"* ]] && [[ "$ADMISSION_PLUGINS" == *"PodSecurity"* ]]; then
        echo -e "${GREEN}[PASS]${NC} API Server admission plugins include NodeRestriction and PodSecurity."
        ((Q7_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} API Server admission plugins missing NodeRestriction and/or PodSecurity."
    fi
else
    echo -e "${RED}[FAIL]${NC} API Server manifest not found at $API_SERVER."
fi

# ------------------------------------------------------------------------------
# Q7 Result
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
if [ $Q7_SCORE -eq $Q7_TOTAL ]; then
    echo -e "--> Q7 Result: ${GREEN}SUCCESS ($Q7_SCORE/$Q7_TOTAL)${NC}"
else
    echo -e "--> Q7 Result: ${RED}FAILED ($Q7_SCORE/$Q7_TOTAL)${NC}"
fi
echo "=============================================================================="