# Homelab Monitoring & Secure Remote Access (Grafana + SSH Tunneling)

This guide documents the setup of the **CPU Lab** monitoring dashboard in Grafana, the configuration of Prometheus-backed alerting rules, and the implementation of a restricted SSH local port-forwarding tunnel to securely share dashboard access without exposing ports to the public internet.

---

## 1. Grafana Dashboard Configuration ("CPU Lab")

The **CPU Lab** dashboard tracks container-level resource metrics scraped via `cAdvisor` and stored in **Prometheus**.

### Panels
1. **Container CPU Rate**
   * **Data Source:** `prometheus`
   * **PromQL Query:**
     ```promql
     rate(container_cpu_system_seconds_total[5m])
     ```
   * **Purpose:** Converts the raw cumulative CPU counter into a per-second rate over a 5-minute window.

2. **Container Memory Usage**
   * **Data Source:** `prometheus`
   * **PromQL Query:**
     ```promql
     container_memory_usage_bytes
     ```
   * **Unit Formatting:** `GiB` (Gibibytes)

---

## 2. Alerting Setup (`sakora-test`)

Grafana alerting is configured to evaluate container CPU rates and route notifications to the `sakora-poc` contact point.

### Rule Configuration
* **Rule Name:** `sakora-test`
* **Rule Type:** Grafana-managed alert
* **Query (`A`):**
  * **Metric:** `container_cpu_system_seconds_total`
  * **Operation:** `Rate` (Range: `5m`) — evaluates as `rate(container_cpu_system_seconds_total[5m])`
  * **Query Type:** `Instant`
* **Condition (`C` - Threshold):**
  * **Input:** `A` (Directly evaluates the instant query output)
  * **Condition:** `IS ABOVE 0.01`
* **Notifications:**
  * **Contact Point:** `sakora-poc`
  * **Summary:** `Container CPU usage exceeded threshold`

---

## 3. Secure Remote Access via Restricted SSH Tunneling

Rather than exposing Grafana (`http://localhost:3000`) directly to the internet without TLS, remote access is granted using **SSH Local Port Forwarding** tied to a restricted, shell-less Linux account (`martin`).

### Step 1: Create the Restricted User on the Host
Create a dedicated user with `/usr/sbin/nologin` so they cannot open an interactive terminal session:

```bash
sudo useradd -m -s /usr/sbin/nologin martin
sudo mkdir -p /home/martin/.ssh
sudo chmod 700 /home/martin/.ssh
```

### Step 2: Generate and Install SSH Keys
Generate an Ed25519 keypair, install the public key into `martin`'s `authorized_keys`, and set strict permissions:

```bash
# Generate keypair
ssh-keygen -t ed25519 -C "martin-grafana" -f /tmp/martin_key -N ""

# Install public key
sudo cp /tmp/martin_key.pub /home/martin/.ssh/authorized_keys
sudo chmod 600 /home/martin/.ssh/authorized_keys
sudo chown -R martin:martin /home/martin/.ssh

# Securely transfer /tmp/martin_key to the client, then clean up temporary files
rm -f /tmp/martin_key /tmp/martin_key.pub
```

### Step 3: Restrict SSH Capabilities in `sshd_config`
Lock the `martin` user strictly to local TCP forwarding for port `3000`:

```bash
sudo tee -a /etc/ssh/sshd_config << 'EOF'

Match User martin
    AllowTcpForwarding local
    PermitOpen localhost:3000
    X11Forwarding no
    AllowAgentForwarding no
EOF

# Validate syntax and restart SSH daemon
sudo sshd -t && sudo systemctl restart ssh
```

### Step 4: Create a Read-Only Grafana Account
1. In Grafana, navigate to **Administration → Users and access → Users → New user**.
2. Create an account for the guest user with the **Viewer** role to prevent unintended dashboard or alert modifications.

### Step 5: Client Connection Command
On the client machine, ensure the private key has `600` permissions and start the SSH tunnel (using local port `3001` to avoid local port `3000` conflicts):

```bash
chmod 600 ~/.ssh/martin_key
ssh -i ~/.ssh/martin_key -N -L 3001:localhost:3000 martin@<SERVER_IP>
```

* `-N`: Do not execute a remote command (required for `nologin` users).
* `-L 3001:localhost:3000`: Maps local port `3001` on the client to port `3000` on the Grafana host.
* **Access URL:** `http://localhost:3001`

---

## 4. Troubleshooting & Issues Encountered

During setup and testing, the following issues were identified and resolved:

### 1. Alert Rules Hidden by Default Filter Chips
* **Issue:** Navigating to **Alerting → Alert rules** showed *"You haven't created any rules yet"* or hid existing rules.
* **Cause:** Active search filter chips (such as `health:error` or `contactPoint:sakora-poc`) were filtering out rules.
* **Resolution:** Clicked **× Clear filters** to reset the search bar.

### 2. Alert Threshold Input Mismatch (`Input B` vs `Input A`)
* **Issue:** The `Threshold` expression (`C`) initially defaulted to `Input B` (a `Reduce` expression), even though no `B` block was needed.
* **Cause:** Query `A` was already configured as `Type: Instant`, returning a single scalar value per series rather than a multi-point time series.
* **Resolution:** Changed the `Threshold` block's **Input** directly to `A`.

### 3. `.ssh` Directory Typo & Missing User on Host
* **Issue:** Running `chown -R martin:martin /home/martin/.ssh` returned `chown: invalid user: 'martin:martin'`, and an earlier `mkdir` command had a typo (`/home/martin.ssh`).
* **Cause:** The `martin` user had not yet been created on the target `learning` host, and a missing `/` created a misnamed directory.
* **Resolution:** Created `/home/martin/.ssh` properly, ran `sudo useradd -s /usr/sbin/nologin martin`, and re-applied `chown -R martin:martin /home/martin/.ssh`.

### 4. SSH Falling Back to Password Authentication
* **Issue:** Running `ssh -i ~/.ssh/martin_key ...` prompted for `martin@<SERVER_IP>'s password:` despite using `-i`.
* **Cause:** Either the `martin` user/ownership was not yet configured on the target host, or strict file permissions (`700` on `.ssh`, `600` on `martin_key` and `authorized_keys`) were not enforced.
* **Resolution:** Enforced `chmod 600` on the client private key, verified `martin:martin` ownership and `600` permissions on `/home/martin/.ssh/authorized_keys`, and used `ssh -v` to debug key offers.
