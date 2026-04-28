# ==============================================================================
# Question 10 VALIDATION: gVisor & RuntimeClass
# ==============================================================================
# Define colors if not already defined
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "--- Q10 VALIDATION: RuntimeClass (gVisor) ---"
Q10_SCORE=0
Q10_TOTAL=2

# ------------------------------------------------------------------------------
# 1. RuntimeClass Validation
# ------------------------------------------------------------------------------
echo ">> Checking RuntimeClass..."
# Fetch the handler for the 'sandboxed' RuntimeClass, suppressing errors if it doesn't exist
HANDLER=$(kubectl get runtimeclass sandboxed -o jsonpath='{.handler}' 2>/dev/null)

if [ "$HANDLER" == "runsc" ]; then
    echo -e "${GREEN}[PASS]${NC} RuntimeClass 'sandboxed' exists and uses handler 'runsc'."
    ((Q10_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} RuntimeClass 'sandboxed' is missing or does not use handler 'runsc'."
fi

# ------------------------------------------------------------------------------
# 2. Pod Namespace Validation
# ------------------------------------------------------------------------------
echo ">> Checking Pods in 'server' namespace..."
# Check if any pods actually exist in the namespace to prevent false passes
PODS_EXIST=$(kubectl get pods -n server --no-headers 2>/dev/null | wc -l)

if [ "$PODS_EXIST" -gt 0 ]; then
    # Fetch a list of all pods and their runtimeClassName. 
    # We count how many lines do NOT contain "sandboxed".
    NON_SANDBOXED=$(kubectl get pods -n server -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.runtimeClassName}{"\n"}{end}' | grep -v "sandboxed" | wc -l)
    
    if [ "$NON_SANDBOXED" -eq 0 ]; then
        echo -e "${GREEN}[PASS]${NC} All Pods in 'server' namespace are using the 'sandboxed' RuntimeClass."
        ((Q10_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Found $NON_SANDBOXED Pod(s) in 'server' namespace NOT using 'sandboxed' RuntimeClass."
        # Optional: Print the pods that failed for easier debugging
        echo "   Failing Pods:"
        kubectl get pods -n server -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.runtimeClassName}{"\n"}{end}' | grep -v "sandboxed" | sed 's/^/   - /'
    fi
else
    echo -e "${RED}[FAIL]${NC} No Pods found in the 'server' namespace. Ensure they are running."
fi

# ------------------------------------------------------------------------------
# Q10 Result
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
if [ $Q10_SCORE -eq $Q10_TOTAL ]; then
    echo -e "--> Q10 Result: ${GREEN}SUCCESS ($Q10_SCORE/$Q10_TOTAL)${NC}"
else
    echo -e "--> Q10 Result: ${RED}FAILED ($Q10_SCORE/$Q10_TOTAL)${NC}"
fi
echo "=============================================================================="