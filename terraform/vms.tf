locals {
  # Provision request map — add VMs here. Keys become Terraform resource addresses
  # (module.vms["web01"]), values feed the vm module below.
  vms = {
    web01 = {
      prefix = "dev"
      role   = "web"
      ip     = "10.0.0.10"
    }
    # app01 = {
    #   prefix    = "dev"
    #   role      = "app"
    #   ip        = "10.0.0.11"
    #   cpus      = 4
    #   memory    = 8192
    #   disk_size = 120
    # }
  }
}

module "vms" {
  source   = "./modules/vm"
  for_each = local.vms

  # per-VM inputs
  prefix    = each.value.prefix
  role      = each.value.role
  ip        = each.value.ip
  cpus      = lookup(each.value, "cpus", var.default_cpus)
  memory    = lookup(each.value, "memory", var.default_memory)
  disk_size = lookup(each.value, "disk_size", var.default_disk_size)

  # env-level inputs
  vsphere_datacenter = var.vsphere_datacenter
  vsphere_cluster    = var.vsphere_cluster
  vsphere_datastore  = var.vsphere_datastore
  vsphere_network    = var.vsphere_network
  vsphere_folder     = var.vsphere_folder
  template_name      = var.template_name
  domain             = var.domain
  gateway            = var.gateway
  dns_servers        = var.dns_servers
  dns_suffixes       = var.dns_suffixes
  netmask            = var.netmask
}
