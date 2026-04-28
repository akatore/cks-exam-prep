# ==============================================================================
# Question 8 VALIDATION: Encryption at Rest
# ==============================================================================
# Define colors if not already defined
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "--- Q8 VALIDATION: Encryption at Rest ---"
Q8_SCORE=0
Q8_TOTAL=5

API_SERVER="/etc/kubernetes/manifests/kube-apiserver.yaml"

# ------------------------------------------------------------------------------
# 1. API Server Flag Validation
# ------------------------------------------------------------------------------
echo ">> Checking API Server Configuration..."
if [ -f "$API_SERVER" ]; then
    if grep -q "\-\-encryption-provider-config=" "$API_SERVER"; then
        echo -e "${GREEN}[PASS]${NC} API Server has --encryption-provider-config flag configured."
        ((Q8_SCORE++))
        
        # Extract the file path from the flag
        ENCRYPTION_CONF=$(grep -oP '(?<=--encryption-provider-config=)[^\s]+' "$API_SERVER" | tr -d '"' | tr -d "'" | head -n 1)
        
        if [ -n "$ENCRYPTION_CONF" ] && [ -f "$ENCRYPTION_CONF" ]; then
            echo -e "${GREEN}[PASS]${NC} Encryption config file found at: $ENCRYPTION_CONF"
            ((Q8_SCORE++))
            
            # ------------------------------------------------------------------
            # 2. Encryption Configuration File Validation
            # ------------------------------------------------------------------
            echo ">> Analyzing Encryption Configuration File..."
            
            # Check if it targets secrets
            if grep -qi "\-\s*resources:\s*\[\s*['\"]*secrets['\"]*\s*\]" "$ENCRYPTION_CONF" || grep -A 2 "resources:" "$ENCRYPTION_CONF" | grep -qi "\-\s*secrets"; then
                echo -e "${GREEN}[PASS]${NC} Config file correctly targets the 'secrets' resource."
                ((Q8_SCORE++))
            else
                echo -e "${RED}[FAIL]${NC} Config file does not properly target 'secrets'."
            fi
            
            # Check for aescbc provider
            if grep -qi "aescbc:" "$ENCRYPTION_CONF"; then
                echo -e "${GREEN}[PASS]${NC} Config file includes the 'aescbc' provider."
                ((Q8_SCORE++))
            else
                echo -e "${RED}[FAIL]${NC} Config file is missing the 'aescbc' provider."
            fi
            
            # Check for identity provider
            if grep -qi "identity:" "$ENCRYPTION_CONF"; then
                echo -e "${GREEN}[PASS]${NC} Config file includes the 'identity' provider."
                ((Q8_SCORE++))
            else
                echo -e "${RED}[FAIL]${NC} Config file is missing the 'identity' provider (required for plaintext fallback)."
            fi

        else
            echo -e "${RED}[FAIL]${NC} Encryption config file specified in manifest does not exist at $ENCRYPTION_CONF."
        fi
    else
        echo -e "${RED}[FAIL]${NC} API Server is missing the --encryption-provider-config flag."
    fi
else
    echo -e "${RED}[FAIL]${NC} API Server manifest not found at $API_SERVER."
fi

# ------------------------------------------------------------------------------
# Q8 Result
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
if [ $Q8_SCORE -eq $Q8_TOTAL ]; then
    echo -e "--> Q8 Result: ${GREEN}SUCCESS ($Q8_SCORE/$Q8_TOTAL)${NC}"
else
    echo -e "--> Q8 Result: ${RED}FAILED ($Q8_SCORE/$Q8_TOTAL)${NC}"
fi
echo "=============================================================================="