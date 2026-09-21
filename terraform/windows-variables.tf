# ---------------------------------------------------------------------------
# Windows-specific variables (NEW file — existing variables.tf untouched).
# Env vars shared with the Linux fleet (endpoint/creds/datacenter/cluster/
# domain/gateway/dns/netmask) live in variables.tf and are reused as-is.
# ---------------------------------------------------------------------------

variable "win_template_name" {
  description = "Windows golden image built by ../packer (or an existing template)"
  type        = string
  default     = "windows-2022-minimal"
}

variable "win_admin_password" {
  description = "Per-VM local Administrator password applied by guest customization — supply via TF_VAR_win_admin_password or a .tfvars file that is never committed"
  type        = string
  sensitive   = true
}

variable "win_vsphere_datastore" {
  description = "Datastore for Windows VMs (defaults to the same sanitized value as the Linux fleet)"
  type        = string
  default     = "PURE_ESXi_Lower_LinuxAppx_DS08"
}

variable "win_vsphere_network" {
  description = "Port group for the Windows VM NIC"
  type        = string
  default     = "dvPG-SitLinuxServers-443"
}

variable "win_vsphere_folder" {
  description = "VM folder placement for Windows VMs"
  type        = string
  default     = "Example Windows"
}

variable "win_default_cpus" {
  type    = number
  default = 2
}

variable "win_default_memory" {
  description = "MB — Windows wants more headroom than the minimal Linux box"
  type        = number
  default     = 4096
}

variable "win_default_disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 120
}

variable "workgroup_name" {
  type        = string
  default     = "WORKGROUP"
  description = "NetBIOS workgroup when join_domain = false (max 15 chars, no dots)."
}

variable "win25_template_name" {
  type        = string
  description = "Exact Windows Server 2025 template name as produced by Packer (versioned)."
}
