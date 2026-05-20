#!/usr/bin/env bash
set -euo pipefail
DIR=/tmp/cks-lab/q21
mkdir -p "$DIR"
cat > "$DIR/Dockerfile" <<'EOF'
FROM alpine:3.19
ENV API_TOKEN=super-secret-do-not-commit
RUN apk add --no-cache curl
USER root
CMD ["sleep", "infinity"]
EOF
echo "Lab ready: insecure Dockerfile at $DIR/Dockerfile — fix exactly ONE line."
