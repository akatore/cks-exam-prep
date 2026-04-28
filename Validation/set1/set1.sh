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

# ==============================================================================
# Question 3 VALIDATION: ServiceAccount Token Management
# ==============================================================================
echo "--- Q3 VALIDATION: ServiceAccount Token Management ---"
Q3_SCORE=0
Q3_TOTAL=3

# 1. Check ServiceAccount automountServiceAccountToken
SA_AUTOMOUNT=$(kubectl get sa default -n default -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
if [ "$SA_AUTOMOUNT" == "false" ]; then
    echo -e "${GREEN}[PASS]${NC} Default ServiceAccount 'automountServiceAccountToken' is disabled."
    ((Q3_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} Default ServiceAccount 'automountServiceAccountToken' is not disabled. Found: ${SA_AUTOMOUNT:-true}"
fi

# 2. Check for the Secret
# Iterating through secrets to find the correct type and annotation
CUSTOM_SECRET=""
for secret in $(kubectl get secrets -n default -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    TYPE=$(kubectl get secret $secret -n default -o jsonpath='{.type}')
    ANNOTATION=$(kubectl get secret $secret -n default -o jsonpath='{.metadata.annotations.kubernetes\.io/service-account\.name}' 2>/dev/null)
    if [ "$TYPE" == "kubernetes.io/service-account-token" ] && [ "$ANNOTATION" == "default" ]; then
        CUSTOM_SECRET=$secret
        break
    fi
done

if [ -n "$CUSTOM_SECRET" ]; then
    echo -e "${GREEN}[PASS]${NC} Found ServiceAccount token Secret referencing the 'default' SA: $CUSTOM_SECRET"
    ((Q3_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} Could not find a Secret of type 'kubernetes.io/service-account-token' referencing the 'default' SA."
fi

# 3. Check Pod configuration
POD_SA=$(kubectl get pod nginx-pod -n default -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)

# Check if the pod uses the custom secret in its volumes
if [ -n "$CUSTOM_SECRET" ]; then
    USES_SECRET=$(kubectl get pod nginx-pod -n default -o jsonpath="{.spec.volumes[*].secret.secretName}" 2>/dev/null | grep -c "$CUSTOM_SECRET")
else
    USES_SECRET=0
fi

# Check if it mounts at the correct path (if mounted at the dir, the token file exists at the required path)
MOUNTS_PATH=$(kubectl get pod nginx-pod -n default -o jsonpath="{.spec.containers[0].volumeMounts[*].mountPath}" 2>/dev/null | grep -c "/var/run/secrets/kubernetes.io/serviceaccount")

if [ "$POD_SA" == "default" ] && [ "$USES_SECRET" -gt 0 ] && [ "$MOUNTS_PATH" -gt 0 ]; then
    echo -e "${GREEN}[PASS]${NC} Pod 'nginx-pod' uses SA 'default' and manually mounts the token Secret correctly."
    ((Q3_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} Pod 'nginx-pod' is not correctly configured."
    echo "   -> Uses SA 'default': ${POD_SA:-NotFound}"
    echo "   -> Mounts custom Secret: $(if [ "$USES_SECRET" -gt 0 ]; then echo "Yes"; else echo "No"; fi)"
    echo "   -> Correct Mount Path: $(if [ "$MOUNTS_PATH" -gt 0 ]; then echo "Yes"; else echo "No"; fi)"
fi

# Q3 Result
echo "------------------------------------------------------------------------------"
if [ $Q3_SCORE -eq $Q3_TOTAL ]; then
    echo -e "--> Q3 Result: ${GREEN}SUCCESS ($Q3_SCORE/$Q3_TOTAL)${NC}"
else
    echo -e "--> Q3 Result: ${RED}FAILED ($Q3_SCORE/$Q3_TOTAL)${NC}"
fi
echo "=============================================================================="

# ... Future validations will be appended below ...

echo "Validation complete!"



# ==============================================================================
# Question 4 VALIDATION: Secure API Server
# ==============================================================================
echo "--- Q4 VALIDATION: Secure API Server ---"
Q4_SCORE=0
Q4_TOTAL=4

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
KUBECONFIG_PATH="/etc/kubernetes/admin.conf"

if [ -f "$MANIFEST" ]; then
    # 1. Check Authorization Mode (Must include Node and RBAC)
    if grep -q "\-\-authorization-mode=.*Node" "$MANIFEST" && grep -q "\-\-authorization-mode=.*RBAC" "$MANIFEST"; then
        echo -e "${GREEN}[PASS]${NC} Authorization mode includes Node and RBAC."
        ((Q4_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Authorization mode is missing Node or RBAC."
    fi

    # 2. Check Admission Controller (Must include NodeRestriction)
    if grep -q "\-\-enable-admission-plugins=.*NodeRestriction" "$MANIFEST"; then
        echo -e "${GREEN}[PASS]${NC} Admission plugins include NodeRestriction."
        ((Q4_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Admission plugins do not include NodeRestriction."
    fi

    # 3. Check Anonymous Auth (Must be explicitly set to false)
    if grep -q "\-\-anonymous-auth=false" "$MANIFEST"; then
        echo -e "${GREEN}[PASS]${NC} Anonymous authentication is disabled."
        ((Q4_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Anonymous authentication is not disabled (missing --anonymous-auth=false)."
    fi
else
    echo -e "${RED}[FAIL]${NC} Could not find API Server manifest at $MANIFEST. Ensure you are running this on the control plane."
fi

# 4. Check ClusterRoleBinding for system:anonymous using the original kubeconfig
ANON_BINDING=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get clusterrolebindings -o custom-columns="NAME:.metadata.name,SUBJECT:.subjects[*].name" 2>/dev/null | grep "system:anonymous" | awk '{print $1}')

if [ -z "$ANON_BINDING" ]; then
    echo -e "${GREEN}[PASS]${NC} No ClusterRoleBinding found granting access to 'system:anonymous'."
    ((Q4_SCORE++))
else
    echo -e "${RED}[FAIL]${NC} Found a ClusterRoleBinding granting access to 'system:anonymous': $ANON_BINDING"
fi

# Q4 Result
echo "------------------------------------------------------------------------------"
if [ $Q4_SCORE -eq $Q4_TOTAL ]; then
    echo -e "--> Q4 Result: ${GREEN}SUCCESS ($Q4_SCORE/$Q4_TOTAL)${NC}"
else
    echo -e "--> Q4 Result: ${RED}FAILED ($Q4_SCORE/$Q4_TOTAL)${NC}"
fi
echo "=============================================================================="

# ... Future validations will be appended below ...

echo "Validation complete!"


# ==============================================================================
# Question 5 VALIDATION: Audit Logging
# ==============================================================================
echo "--- Q5 VALIDATION: Audit Logging ---"
Q5_SCORE=0
Q5_TOTAL=5

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

if [ -f "$MANIFEST" ]; then
    # 1. Check API Server flags
    if grep -q "\-\-audit-log-path=/var/log/kubernetes-logs.log" "$MANIFEST" && \
       grep -q "\-\-audit-log-maxage=5" "$MANIFEST" && \
       grep -q "\-\-audit-log-maxbackup=10" "$MANIFEST" && \
       grep -q "\-\-audit-log-maxsize=100" "$MANIFEST"; then
        echo -e "${GREEN}[PASS]${NC} Audit log path, maxage, maxbackup, and maxsize are correctly configured."
        ((Q5_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Audit log flags (path, maxage, maxbackup, maxsize) are missing or incorrect."
    fi
    
    # 2. Check if policy file is referenced and exists
    # Extract the file path configured in the manifest
    POLICY_FILE=$(grep -oP '(?<=--audit-policy-file=)[^\s]+' "$MANIFEST" | tr -d '"' | tr -d "'" | head -n 1)
    
    if [ -n "$POLICY_FILE" ] && [ -f "$POLICY_FILE" ]; then
        echo -e "${GREEN}[PASS]${NC} Audit policy file is configured and exists at: $POLICY_FILE"
        ((Q5_SCORE++))
        
        # 3. Check CronJob RequestResponse rule
        if grep -qi "cronjobs" "$POLICY_FILE" && grep -qi "RequestResponse" "$POLICY_FILE"; then
            echo -e "${GREEN}[PASS]${NC} Policy includes rule for CronJobs at RequestResponse level."
            ((Q5_SCORE++))
        else
            echo -e "${RED}[FAIL]${NC} Policy missing rule for CronJobs at RequestResponse level."
        fi
        
        # 4. Check Deployments in kube-system RequestResponse rule
        if grep -qi "deployments" "$POLICY_FILE" && grep -qi "kube-system" "$POLICY_FILE"; then
            echo -e "${GREEN}[PASS]${NC} Policy includes rule for Deployments in kube-system."
            ((Q5_SCORE++))
        else
            echo -e "${RED}[FAIL]${NC} Policy missing rule for Deployments in kube-system namespace."
        fi
        
        # 5. Check kube-proxy watch exclusion
        if grep -qi "system:kube-proxy" "$POLICY_FILE" && grep -qi "watch" "$POLICY_FILE" && grep -qi "None" "$POLICY_FILE"; then
            echo -e "${GREEN}[PASS]${NC} Policy includes exclusion (None) for kube-proxy watch requests."
            ((Q5_SCORE++))
        else
            echo -e "${RED}[FAIL]${NC} Policy missing exclusion for kube-proxy watch requests on endpoints/services."
        fi
    else
        echo -e "${RED}[FAIL]${NC} Audit policy file not configured in manifest or file does not exist."
    fi
else
    echo -e "${RED}[FAIL]${NC} API Server manifest not found. Ensure this runs on the control plane."
fi

# Q5 Result
echo "------------------------------------------------------------------------------"
if [ $Q5_SCORE -eq $Q5_TOTAL ]; then
    echo -e "--> Q5 Result: ${GREEN}SUCCESS ($Q5_SCORE/$Q5_TOTAL)${NC}"
else
    echo -e "--> Q5 Result: ${RED}FAILED ($Q5_SCORE/$Q5_TOTAL)${NC}"
fi
echo "=============================================================================="

# ... Future validations will be appended below ...

echo "Validation complete!"

# ==============================================================================
# Question 6 VALIDATION: Security Context & Dockerfile Best Practices
# ==============================================================================
# Define colors if they aren't already defined in your master script
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "--- Q6 VALIDATION: Security Context & Dockerfile ---"
Q6_SCORE=0
Q6_TOTAL=4

# Target files (Change these if your files have different names/paths)
DOCKERFILE="./Dockerfile"
POD_MANIFEST="./pod.yaml"

# ------------------------------------------------------------------------------
# Question 6: Dockerfile Validations
# ------------------------------------------------------------------------------
if [ -f "$DOCKERFILE" ]; then
    # Issue 1: Prevent use of 'latest' tag
    # Checks if the FROM line no longer ends in :latest
    if ! grep -qE "^FROM .*:latest" "$DOCKERFILE"; then
        echo -e "${GREEN}[PASS]${NC} Dockerfile base image does not use the 'latest' tag."
        ((Q6_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Dockerfile base image is still using the 'latest' tag."
    fi

    # Issue 2: Prevent running as ROOT
    # Checks if the USER line was changed to 5375 or test-user
    if grep -qE "^USER (5375|test-user)" "$DOCKERFILE"; then
        echo -e "${GREEN}[PASS]${NC} Dockerfile USER is correctly set to 5375 (or test-user)."
        ((Q6_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Dockerfile USER is still ROOT or not correctly set to UID 5375."
    fi
else
    echo -e "${RED}[FAIL]${NC} Dockerfile not found at $DOCKERFILE."
fi

# ------------------------------------------------------------------------------
# Question 6: Pod Manifest Validations
# ------------------------------------------------------------------------------
if [ -f "$POD_MANIFEST" ]; then
    # Issue 3: Container running as root (runAsUser: 0)
    # Checks if runAsUser was updated to 5375 anywhere in the manifest
    if grep -qE "runAsUser:\s*5375" "$POD_MANIFEST"; then
        echo -e "${GREEN}[PASS]${NC} Pod manifest 'runAsUser' is correctly set to 5375."
        ((Q6_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Pod manifest 'runAsUser' is still 0 or not correctly set to 5375."
    fi

    # Issue 4: Container running in privileged mode (privileged: true)
    # Checks if privileged was changed to false
    if grep -qE "privileged:\s*false" "$POD_MANIFEST"; then
        echo -e "${GREEN}[PASS]${NC} Pod manifest 'privileged' flag is correctly set to false."
        ((Q6_SCORE++))
    else
        echo -e "${RED}[FAIL]${NC} Pod manifest 'privileged' flag is still set to true."
    fi
else
    echo -e "${RED}[FAIL]${NC} Pod manifest not found at $POD_MANIFEST."
fi

# ------------------------------------------------------------------------------
# Q6 Result
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
if [ $Q6_SCORE -eq $Q6_TOTAL ]; then
    echo -e "--> Q6 Result: ${GREEN}SUCCESS ($Q6_SCORE/$Q6_TOTAL)${NC}"
else
    echo -e "--> Q6 Result: ${RED}FAILED ($Q6_SCORE/$Q6_TOTAL)${NC}"
fi
echo "=============================================================================="