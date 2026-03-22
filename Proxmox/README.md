# 🖥️ Proxmox VM Automation with Terraform & Cloud-Init

> Automate the deployment of multiple Ubuntu Server instances on Proxmox VE using Terraform — with Cloud-Init provisioning and Linked Clones for storage efficiency.

---

## 📋 Table of Contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Part 1 — Proxmox Setup](#part-1--proxmox-setup)
- [Part 2 — Provider Configuration](#part-2--provider-configuration)
- [Part 3 — Cloud-Init Template](#part-3--cloud-init-template)
- [Part 4 — Deployment](#part-4--deployment)
- [Lessons Learned & Bug Fixes](#️-lessons-learned--bug-fixes)

---

## ✨ Features

| Feature | Description |
|---|---|
| **Dynamic Scaling** | Uses `count` and `count.index` to auto-generate unique VM IDs, names, and IPs |
| **Storage Efficiency** | Linked Clones (`full = false`) to save space on `local-lvm` |
| **QEMU Guest Agent** | Automated activation for real-time IP reporting in Proxmox |
| **Resilient Deployment** | Optimized for Proxmox storage locking with controlled parallelism |

---

## 🔧 Prerequisites

- Proxmox VE installed and accessible
- Terraform installed on your local machine
- A Ubuntu Cloud-Init image downloaded (see [Part 3](#part-3--cloud-init-template))
- API Token generated for your Terraform user (see [Part 1](#part-1--proxmox-setup))

---

## Part 1 — Proxmox Setup

> **Why this matters:** Never use the `root` account for automation. This section creates a dedicated Terraform user with scoped permissions.

### 1.1 Create a Role

Navigate to **Datacenter → Permissions → Roles** and create a new role with the following permissions:

```
VM.Allocate, VM.Config.Disk, VM.Config.Memory, VM.Config.CPU
VM.PowerMgmt, VM.Audit, VM.GuestAgent
SDN.Use, Datastore.AllocateSpace, Datastore.Audit
```

### 1.2 Create a User

Navigate to **Datacenter → Permissions → Users** and create `terraform-user@pve`.

### 1.3 Assign Permissions

Navigate to **Datacenter → Permissions → Add (User Permission)**:

| Field | Value |
|---|---|
| Path | `/` |
| User | `terraform-user@pve` |
| Role | *(role from step 1.1)* |

Repeat for the **API Token permission**.

### 1.4 Generate an API Token

Navigate to **Datacenter → Permissions → API Tokens → Add**:

- Select `terraform-user@pve`
- Uncheck **"Privilege Separation"** *(simpler for homelabs)*
- Save the token — **you will only see it once**

---

## Part 2 — Provider Configuration

This project uses the [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) Terraform provider. Configure your `provider.tf` with your Proxmox endpoint and API token, then run:

```bash
terraform init
```

---

## Part 3 — Cloud-Init Template

> Instead of a local ISO, we clone a **pre-installed cloud image** — enabling full automation with no manual OS installation. The template VM cannot be started; it is only used as a clone source.

Run the following on your **Proxmox host shell**:

```bash
# Download Ubuntu 24.04 Cloud Image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create base VM
qm create 9000 --name "ubuntu-2404-template" --memory 2048 --net0 virtio,bridge=vmbr0

# Import and attach disk
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Add Cloud-Init drive and set boot order
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0

# Convert to template
qm template 9000
```

---

## Part 4 — Deployment

The core concept in `main.tf` is index-based math — `count.index` increments VM IDs, names, and IP addresses automatically, preventing resource collisions across all cloned VMs.

```bash
# Preview changes
terraform plan

# Deploy — parallelism=1 prevents Proxmox storage locking
terraform apply -parallelism=1

# Tear down
terraform destroy -parallelism=1
```

---

## ⚠️ Lessons Learned & Bug Fixes

### 1. KVM Hardware Virtualization Error

**Symptom:** VM fails to start with a KVM-related error.

**Fix:** Enter BIOS and enable virtualization (Intel VT-x / AMD-V) before Proxmox can pass it through to VMs.

---

### 2. Storage Locking — `lock-xxx.conf timeout`

**Symptom:** Terraform times out during `apply` with a lock conflict.

**Fix:** Force sequential creation and ensure VM IDs do not collide:

```bash
terraform apply -parallelism=1
```

---

### 3. Insufficient Permissions — HTTP 403

**Symptom:** Terraform returns `403 Forbidden` from the Proxmox API.

**Fix:** Read the error — it names the missing permission. Add it to your role, or via the Proxmox shell:

```bash
pveum aclmod / -user terraform-user@pve -role PVEVMAdmin
```

---

### 4. Terraform Variables Not Loading

**Symptom:** Terraform ignores your variable values.

**Fix:** Name your file exactly `terraform.tfvars` or `anything.auto.tfvars`. Any other name requires:

```bash
terraform apply -var-file="filename.tfvars"
```

---

### 5. VM Not Booting

**Symptom:** VM is created but fails to boot.

**Fix:** Confirm the Cloud-Init template was created correctly (`qm template 9000`) and that `scsi0` is set as the boot disk.

---

## 📁 Project Structure

```
.
├── provider.tf         # Proxmox provider configuration
├── main.tf             # VM resource definitions
├── variables.tf        # Input variable declarations
├── terraform.tfvars    # Your actual values — do not commit
└── outputs.tf          # Output definitions
```

> 💡 Add `terraform.tfvars` to `.gitignore` to avoid leaking API tokens and credentials.
