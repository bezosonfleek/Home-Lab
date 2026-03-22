resource "proxmox_virtual_environment_vm" "clone_vm" {
   count     = 3
    name      = "${var.vm_name}-${count.index + 1}"
    node_name = var.proxmox_node         #replace with your node name 
    vm_id     = var.vm_id + count.index  #id number in your list - incremented to avoid lock conflicts

    #agent {enabled = true} #good practice to enable (allows things like graceful shutdown)

    clone {
    vm_id = 9000
    full  = false                       # makes linked clone fast/saves space
  }

   cpu {
     cores = 2
     type  = "host"
   }

   #cloud-init
   initialization {
     datastore_id = "local-lvm"
     user_account {
       username = "ubuntu"
       password = var.vm_password
     }
     ip_config {
       ipv4 {
         address = "192.168.0.${120 + count.index}/24"
         gateway = "192.168.0.1"
       }
     }
   }

}
