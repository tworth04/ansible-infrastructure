data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vm" {
  name             = "${var.prefix}-${var.role}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vsphere_folder

  num_cpus = var.cpus
  memory   = var.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  # The Packer template owns disk 0's base layout — size here only extends it.
  disk {
    label            = "disk0"
    size             = var.disk_size
    thin_provisioned = true
  }

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }

  wait_for_guest_net_timeout = 15 # minutes; 0 disables waiting (IP/tools)

  clone {
    template_uuid = data.vsphere_virtual_machine.template.uuid

    customize {
      linux_options {
        host_name = "${var.prefix}-${var.role}"
        domain    = var.domain
      }
      network_interface {
        ipv4_address = var.ip
        ipv4_netmask = var.netmask
      }
      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  # vCenter-owned attributes — ignore so day-2 ops (vmotion, annotations,
  # hot-added disks) don't show as drift.
  lifecycle {
    ignore_changes = [
      annotation,
      disk,
    ]
  }
}
