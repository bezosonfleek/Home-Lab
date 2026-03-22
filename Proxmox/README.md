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
- [Core Configuration](#️-core-configuration)
- [Outputs](#-outputs)
- [Lessons Learned & Bug Fixes](#️-lessons-learned--bug-fixes)

---

## ✨ Features

| Feature | Description |
|---|---|
| **Dynamic Scaling** | Uses `count` and `${count.index}` to auto-generate unique VM IDs, names, and IPs |
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

> **Why this matters:** You should never use the `root` account for automation. This section creates a dedicated Terraform user with scoped permissions.

### 1.1 Create a Role

Navigate to **Datacenter → Permissions → Roles** and create a new role with the following permissions:

```
VM.Allocate
VM.Config.Disk
VM.Config.Memory
VM.Config.CPU
VM.PowerMgmt
VM.Audit
VM.GuestAgent
SDN.Use
Datastore.AllocateSpace
Datastore.Audit
```

### 1.2 Create a User

Navigate to **Datacenter → Permissions → Users** and create:

```
Username: terraform-user@pve
```

### 1.3 Assign Permissions

Navigate to **Datacenter → Permissions → Add (Group/User Permission)**:

| Field | Value |
|---|---|
| Path | `/` |
| User | `terraform-user@pve` |
| Role | *(the role you created above)* |

Repeat the same for the **API Token permission**.

### 1.4 Generate an API Token

Navigate to **Datacenter → Permissions → API Tokens → Add**:

- Select your `terraform-user@pve`
- Uncheck **"Privilege Separation"** *(simpler for homelabs)*
- Save the token — **you will only see it once**

---

## Part 2 — Provider Configuration

Create a `provider.tf` file in your project root:

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://<YOUR_PROXMOX_IP>:8006/"
  api_token = "<YOUR_API_TOKEN>"
  insecure  = true  # Set to false if you have a valid TLS cert
}
```

Then initialize Terraform:

```bash
terraform init
```

---

## Part 3 — Cloud-Init Template

> Instead of using a local ISO, we clone a **pre-installed cloud image** — enabling full automation with no manual OS installation.

Run the following commands directly on your **Proxmox host shell**:

```bash
# Download the Ubuntu 24.04 Cloud Image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create a base VM for the template
qm create 9000 --name "ubuntu-2404-template" --memory 2048 --net0 virtio,bridge=vmbr0

# Import the disk image
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm

# Attach and configure the disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Add Cloud-Init drive
qm set 9000 --ide2 local-lvm:cloudinit

# Set boot order
qm set 9000 --boot c --bootdisk scsi0

# Convert to template (cannot be started, only cloned)
qm template 9000
```

> **Note:** The template VM (ID `9000`) will not boot — it is only used as a clone source.

---

## Part 4 — Deployment

```bash
# Preview changes
terraform plan

# Deploy — use parallelism=1 to prevent Proxmox storage locking issues
terraform apply -parallelism=1

# Destroy all VMs
terraform destroy -parallelism=1
```

---

## 🛠️ Core Configuration

The main resource uses index-based math to ensure unique VM IDs, names, and IP addresses with no collisions:

```hcl
resource "proxmox_virtual_environment_vm" "clone_vm" {
  count     = 3
  name      = "${var.vm_name}-${count.index + 1}"
  vm_id     = var.vm_id + count.index
  node_name = var.proxmox_node

  # Prevents "Wait for Shutdown" hangs during terraform destroy
  stop_on_destroy = true

  clone {
    vm_id = 9000  # Template ID from Part 3
    full  = false # Linked Clone — saves storage space
  }

  initialization {
    ip_config {
      ipv4 {
        # Dynamically increments last octet: .120, .121, .122
        address = "192.168.0.${120 + count.index}/24"
        gateway = "192.168.0.1"
      }
    }
  }
}
```

---

## 📤 Outputs

Add an `outputs.tf` to display your deployed infrastructure at a glance:

```hcl
output "vm_ips" {
  description = "IP addresses of all deployed VMs"
  value       = proxmox_virtual_environment_vm.clone_vm[*].initialization[0].ip_config[0].ipv4[0].address
}
```

---

## ⚠️ Lessons Learned & Bug Fixes

### 1. KVM Hardware Virtualization Error (VM won't boot)

**Symptom:** VM fails to start with a KVM-related error.

**Fix:** Enter your BIOS and enable all virtualization options (Intel VT-x / AMD-V). This must be enabled at the hardware level before Proxmox can pass it through to VMs.

---

### 2. Storage Locking — `lock-xxx.conf timeout`

**Symptom:** Terraform times out during `apply` with a lock conflict error.

**Fix:** Force sequential VM creation:

```bash
terraform apply -parallelism=1
```

Also ensure your VM IDs are incremented and do not collide (e.g., `200`, `201`, `202`).

---

### 3. Insufficient Permissions — HTTP 403

**Symptom:** Terraform returns a `403 Forbidden` error from the Proxmox API.

**Fix:** Read the error message carefully — it will name the missing permission. Add it to your role in Proxmox:

```bash
# Or via CLI on the Proxmox shell:
pveum aclmod / -user terraform-user@pve -role PVEVMAdmin
```

For Guest Agent access specifically, ensure `VM.GuestAgent` is in your role.

---

### 4. Terraform Variables Not Loading

**Symptom:** Terraform doesn't pick up your variable values.

**Fix:** Your variables file must be named exactly one of:

```
terraform.tfvars
anything.auto.tfvars
```

Any other name requires explicit `-var-file=filename.tfvars` during apply.

---

### 5. VM Not Booting (ISO-related)

**Symptom:** VM is created but fails to boot.

**Fix:** Ensure you have linked a valid boot disk or ISO in `main.tf`. When using Cloud-Init, confirm the template was converted correctly with `qm template 9000` and that the `scsi0` disk is set as the boot disk.

---

## 📁 Project Structure

```
.
├── provider.tf         # Proxmox provider configuration
├── main.tf             # VM resource definitions
├── variables.tf        # Input variable declarations
├── terraform.tfvars    # Your actual values (do not commit secrets)
└── outputs.tf          # Output definitions
```

---

> 💡 **Tip:** Add `terraform.tfvars` to your `.gitignore` to avoid leaking API tokens and credentials.
