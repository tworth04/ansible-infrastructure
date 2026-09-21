variable "vsphere_endpoint" {
  description = "vCenter FQDN"
  type        = string
  default     = "vcenter.example.com"
}

variable "vsphere_username" {
  description = "vCenter service account"
  type        = string
  default     = "ansible-svc@vsphere.local"
}

variable "vsphere_password" {
  description = "vCenter password — supply via TF_VAR_vsphere_password or a .tfvars file that is never committed"
  type        = string
  sensitive   = true
}

variable "vsphere_datacenter" {
  description = "Datacenter name"
  type        = string
  default     = "Example Dev"
}

variable "vsphere_cluster" {
  description = "Cluster to deploy into"
  type        = string
  default     = "Lower Env Linux App Services EVC"
}

variable "vsphere_datastore" {
  type    = string
  default = "PURE_ESXi_Lower_LinuxAppx_DS08"
}

variable "vsphere_network" {
  description = "Port group for the VM NIC"
  type        = string
  default     = "dvPG-SitLinuxServers-443"
}

variable "vsphere_folder" {
  description = "VM folder placement"
  type        = string
  default     = "Example Linux"
}

variable "template_name" {
  description = "Golden image built by ../packer (or an existing template)"
  type        = string
  default     = "rocky-95-minimal"
}

variable "netmask" {
  type    = number
  default = 24
}

variable "gateway" {
  type    = string
  default = "10.0.0.1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["10.0.0.5", "10.0.0.6"]
}

variable "domain" {
  type    = string
  default = "example.com"
}

variable "default_cpus" {
  type    = number
  default = 2
}

variable "default_memory" {
  type    = number
  default = 4096
}

variable "default_disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 60
}
