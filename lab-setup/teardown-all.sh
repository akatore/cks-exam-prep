#!/usr/bin/env bash
set -euo pipefail
for ns in workloads supply-chain psa-lab team-a team-b sa-lab ingress-lab immutability-lab gatekeeper-lab foo trusted app; do
  kubectl delete namespace "$ns" --ignore-not-found --timeout=60s 2>/dev/null || true
done
kubectl delete clusterrolebinding cks-anon-test --ignore-not-found 2>/dev/null || true
echo "Kubernetes lab namespaces removed. Restore Docker manually if you ran q03 (see q03 teardown in README)."
