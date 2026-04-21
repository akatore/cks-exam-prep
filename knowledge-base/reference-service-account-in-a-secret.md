To reference a **ServiceAccount** in a Secret (so that Kubernetes automatically populates the Secret with a token for that account), you need to include two specific details in your Secret's YAML file:

1.  **The Type:** It must be set to `kubernetes.io/service-account-token`.
2.  **The Annotation:** You must add an annotation named `kubernetes.io/service-account.name` that holds the exact name of the ServiceAccount.

### The YAML Manifest

Here is the exact syntax you would use. This example perfectly matches the requirements for your "Question 3" scenario, referencing the `default` ServiceAccount:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret-token      # Name of your secret
  namespace: default
  annotations:
    kubernetes.io/service-account.name: "default"  # <-- This is the reference!
type: kubernetes.io/service-account-token        # <-- Required type
```

### How to apply this in your exam/practice:

You can't easily create this specific type of secret using a single imperative `kubectl create secret` command, so the fastest way to create it during an exam is to use standard input with `cat`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: secret-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: "default"
type: kubernetes.io/service-account-token
EOF
```

### Why do we do this?
Since Kubernetes v1.24, ServiceAccount tokens are no longer automatically generated as Secrets. If you have an older application that expects to mount a ServiceAccount token directly from a Secret (like in your Question 3 scenario), you have to manually create the Secret and link it using the annotation shown above. The Kubernetes control plane will see the annotation and automatically inject the `token` and `ca.crt` data into the Secret for you.