# ---------------------------------------------------------------------------
# Windows VM fleet — parallel to vms.tf (Linux), separate locals + module so
# neither map touches the other. Declared here as a request map; one entry
# per VM, for_each into module.windows_vms (./modules/vm-windows).
# ---------------------------------------------------------------------------

locals {
  win_vms = {
    # winweb01 = {
    #   prefix = "dev"
    #   role   = "winweb"
    #   ip     = "10.0.0.20"
    #   # Optional per-VM overrides (fall back to the win_default_* vars):
    #   # cpus      = 4
    #   # memory    = 8192
    #   # disk_size = 120
    #   # join_domain   = true   # also set TF_VAR_win_domain_user / _password
    #   # domain_user   = "svc-join@example.com"
    #   # domain_password = "..."  # prefer tfvars/env, never commit
    # }
    # winsql01 = {
    #   prefix   = "dev"
    #   role     = "winsql"
    #   ip       = "10.0.0.21"
    #   # Point this VM at the Server 2025 golden image built by
    #   # ../packer/windows-server-2025.pkr.hcl (no module change needed —
    #   # guest customization overrides name/password either way):
    #   template        = var.win25_template_name
    # }
  }
}

module "windows_vms" {
  source   = "./modules/vm-windows"
  for_each = local.win_vms

  # per-VM inputs
  prefix    = each.value.prefix
  role      = each.value.role
  ip        = each.value.ip
  cpus      = lookup(each.value, "cpus", var.win_default_cpus)
  memory    = lookup(each.value, "memory", var.win_default_memory)
  disk_size = lookup(each.value, "disk_size", var.win_default_disk_size)

  # sensitive / optional inputs
  admin_password  = var.win_admin_password
  join_domain     = lookup(each.value, "join_domain", false)
  domain_user     = lookup(each.value, "domain_user", null)
  domain_password = lookup(each.value, "domain_password", null)

  # env-level inputs (Windows-specific defaults; shared env vars reuse
  # variables.tf where the values match). Per-entry `template = "..."`
  # overrides the fleet default (e.g. a 2025 VM on a 2025 template).
  vsphere_datacenter = var.vsphere_datacenter
  vsphere_cluster    = var.vsphere_cluster
  vsphere_datastore  = var.win_vsphere_datastore
  vsphere_network    = var.win_vsphere_network
  vsphere_folder     = var.win_vsphere_folder
  template_name      = lookup(each.value, "template", var.win_template_name)
  domain             = var.domain
  gateway            = var.gateway
  dns_servers        = var.dns_servers
  dns_suffixes       = var.dns_suffixes
  netmask            = var.netmask
}
