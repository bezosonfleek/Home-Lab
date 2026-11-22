# Secure Remote Access via Restricted SSH Tunneling

This guide documents how to grant a guest user (`martin`) secure, read-only remote access to an internal web service (such as Grafana running on `localhost:3000`) using **SSH Local Port Forwarding** without exposing ports to the public internet or granting interactive shell access.

---

## 1. Host Configuration

### Step 1: Create a Restricted User (`nologin`)
Create a dedicated Linux account with `/usr/sbin/nologin` so the user can authenticate for port forwarding but cannot open an interactive terminal session:

```bash
sudo useradd -m -s /usr/sbin/nologin martin
sudo mkdir -p /home/martin/.ssh
sudo chmod 700 /home/martin/.ssh
```

### Step 2: Generate and Install SSH Keys
Generate an Ed25519 keypair, install the public key into `martin`'s `authorized_keys` file, and enforce strict ownership and permissions:

```bash
# Generate keypair
ssh-keygen -t ed25519 -C "martin-grafana" -f /tmp/martin_key -N ""

# Install public key
sudo cp /tmp/martin_key.pub /home/martin/.ssh/authorized_keys
sudo chmod 600 /home/martin/.ssh/authorized_keys
sudo chown -R martin:martin /home/martin/.ssh

# Securely transfer /tmp/martin_key to the client, then remove temporary files
rm -f /tmp/martin_key /tmp/martin_key.pub
```

*(Note: The server only uses `/home/martin/.ssh/authorized_keys` for PKI verification; removing the temporary files in `/tmp` keeps the host clean and avoids leaving the private key behind.)*

### Step 3: Lock Down SSH Capabilities in `sshd_config`
Restrict `martin` strictly to local TCP port forwarding for `localhost:3000`:

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

### Step 4: Create a Read-Only Application Account
Because SSH only secures the network tunnel and does not manage application-level permissions:
1. In Grafana, go to **Administration → Users and access → Users → New user**.
2. Create a dedicated account for `martin` with the **Viewer** role so he cannot modify dashboards or alert rules.

---

## 2. Client Connection

On the client machine, place the private key in `~/.ssh/martin_key`, lock down its permissions, and open the local tunnel (using an unused local port like `7000` to avoid conflicts with local services on port `3000`):

```bash
chmod 600 ~/.ssh/martin_key
ssh -i ~/.ssh/martin_key -N -L 7000:localhost:3000 martin@<SERVER_IP>
```

* **`-N`**: Do not execute a remote command or allocate a shell (required for `nologin` users; the terminal will stay open and silent while the tunnel is active).
* **`-L 7000:localhost:3000`**: Binds port `7000` on the client (`127.0.0.1`) and forwards traffic over SSH to `localhost:3000` on the server.
* **Access URL:** Open `http://localhost:7000` in a browser while the terminal remains open.

*(Optional: Add `-f` before `-i` to run the tunnel in the background.)*

---

## 3. Troubleshooting & Issues Encountered

During setup and testing, the following SSH and access issues were encountered and resolved:

### 1. `.ssh` Directory Typo & Missing User on Host
* **Issue:** Running `chown -R martin:martin /home/martin/.ssh` failed with `chown: invalid user: 'martin:martin'`, and an earlier `mkdir` command had a typo (`/home/martin.ssh`).
* **Cause:** The `martin` account had not yet been created on the target `learning` host, and a missing `/` created a misnamed directory.
* **Resolution:** Created `/home/martin/.ssh` properly, created the user via `sudo useradd -s /usr/sbin/nologin martin`, and re-applied `sudo chown -R martin:martin /home/martin/.ssh`.

### 2. SSH Falling Back to Password Authentication
* **Issue:** Running `ssh -i ~/.ssh/martin_key ...` prompted for `martin@<SERVER_IP>'s password:` instead of authenticating with the key.
* **Cause:** Either `martin` did not exist / own `.ssh` on the target host yet, or strict permissions (`700` on `.ssh`, `600` on `martin_key` and `authorized_keys`) were missing.
* **Resolution:** Set `chmod 600 ~/.ssh/martin_key` on the client, confirmed `martin:martin` ownership and `600` permissions on `/home/martin/.ssh/authorized_keys`, and verified key negotiation using `ssh -v`.

### 3. Local Port `3000` Already in Use (`Address already in use`)
* **Issue:** Running `-L 3000:localhost:3000` failed with:
  `bind [127.0.0.1]:3000: Address already in use`
* **Cause:** Port `3000` was already occupied on the client machine.
* **Resolution:** Changed the local binding port to `7000` (`-L 7000:localhost:3000`) while keeping the remote destination at `3000`, accessing the service at `http://localhost:7000`.

### 4. Terminal Appeared "Stuck" After Connecting
* **Issue:** Running `ssh -i ~/.ssh/martin_key -N -L 7000:localhost:3000 martin@<SERVER_IP>` returned no prompt and appeared to hang.
* **Cause:** Expected behavior of the `-N` flag—authentication succeeded and the tunnel stays active in the foreground until terminated with `Ctrl+C`.
* **Resolution:** Left the terminal running in the background/another tab and accessed `http://localhost:7000` in the browser.

### 5. Tunnel Logged Straight into the Admin Account During Testing
* **Issue:** Opening `http://localhost:7000` during local testing bypassed the login screen and loaded the existing `admin` session.
* **Cause:** Browsers scope session cookies by hostname (`localhost`) rather than port number, so `localhost:7000` reused the active `localhost:3000` admin cookie.
* **Resolution:** Verified that SSH tunneling only secures transport and does not enforce application roles; tested `martin`'s read-only **Viewer** login in a separate Incognito/Private browser session.