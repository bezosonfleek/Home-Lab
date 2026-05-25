# ── Proxmox connection ─────────────────────────────────────────────────────────
variable "proxmox_host" {
  description = "Proxmox host URL e.g. https://192.168.1.10:8006"
  type        = string
  default     = "https://YOUR_PROXMOX_IP:8006"
}

variable "proxmox_node" {
  description = "Proxmox node name (shown in top-left of UI)"
  type        = string
  default     = "YOUR_NODE_NAME"
}

variable "proxmox_token_id" {
  description = "API token ID — format: user@realm!tokenname"
  type        = string
  default     = "YOUR_TOKEN_ID"   # e.g. terraform@pam!gaffer
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "API token secret (shown once when created)"
  type        = string
  default     = "YOUR_TOKEN_SECRET"
  sensitive   = true
}

# ── VM config ──────────────────────────────────────────────────────────────────
variable "vm_name" {
  description = "Name of the VM in Proxmox"
  type        = string
  default     = "gaffer-server"
}

variable "vm_id" {
  description = "Proxmox VM ID (must be unique)"
  type        = number
  default     = 300
}

variable "template_name" {
  description = "Cloud-init template to clone from"
  type        = string
  default     = "YOUR_TEMPLATE_NAME"   # e.g. ubuntu-2404-cloudinit
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disk"
  type        = string
  default     = "YOUR_STORAGE_POOL"    # e.g. local-lvm or local-zfs
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

# ── Networking ─────────────────────────────────────────────────────────────────
variable "vm_ip" {
  description = "Static IP for the Gaffer VM"
  type        = string
  default     = "192.168.1.240"
}

variable "vm_subnet" {
  description = "Subnet prefix length"
  type        = number
  default     = 24
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "YOUR_GATEWAY"   # e.g. 192.168.1.1
}

variable "bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

# ── SSH ────────────────────────────────────────────────────────────────────────
variable "ssh_public_key" {
  description = "SSH public key to inject into the VM"
  type        = string
  default     = "YOUR_SSH_PUBLIC_KEY"  # contents of ~/.ssh/id_rsa.pub
}

variable "vm_user" {
  description = "Default user created by cloud-init"
  type        = string
  default     = "ubuntu"
}
