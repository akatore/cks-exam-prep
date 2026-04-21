Here is the step-by-step knowledge info for solving this AppArmor challenge, from loading it on the node to verifying it in the Pod.

### 1. Load the AppArmor Profile on the Node
First, you need to log into the node where the profile file was created and load it into the kernel using `apparmor_parser`.
```bash
# SSH into the specific node
ssh <WORKER_NODE_NAME>

# Load the profile into the kernel (-q means quiet, -r means replace/reload if it exists)
sudo apparmor_parser -q /etc/apparmor.d/nginx-profile-2
```

### 2. Check the Status on the Node
While still SSH'd into the node, you can verify that the profile is loaded and active.
```bash
sudo aa-status | grep nginx-profile-2
```
*You should see `nginx-profile-2` listed under the profiles in `enforce` mode.*
*(Type `exit` to return to the control plane).*

### 3. Apply it to the Pod (and target the node)
Edit the `secure-nginx-pod.yaml` manifest. You need to add the AppArmor annotation (or `securityContext` in k8s v1.30+) and a `nodeSelector` or `nodeName` to ensure it lands on the node with the profile.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-nginx
  annotations:
    # Format: container.apparmor.security.beta.kubernetes.io/<container-name>: localhost/<profile-name>
    container.apparmor.security.beta.kubernetes.io/nginx: localhost/nginx-profile-2
spec:

  nodeName: <WORKER_NODE_NAME> # Forces the pod to run on this specific node
  containers:
  - name: nginx
    image: nginx
```
*(Note: If your cluster is Kubernetes 1.30+, AppArmor is GA and configured in the container's `securityContext`: `securityContext: { appArmorProfile: { type: Localhost, localhostProfile: nginx-profile-2 } }`. However, the annotation method is still standard for most CKS exam simulators).*
```yaml
spec:
  nodeName: <WORKER_NODE_NAME>
  containers:
  - name: nginx
    image: nginx
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: nginx-profile-2
```

### 4. Verify it is Applied to the Pod
Deploy the pod using `kubectl apply -f secure-nginx-pod.yaml`. Once it's running, verify it in two ways:

**Method A: Check Pod Metadata**
```bash
kubectl describe pod secure-nginx | grep AppArmor
```
*Output should show: `Annotations: container.apparmor.security.beta.kubernetes.io/nginx: localhost/nginx-profile-2`*

**Method B: Check inside the Container (The Ultimate Proof)**
```bash
kubectl exec secure-nginx -- cat /proc/1/attr/current
```
*Output should show: `nginx-profile-2 (enforce)`* 

```bash
root@controlplane:~/cks-exam-prep$ kubectl exec secure-nginx -- cat /proc/1/attr/current
nginx-profile-2 (enforce)
```
