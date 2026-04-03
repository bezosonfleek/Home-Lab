terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "0.99.0"
    }
  }
}

provider "proxmox" {
    endpoint  = "https://IP/" #proxmox GUI page
    api_token = "user@pve!token-name=your-token"
    insecure  = "true" #because of the self-signed SSL certs
}
