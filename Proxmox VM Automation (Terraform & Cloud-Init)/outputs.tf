output "vm_info" {
  value = [
    for vm in proxmox_virtual_environment_vm.clone_vm : {
      name = vm.name
      id   = vm.vm_id
      ip   = vm.initialization[0].ip_config[0].ipv4[0].address
    }
  ]
}