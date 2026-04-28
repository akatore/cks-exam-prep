# ==============================================================================
# Question 12 VALIDATION: Pod Security Admission (Restricted)
# ==============================================================================
# Define colors if not already defined
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "--- Q12 VALIDATION: Pod Security Admission ---"
Q12_SCORE=0
Q12_TOTAL=5

NAMESPACE="secure-team"
DEPLOYMENT="secure-app"

# ------------------------------------------------------------------------------
# 1. Live Pod/Deployment Validation
# ------------------------------------------------------------------------------
echo ">> Checking if deployment is running..."

# Check if the Deployment exists
if kubectl get deployment $DEPLOYMENT -n $NAMESPACE >/dev/null 2>&1; then
    
    # Check if Pods were actually scheduled and are running (This means PSA allowed it!)
    READY_REPLICAS=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    
    if [ -n "$READY_REPLICAS" ] && [ "$READY_REPLICAS" -ge 1 ]; then
        echo -e "${GREEN}[PASS]${NC} Deployment is active and Pods are running (PSA Admission Passed!)."
        ((Q12_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Deployment exists, but no Pods are running. The ReplicaSet is likely being blocked by PSA."
    fi

    # --------------------------------------------------------------------------
    # 2. Detailed Security Context Checks (Live Object)
    # --------------------------------------------------------------------------
    echo ">> Validating Security Context settings..."
    
    # Requirement 1: Drop ALL Capabilities
    CAP_DROP=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop}' 2>/dev/null)
    if [[ "$CAP_DROP" == *"ALL"* ]]; then
        echo -e "${GREEN}[PASS]${NC} Capabilities correctly drop 'ALL'."
        ((Q12_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Missing or incorrect capabilities drop. Must drop 'ALL'."
    fi

    # Requirement 2: allowPrivilegeEscalation is false
    PRIV_ESC=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
    if [ "$PRIV_ESC" == "false" ]; then
        echo -e "${GREEN}[PASS]${NC} allowPrivilegeEscalation is correctly set to false."
        ((Q12_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} allowPrivilegeEscalation is missing or not set to false."
    fi

    # Requirement 3: runAsNonRoot is true (Can be on pod or container level)
    NON_ROOT_POD=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null)
    NON_ROOT_CONT=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)
    
    if [ "$NON_ROOT_POD" == "true" ] || [ "$NON_ROOT_CONT" == "true" ]; then
        echo -e "${GREEN}[PASS]${NC} runAsNonRoot is correctly set to true."
        ((Q12_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} runAsNonRoot is missing or not set to true."
    fi

    # Requirement 4: seccompProfile type is RuntimeDefault (Can be on pod or container level)
    SECCOMP_POD=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}' 2>/dev/null)
    SECCOMP_CONT=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].securityContext.seccompProfile.type}' 2>/dev/null)
    
    if [ "$SECCOMP_POD" == "RuntimeDefault" ] || [ "$SECCOMP_CONT" == "RuntimeDefault" ]; then
        echo -e "${GREEN}[PASS]${NC} seccompProfile type is correctly set to RuntimeDefault."
        ((Q12_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} seccompProfile type is missing or not set to RuntimeDefault."
    fi

else
    echo -e "${RED}[FAIL]${NC} Deployment '$DEPLOYMENT' not found in namespace '$NAMESPACE'."
    echo "Did you apply your modified YAML file?"
fi

# ------------------------------------------------------------------------------
# Q12 Result
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
if [ $Q12_SCORE -eq $Q12_TOTAL ]; then
    echo -e "--> Q12 Result: ${GREEN}SUCCESS ($Q12_SCORE/$Q12_TOTAL)${NC}"
else
    echo -e "--> Q12 Result: ${RED}FAILED ($Q12_SCORE/$Q12_TOTAL)${NC}"
fi
echo "=============================================================================="