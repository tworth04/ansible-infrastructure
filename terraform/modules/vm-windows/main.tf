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

  # Disk 0 inherits size/provisioning from the template (pattern from
  # vmware/packer-examples-for-vsphere, BSD-2-Clause) instead of forcing a
  # fixed size — avoids "new size smaller than disk" clone failures. The
  # Windows templates are typically 60-80GB, so a fixed 60 would fail.
  disk {
    label            = "disk0"
    size             = var.disk_size > 0 ? var.disk_size : data.vsphere_virtual_machine.template.disks[0].size
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks[0].eagerly_scrub
  }

  # Template ships VMware Tools + a vmxnet3 driver — the hardened NIC wins.
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }

  wait_for_guest_net_timeout = 15 # minutes; 0 disables waiting (IP/tools)

  clone {
    template_uuid = data.vsphere_virtual_machine.template.uuid

    customize {
      # windows_options (vs. linux_options in modules/vm): guest customization
      # sets a FRESH computer name + admin password on every clone, which is
      # what supersedes the build-time password baked into the template.
      windows_options {
        computer_name  = "${var.prefix}-${var.role}"
        admin_password = var.admin_password
        workgroup        = var.workgroup_name

        # Domain join — flip join_domain in the map entry and supply the
        # service creds (sensitive tfvars, never committed):
        # join_domain   = var.join_domain
        # domain_user   = var.domain_user
        # domain_password = var.domain_password
      }
      network_interface {
        ipv4_address = var.ip
        ipv4_netmask = var.netmask
      }
      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
      dns_suffix_list = var.dns_suffixes
    }
  }

  # vCenter-owned attributes — ignore so day-2 ops (vmotion, annotations,
  # re-pointing at a newer template build) don't show as drift. `disk` is
  # deliberately NOT ignored — disk changes (grow, add data disk) SHOULD
  # appear in plans. (Pattern from vmware/packer-examples-for-vsphere, BSD-2.)
  lifecycle {
    ignore_changes = [
      annotation,
      clone[0].template_uuid,
    ]
  }
}
