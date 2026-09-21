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
  description = "Role suffix, e.g. web/app/db"
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
  description = "Root disk GB — template disk is grown to this size"
  type        = number
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
