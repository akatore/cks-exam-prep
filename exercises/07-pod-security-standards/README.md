# Exercise 07 — Pod Security Standards

> Related: [Pod Security Admission skeleton](../../skeletons/pod-security-admission.yaml) | [SecurityContext skeleton](../../skeletons/securitycontext.yaml) | [README — Minimize Microservice Vulnerabilities](../../README.md#domain-4--minimize-microservice-vulnerabilities-20)

Enforce Pod Security Standards (PSS) using Pod Security Admission (PSA). This replaced PodSecurityPolicy.

## Tasks

1. Create three namespaces:
   - `psa-privileged` with PSA mode `enforce` level `privileged`
   - `psa-baseline` with PSA mode `enforce` level `baseline`
   - `psa-restricted` with PSA mode `enforce` level `restricted`
2. Try to create a privileged pod in each namespace:
   ```yaml
   securityContext:
     privileged: true
   ```
   - Should succeed in `psa-privileged`
   - Should fail in `psa-baseline`
   - Should fail in `psa-restricted`
3. Create a compliant pod in `psa-restricted` that:
   - Runs as non-root (runAsNonRoot: true, runAsUser: 1000)
   - Drops all capabilities
   - Has read-only root filesystem
   - Disallows privilege escalation
   - Uses `RuntimeDefault` Seccomp profile
4. Add `warn` mode to `psa-baseline` and create a pod without security context — verify you get a warning

## Hints

- PSA labels: `pod-security.kubernetes.io/<mode>: <level>`
- Modes: `enforce`, `audit`, `warn`
- Levels: `privileged`, `baseline`, `restricted`
- Version label is optional: `pod-security.kubernetes.io/<mode>-version: v1.34`

## Verify

```bash
# Privileged pod in psa-baseline — should be rejected
k run test --image=nginx:1.27 -n psa-baseline \
  --overrides='{"spec":{"containers":[{"name":"test","image":"nginx:1.27","securityContext":{"privileged":true}}]}}'
# Error: violates PodSecurity "baseline:latest"

# Compliant pod in psa-restricted — should work
k get pod compliant-pod -n psa-restricted
```

## Cleanup

```bash
k delete ns psa-privileged psa-baseline psa-restricted
```

<details>
<summary>Solution</summary>

```bash
# Create namespaces with PSA labels
k create ns psa-privileged
k label ns psa-privileged pod-security.kubernetes.io/enforce=privileged

k create ns psa-baseline
k label ns psa-baseline pod-security.kubernetes.io/enforce=baseline
k label ns psa-baseline pod-security.kubernetes.io/warn=baseline

k create ns psa-restricted
k label ns psa-restricted pod-security.kubernetes.io/enforce=restricted
```

```yaml
# compliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: psa-restricted
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.27
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

```bash
k apply -f compliant-pod.yaml
k get pod compliant-pod -n psa-restricted
```

</details>
