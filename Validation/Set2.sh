#!/bin/bash

# ==============================================================================
# Kubernetes Playground Validation Script
# ==============================================================================
# Run this script to validate if the candidate successfully solved the tasks.

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Starting validation..."
echo "=============================================================================="

# ==============================================================================
# Question 1 VALIDATION: AppArmor Profile Enforcement
# ==============================================================================
echo "--- Q1 VALIDATION: AppArmor ---"
Q1_SCORE=0
Q1_TOTAL=3

# 1. Check if Pod exists and is Running
POD_STATUS=$(kubectl get pod secure-nginx -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$POD_STATUS" == "Running" ]; then
    echo -e "${GREEN}[PASS]${NC} Pod 'secure-nginx' is Running."
    ((Q1_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} Pod 'secure-nginx' is not Running (Status: ${POD_STATUS:-NotFound}). Did they load the profile on the node with apparmor_parser?"
fi

# 2. Check if AppArmor is specified in the Pod (Handles v1.30+ and legacy annotations)
# We use 'grep' on the yaml output to avoid complex jsonpath escaping issues with dots and slashes
HAS_AA_V130=$(kubectl get pod secure-nginx -o yaml 2>/dev/null | grep -c "localhostProfile: nginx-profile-2")
HAS_AA_ANNOTATION=$(kubectl get pod secure-nginx -o yaml 2>/dev/null | grep -c "container.apparmor.security.beta.kubernetes.io/nginx: localhost/nginx-profile-2")

if [ "$HAS_AA_V130" -gt 0 ] || [ "$HAS_AA_ANNOTATION" -gt 0 ]; then
    echo -e "${GREEN}[PASS]${NC} Pod specification properly references 'nginx-profile-2'."
    ((Q1_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} Pod specification does not reference 'nginx-profile-2'. Missing securityContext or annotation?"
fi

# 3. Check inside the container to see if the kernel is actually enforcing it
if [ "$POD_STATUS" == "Running" ]; then
    # Different kernel versions store this in slightly different paths, so we check both
    AA_ACTIVE=$(kubectl exec secure-nginx -- sh -c 'cat /proc/1/attr/apparmor/current 2>/dev/null || cat /proc/1/attr/current 2>/dev/null')
    
    if [[ "$AA_ACTIVE" == *"nginx-profile-2 (enforce)"* ]]; then
        echo -e "${GREEN}[PASS]${NC} Kernel is actively enforcing 'nginx-profile-2' inside the container."
        ((Q1_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Profile is NOT actively enforced inside the container. Found: $AA_ACTIVE"
    fi
else
    echo -e "${RED}[FAIL]${NC} Cannot verify active kernel enforcement because the pod is not running."
fi

# Q1 Result
echo "------------------------------------------------------------------------------"
if [ $Q1_SCORE -eq $Q1_TOTAL ]; then
    echo -e "--> Q1 Result: ${GREEN}SUCCESS ($Q1_SCORE/$Q1_TOTAL)${NC}"
else
    echo -e "--> Q1 Result: ${RED}FAILED ($Q1_SCORE/$Q1_TOTAL)${NC}"
fi
echo "=============================================================================="

# ==============================================================================
# Question 2 VALIDATION: Default Deny NetworkPolicy
# ==============================================================================
echo "--- Q2 VALIDATION: NetworkPolicy ---"
Q2_SCORE=0
Q2_TOTAL=3

# 1. Check if NetworkPolicy exists in the testing namespace
if kubectl get networkpolicy deny-all -n testing &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} NetworkPolicy 'deny-all' exists in namespace 'testing'."
    ((Q2_SCORE++))
    
    # 2. Check podSelector (should be empty to match all pods)
    # Using jsonpath. An empty podSelector in yaml often translates to '{}' or completely blank.
    POD_SELECTOR=$(kubectl get networkpolicy deny-all -n testing -o jsonpath='{.spec.podSelector}')
    if [[ "$POD_SELECTOR" == "{}" || "$POD_SELECTOR" == "" || "$POD_SELECTOR" == '{"matchLabels":{}}' ]]; then
        echo -e "${GREEN}[PASS]${NC} NetworkPolicy podSelector is empty (applies to all pods in namespace)."
        ((Q2_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} NetworkPolicy does not select all pods. Expected empty podSelector, found: $POD_SELECTOR"
    fi
    
    # 3. Check PolicyTypes (Must include Ingress and Egress, and rules must be empty)
    POLICY_TYPES=$(kubectl get networkpolicy deny-all -n testing -o jsonpath='{.spec.policyTypes}')
    INGRESS_RULES=$(kubectl get networkpolicy deny-all -n testing -o jsonpath='{.spec.ingress}')
    EGRESS_RULES=$(kubectl get networkpolicy deny-all -n testing -o jsonpath='{.spec.egress}')
    
    if [[ "$POLICY_TYPES" == *"Ingress"* && "$POLICY_TYPES" == *"Egress"* ]]; then
        if [[ -z "$INGRESS_RULES" && -z "$EGRESS_RULES" ]]; then
            echo -e "${GREEN}[PASS]${NC} PolicyTypes include both Ingress and Egress, with no allow rules (Blocks All)."
            ((Q2_SCORE++))
        else
            echo -e "${RED}[FAIL]${NC} PolicyTypes are correct, but explicit allow rules exist in ingress/egress blocks!"
        fi
    else
        echo -e "${RED}[FAIL]${NC} policyTypes must include both 'Ingress' and 'Egress'. Found: ${POLICY_TYPES:-None}"
    fi
else
    echo -e "${RED}[FAIL]${NC} NetworkPolicy 'deny-all' not found in namespace 'testing'."
fi

# Q2 Result
echo "------------------------------------------------------------------------------"
if [ $Q2_SCORE -eq $Q2_TOTAL ]; then
    echo -e "--> Q2 Result: ${GREEN}SUCCESS ($Q2_SCORE/$Q2_TOTAL)${NC}"
else
    echo -e "--> Q2 Result: ${RED}FAILED ($Q2_SCORE/$Q2_TOTAL)${NC}"
fi
echo "=============================================================================="

# ... Future validations will be appended below ...

echo "Validation complete!"