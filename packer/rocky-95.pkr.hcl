# Rocky Linux 9.5 golden-image pipeline for vSphere.
# Builds a VM from ISO + kickstart, provisions it with the local Ansible
# playbook, then converts it into a vSphere TEMPLATE (convert = true).
#
# Usage:
#   packer init .
#   PKR_VAR_vsphere_password='...' PKR_VAR_ssh_password='...' \
#     packer build -var-file=rocky-95.pkrvars.hcl .

packer {
  required_plugins {
    vsphere = {
      source  = "github.com/vmware/vsphere"
      version = ">= 1.0.0"
    }
    # Packer >= 1.13 moved the ansible provisioner out of core into a plugin.
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "vsphere_endpoint" {
  type    = string
  default = "vcenter.example.com"
}

variable "vsphere_username" {
  type    = string
  default = "ansible-svc@vsphere.local"
}

# Sensitive — supply via PKR_VAR_vsphere_password env var or a gitignored
# .pkrvars.hcl file. Never commit a real value.
variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "vsphere_datacenter" {
  type    = string
  default = "Example Dev"
}

variable "vsphere_cluster" {
  type    = string
  default = "Lower Env Linux App Services EVC"
}

variable "vsphere_datastore" {
  type    = string
  default = "PURE_ESXi_Lower_LinuxAppx_DS08"
}

variable "vsphere_network" {
  type    = string
  default = "dvPG-SitLinuxServers-443"
}

variable "vsphere_folder" {
  type    = string
  default = "Templates/Packer"
}

variable "vm_name" {
  type    = string
  default = "rocky-95-minimal"
}

# Verify this guest ID against the target vCenter version — older vCenter
# releases may not ship the rockyLinux9_64Guest ID (fall back to
# other4xLinux64Guest or rhel9_64Guest if the create call rejects it).
variable "guest_os_type" {
  type    = string
  default = "rockyLinux9_64Guest"
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

# Sensitive — the temporary build-VM password (matches the kickstart user).
# Supply via PKR_VAR_ssh_password. Never commit.
variable "ssh_password" {
  type      = string
  sensitive = true
}

# Path to the ISO relative to the datastore above.
variable "iso_path" {
  type    = string
  default = "ISOs/Rocky-9.5-x86_64-minimal.iso"
}

# ---------------------------------------------------------------------------
# Alternative: download the ISO instead of using a datastore path.
# Uncomment this block, comment `iso_path` in the source below, and add
# `iso_urls = [var.iso_url]` / `iso_checksum = var.iso_checksum` instead.
#
# variable "iso_url" {
#   type    = string
#   default = "https://dl.rockylinux.org/pub/rocky/9.5/isos/x86_64/Rocky-9.5-x86_64-minimal.iso"
# }
#
# variable "iso_checksum" {
#   type    = string
#   default = "sha256:REPLACE_WITH_UPSTREAM_SHA256"
# }
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

source "vsphere-iso" "rocky" {
  vcenter_server      = var.vsphere_endpoint
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = "true"

  datacenter = var.vsphere_datacenter
  cluster    = var.vsphere_cluster
  datastore  = var.vsphere_datastore
  folder     = var.vsphere_folder

  # Suffix with a build identifier so successive builds coexist instead of
  # colliding with the previous template.
  vm_name       = "${var.vm_name}-v${formatdate("YYYYMMDD-hhmm", timestamp())}"
  guest_os_type = var.guest_os_type

  CPUs = var.cpus
  RAM  = var.memory

  storage {
    disk_size             = 6072 # MiB
    disk_thin_provisioned = true
  }

  iso_paths = ["/${var.vsphere_datacenter}/datastore/${var.vsphere_datastore}/${var.iso_path}"]

  network_adapters {
    network = var.vsphere_network
  }

  boot_order = "disk,cdrom"
  boot_wait  = "15s"

  http_content = { "/rocky-9.ks" = templatefile("${path.root}/http/rocky-9.ks.tftpl", { ssh_password = var.ssh_password }) }

  # Rocky/RHEL 9 GRUB: arrow the cursor into the install entry's line and
  # append the kickstart URL, forcing a text console (no graphical boot).
  boot_command = [
    "<up><wait><enter><wait>",
    " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/rocky-9.ks<enter><wait5>",
  ]

  communicator     = "ssh"
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  shutdown_command = "sudo shutdown -h now"

  # The whole point: turn the built VM into a vSphere template.
  # (Plugin v2.x argument name: convert_to_template.)
  convert_to_template = true
  create_snapshot     = false
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name = "rocky-95-golden"

  sources = ["source.vsphere-iso.rocky"]

  # The roles-path hook reuses the repo's existing roles (../roles) from
  # inside packer/ansible — layer them in via the playbook.
  provisioner "ansible" {
    playbook_file   = "ansible/playbook.yml"
    extra_arguments = ["--roles-path", "../roles"]
  }
}
