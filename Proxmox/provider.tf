terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "0.99.0"
    }
  }
}

provider "proxmox" {
    endpoint  = "https://192.168.0.102:8006/"
    api_token = "tf-user@pve!tf01=e2346479-5999-4d27-894d-37653ed1ded7"
    insecure  = "true" #because of the self-signed SSL certs
}