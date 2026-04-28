# ==============================================================================
# Question 13 VALIDATION: Istio mTLS STRICT Mode
# ==============================================================================
# Define colors if not already defined
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "--- Q11 VALIDATION: Istio Mutual TLS (mTLS) ---"
Q11_SCORE=0
Q11_TOTAL=2

NAMESPACE="payments"

# ------------------------------------------------------------------------------
# 1. Namespace Sidecar Injection Validation
# ------------------------------------------------------------------------------
echo ">> Checking Sidecar Injection on namespace '$NAMESPACE'..."
# Fetch the istio-injection label for the namespace
INJECTION_LABEL=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)

if [ "$INJECTION_LABEL" == "enabled" ]; then
    echo -e "${GREEN}[PASS]${NC} Namespace '$NAMESPACE' has automatic Istio sidecar injection enabled."
    ((Q11_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} Namespace '$NAMESPACE' is missing the 'istio-injection=enabled' label."
fi

# ------------------------------------------------------------------------------
# 2. PeerAuthentication STRICT Mode Validation
# ------------------------------------------------------------------------------
echo ">> Checking mTLS PeerAuthentication policy..."
# Fetch the mtls mode for any PeerAuthentication resources in the namespace
# We search for at least one policy enforcing STRICT mode
STRICT_POLICIES=$(kubectl get peerauthentication -n $NAMESPACE -o jsonpath='{range .items[*]}{.spec.mtls.mode}{"\n"}{end}' 2>/dev/null | grep -c "STRICT")

if [ -n "$STRICT_POLICIES" ] && [ "$STRICT_POLICIES" -gt 0 ]; then
    echo -e "${GREEN}[PASS]${NC} Found a PeerAuthentication resource enforcing STRICT mTLS in '$NAMESPACE'."
    ((Q11_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} No PeerAuthentication resource found in '$NAMESPACE' with mtls.mode set to STRICT."
    # Optional helpful output if they set it to something else like PERMISSIVE
    CURRENT_MODES=$(kubectl get peerauthentication -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.mtls.mode}{"\n"}{end}' 2>/dev/null)
    if [ -n "$CURRENT_MODES" ]; then
        echo "   Current policies found:"
        echo "$CURRENT_MODES" | sed 's/^/   - /'
    fi
fi

# ------------------------------------------------------------------------------
# Q11 Result
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
if [ $Q11_SCORE -eq $Q11_TOTAL ]; then
    echo -e "--> Q11 Result: ${GREEN}SUCCESS ($Q11_SCORE/$Q11_TOTAL)${NC}"
else
    echo -e "--> Q11 Result: ${RED}FAILED ($Q11_SCORE/$Q11_TOTAL)${NC}"
fi
echo "=============================================================================="