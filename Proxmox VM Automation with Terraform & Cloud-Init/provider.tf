terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "0.99.0"
    }
  }
}

provider "proxmox" {
<<<<<<< HEAD:Proxmox VM Automation with Terraform & Cloud-Init/provider.tf
    endpoint  = "https://IP/" #proxmox GUI page
=======
    endpoint  = "https://IP/"
>>>>>>> b3e3907c23e7aebc7e757dfeac267d458e0109ba:Proxmox/provider.tf
    api_token = "user@pve!token-name=your-token"
    insecure  = "true" #because of the self-signed SSL certs
}
