variable "vsphere_datacenter" { type = string }
variable "vsphere_cluster" { type = string }
variable "vsphere_datastore" { type = string }
variable "vsphere_network" { type = string }
variable "vsphere_folder" { type = string }
variable "template_name" { type = string }
variable "domain" { type = string }
variable "gateway" { type = string }
variable "dns_servers" { type = list(string) }
variable "netmask" { type = number }

variable "prefix" {
  description = "Environment prefix, e.g. dev/prd — combined with role for the VM name"
  type        = string
}

variable "role" {
  description = "Role suffix, e.g. web/app/sql"
  type        = string
}

variable "ip" {
  description = "Static IPv4 — ideally reserved in Bluecat BEFORE apply"
  type        = string
}

variable "cpus" { type = number }
variable "memory" {
  description = "MB"
  type        = number
}
variable "disk_size" {
  description = "Root disk GB — 0 (default) inherits the template's disk size; >0 grows it"
  type        = number
  default     = 0
}

variable "admin_password" {
  description = "Per-VM local Administrator password set by guest customization — overrides the build-time password baked in the template. Supply via TF_VAR*/tfvars, never commit."
  type        = string
  sensitive   = true
}

# Optional domain-join inputs — leave join_domain = false for workgroup VMs.
variable "join_domain" {
  type    = bool
  default = false
}

variable "domain_user" {
  description = "Upn principal for domain join (only used when join_domain = true)"
  type        = string
  default     = null
}

variable "domain_password" {
  description = "Password for domain_user (only used when join_domain = true)"
  type        = string
  default     = null
  sensitive   = true
}

output "vm_name" {
  description = "Created VM name — feed this to Ansible inventory"
  value       = vsphere_virtual_machine.vm.name
}

output "vm_ip" {
  value = vsphere_virtual_machine.vm.default_ip_address
}

output "vm_id" {
  value = vsphere_virtual_machine.vm.id
}

variable "dns_suffixes" {
  description = "DNS search suffixes passed to guest customization"
  type        = list(string)
  default     = []
}

variable "workgroup_name" {
  type    = string
  default = "WORKGROUP"
}
