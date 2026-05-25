output "vm_ip" {
  description = "IP address of the Gaffer VM"
  value       = var.vm_ip
}

output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_machine.gaffer.vm_id
}

output "vm_name" {
  description = "VM name in Proxmox"
  value       = proxmox_virtual_machine.gaffer.name
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.vm_user}@${var.vm_ip}"
}

output "ansible_command" {
  description = "Run this after terraform apply to deploy The Gaffer"
  value       = "ansible-playbook -i ../ansible/inventory.yml ../ansible/playbook.yml"
}
