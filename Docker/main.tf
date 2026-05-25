terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.54"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

# ── Provider ───────────────────────────────────────────────────────────────────
provider "proxmox" {
  endpoint  = var.proxmox_host
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
}

# ── Lookup template by name ────────────────────────────────────────────────────
data "proxmox_virtual_machine" "template" {
  node_name = var.proxmox_node
  name      = var.template_name
}

# ── Gaffer VM ──────────────────────────────────────────────────────────────────
resource "proxmox_virtual_machine" "gaffer" {
  node_name = var.proxmox_node
  vm_id     = var.vm_id
  name      = var.vm_name

  clone {
    vm_id = data.proxmox_virtual_machine.template.vm_id
    full  = true
  }

  cpu {
    cores = var.vm_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = var.vm_disk_size
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${var.vm_subnet}"
        gateway = var.gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }
  }

  agent {
    enabled = true
  }

  boot_order = ["scsi0"]
  on_boot    = true
  started    = true

  provisioner "remote-exec" {
    inline = ["echo 'VM is up'"]
    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = var.vm_ip
      private_key = file("~/.ssh/id_rsa")
      timeout     = "3m"
    }
  }
}
