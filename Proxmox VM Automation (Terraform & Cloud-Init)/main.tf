resource "proxmox_virtual_environment_vm" "iso_vm" {
    name      = "terraform-test-01"
    node_name = "t41"               #replace with your node name 
    vm_id     = 104                 #id number in your list

    cpu {
        cores = 2
    }

    memory {
        dedicated = 2048
    }

    network_device {
        bridge = "vmbr0"
    }

    disk {
        datastore_id = "local-lvm"  #replace with your storage name
        interface    = "scsi0"
        size         = 20
    }

    cdrom {
      #enabled = true  #is by true by default since we are using the cdrom{} block
      file_id = "local:iso/ubuntu-24.04.3-live-server-amd64.iso"
    }

    initialization {
      datastore_id = "local-lvm"
    }
}
