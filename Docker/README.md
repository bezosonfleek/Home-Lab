# The Gaffer — IaC Setup

## Prerequisites

On your workstation:
- Terraform >= 1.6 — https://developer.hashicorp.com/terraform/install
- Ansible >= 2.14 — `pip install ansible`
- Ansible Docker collection — `ansible-galaxy collection install community.docker`
- SSH key pair — `ssh-keygen -t rsa -b 4096`

On Proxmox:
- API token with PVEVMAdmin + PVEDatastoreUser roles
- Cloud-init template with qemu-guest-agent installed

---

## Folder structure

```
gaffer-iac/
├── Makefile                    ← all commands live here
├── terraform/
│   ├── backend.tf              ← local state (swap to Minio later)
│   ├── variables.tf            ← all inputs with placeholders
│   ├── main.tf                 ← VM provisioning
│   └── outputs.tf              ← IP, VM ID, SSH command
└── ansible/
    ├── inventory.yml           ← points to 192.168.1.240
    ├── playbook.yml            ← installs Docker, deploys app
    ├── vars/
    │   └── secrets.yml         ← encrypt this with ansible-vault
    └── templates/
        └── .env.j2             ← generates .env on the server
```

---

## Step 1 — Fill in your values

Edit `terraform/variables.tf` and replace all placeholders:
- `YOUR_PROXMOX_IP`
- `YOUR_NODE_NAME`
- `YOUR_TOKEN_ID`
- `YOUR_TOKEN_SECRET`
- `YOUR_TEMPLATE_NAME`
- `YOUR_STORAGE_POOL`
- `YOUR_GATEWAY`
- `YOUR_SSH_PUBLIC_KEY`  ← paste contents of ~/.ssh/id_rsa.pub

Edit `ansible/vars/secrets.yml` and replace:
- `YOUR_FRONTEND_URL`
- `YOUR_DB_PASSWORD`
- `YOUR_SECRET_KEY`
- `YOUR_TUNNEL_TOKEN`

---

## Step 2 — Encrypt your secrets

```bash
make encrypt
# enter a vault password you'll remember
```

---

## Step 3 — Provision + deploy

```bash
# Full run — creates VM then deploys app
make all

# Or separately:
make provision   # Terraform only
make deploy      # Ansible only
```

---

## Day-to-day commands

```bash
make ssh         # SSH into the server
make logs        # Tail backend logs
make health      # Check app is responding
make destroy     # Destroy the VM when done
```

---

## Migrating state to Minio later

1. Set up Minio (see main README)
2. Uncomment the `backend "s3"` block in `terraform/backend.tf`
3. Delete the local `backend "local"` block
4. Run `terraform init -migrate-state`
5. Terraform will copy local state → Minio automatically
