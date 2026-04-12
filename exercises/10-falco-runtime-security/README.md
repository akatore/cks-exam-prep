# Exercise 10 — Falco Runtime Security

> Related: [Falco Rule skeleton](../../skeletons/falco-rule.yaml) | [README — Monitoring, Logging and Runtime Security](../../README.md#domain-6--monitoring-logging-and-runtime-security-20)

Use Falco to detect suspicious runtime behavior. This is a high-value CKS topic.

## Tasks

1. Install Falco on a node (or use the Helm chart in Kubernetes)
2. Verify Falco is running and detecting events
3. Trigger some built-in Falco rules:
   - Open a shell in a container: `k exec -it <pod> -- /bin/bash`
   - Read a sensitive file: `k exec <pod> -- cat /etc/shadow`
   - Write to `/etc` directory: `k exec <pod> -- touch /etc/suspicious`
4. Check Falco logs for alerts:
   ```bash
   journalctl -u falco | tail -20
   # or
   k logs -n falco -l app.kubernetes.io/name=falco | tail -20
   ```
5. Create a custom Falco rule that alerts when someone runs `curl` or `wget` inside a container
6. Load the custom rule and trigger it
7. Identify which pod triggered a Falco alert from the log output

## Hints

- Falco watches system calls in real-time
- Default rules cover: shell in container, sensitive file read, network tools, etc.
- Custom rules go in `/etc/falco/falco_rules.local.yaml`
- On the exam, you'll likely need to READ Falco output, not install it

## Verify

```bash
# Check Falco logs after running shell in container
journalctl -u falco --no-pager | grep "Terminal shell"
# or
k logs -n falco -l app.kubernetes.io/name=falco | grep "Terminal shell"
```

## Cleanup

```bash
# Remove custom rules
sudo rm /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco
```

<details>
<summary>Solution</summary>

```bash
# Install Falco (on node)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | sudo tee /etc/apt/sources.list.d/falcosecurity.list
sudo apt-get update
sudo apt-get install -y falco

sudo systemctl start falco
sudo systemctl enable falco

# Trigger alerts
k run test --image=nginx:1.27
k exec -it test -- /bin/bash    # triggers "Terminal shell in container"
k exec test -- cat /etc/shadow  # triggers "Read sensitive file untrusted"

# Check alerts
journalctl -u falco --no-pager | tail -20
```

Custom rule:
```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Detect curl or wget in container
  desc: Detect network download tools in containers
  condition: >
    spawned_process and container and
    (proc.name in (curl, wget))
  output: >
    Network tool launched in container
    (user=%user.name command=%proc.cmdline container=%container.name
    image=%container.image.repository pod=%k8s.pod.name ns=%k8s.ns.name)
  priority: WARNING
  tags: [network, container]
```

```bash
sudo cp falco-rules.local.yaml /etc/falco/falco_rules.local.yaml
sudo systemctl restart falco

# Trigger
k exec test -- curl -s https://example.com

# Verify alert
journalctl -u falco --no-pager | grep "Network tool"
```

</details>
