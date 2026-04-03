variable "proxmox_node" {
  type = string
  default = "your-node-name"
}

variable "vm_id" {
  type = number
}

variable "vm_name" {
  type = string
}

variable "vm_password" {
  type = string
  sensitive = true
}