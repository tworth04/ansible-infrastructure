# Windows Server 2022 golden-image pipeline for vSphere.
# Builds a VM from ISO + autounattend.xml (rendered into a virtual CD),
# enables WinRM in-guest via FirstLogonCommands, provisions hygiene over
# WinRM, then converts the VM into a vSphere TEMPLATE.
#
# Structure cribbed from vmware/packer-examples-for-vsphere
# (github.com/vmware/packer-examples-for-vsphere, BSD-2-Clause) —
# builds/windows/server/2022. Trimmed to one Standard/Desktop build.
#
# NOTE: Windows Server 2025 lives in its own template — see
# windows-server-2025.pkr.hcl (2025 needs efi-secure + vTPM + vSphere 8+).
#
# Usage:
#   packer init .
#   PKR_VAR_vsphere_password='...' PKR_VAR_winrm_password='***' \
#     packer build -only='windows-server-2022-golden.*' -var-file=windows-server.pkrvars.hcl.example .

# required_plugins for vsphere + ansible live in rocky-95.pkr.hcl — Packer
# shares one plugin/variable scope per directory, so do not redeclare here.

# ---------------------------------------------------------------------------
# Variables (win_* = Windows-specific)
#
# NOTE: Packer shares ONE variable scope per directory across all .pkr.hcl
# files. The environment vars (vsphere_endpoint/username/password/
# datacenter/cluster/datastore/network/folder) are defined once in
# rocky-95.pkr.hcl and reused here — do NOT redefine them. VM-shape vars
# are win_-prefixed so the Windows build doesn't inherit the Linux values.
# ---------------------------------------------------------------------------

variable "win_vm_name" {
  type    = string
  default = "windows-2022-minimal"
}

# Windows Server 2022's guest ID (2019srvNext is the vSphere ID for 2022).
# For 2025: windows2025srvNext_64Guest. Verify against your vCenter version.
variable "win_guest_os_type" {
  type    = string
  default = "windows2019srvNext_64Guest"
}

variable "win_cpus" {
  type    = number
  default = 2
}

variable "win_memory" {
  type    = number
  default = 4096
}

# WinRM build account. The template uses the built-in Administrator — the
# autounattend sets its password to winrm_password for the build only.
variable "winrm_username" {
  type    = string
  default = "Administrator"
}

# Sensitive — the BUILD-TIME-ONLY Administrator/WinRM password. It ends up
# baked into the template's local Administrator account: rotate it on first
# boot (Terraform guest customization sets a fresh per-VM admin password;
# see terraform/modules/vm-windows).
variable "winrm_password" {
  type      = string
  sensitive = true
}

# Path to the ISO relative to the datastore above.
variable "win_iso_path" {
  type    = string
  default = "ISOs/Windows-Server-2022.iso"
}

# Eval ISO needs no key; set for retail/vl media (referenced by the
# commented ProductKey block in http/autounattend.xml).
variable "win_inst_os_key" {
  type    = string
  default = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
}

# Which image inside the install.wim to install.
variable "win_inst_os_image" {
  type    = string
  default = "Windows Server 2022 SERVERSTANDARD"
}

variable "win_inst_os_language" {
  type    = string
  default = "en-US"
}

variable "win_inst_os_keyboard" {
  type    = string
  default = "0x00000409"
}

variable "win_guest_os_timezone" {
  type    = string
  default = "Eastern Standard Time"
}

# ---------------------------------------------------------------------------
# Alternative: download the ISO instead of using a datastore path.
# Uncomment this block, comment `iso_paths` in the source below, and add
# `iso_urls = [var.iso_url]` / `iso_checksum = var.iso_checksum` instead.
# (Windows evaluation ISOs are behind a Microsoft NDA link — a datastore
# upload is the normal path.)
#
# variable "iso_url" {
#   type    = string
#   default = "https://download.example.com/Windows-Server-2022.iso"
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

source "vsphere-iso" "windows" {
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
  vm_name       = "${var.win_vm_name}-v${formatdate("YYYYMMDD-hhmm", timestamp())}"
  guest_os_type = var.win_guest_os_type

  # BIOS firmware: boots on any ESXi host without vTPM. UEFI + vTPM are
  # only mandatory for Server 2025 (see header note).
  firmware             = "bios"
  CPUs                 = var.win_cpus
  RAM                  = var.win_memory
  disk_controller_type = ["pvscsi"]

  storage {
    disk_size             = 81920 # MiB (80 GiB — Windows needs room for updates)
    disk_thin_provisioned = true
  }

  # Second entry: the built-in VMware Tools ISO served by vCenter (the
  # "[]" datastore-less form) — autounattend's pvscsi driver and
  # windows-vmtools.ps1 both read it from E:.
  iso_paths = [
    "/${var.vsphere_datacenter}/datastore/${var.vsphere_datastore}/${var.win_iso_path}",
    "[] /vmimages/tools-isoimages/windows.iso",
  ]

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  # The Windows ISO drops to "Press any key to boot from CD" — the spacebar
  # is the "any key" (reference repo's proven boot_command).
  boot_order = "disk,cdrom"
  boot_wait  = "10s"
  boot_command = [
    "<spacebar>",
  ]

  # autounattend.xml rides on a virtual CD (F:) alongside the helper
  # scripts, so Setup finds it at install-media root — no HTTP needed at
  # boot time. Rendered from http/autounattend.xml with var substitution.
  cd_files = ["scripts/windows/"]
  cd_content = {
    "autounattend.xml" = templatefile("http/autounattend-2022.xml", {
      build_username       = var.winrm_username
      build_password       = var.winrm_password
      vm_inst_os_language  = var.win_inst_os_language
      vm_inst_os_keyboard  = var.win_inst_os_keyboard
      vm_inst_os_image     = var.win_inst_os_image
      vm_inst_os_key       = var.win_inst_os_key
      vm_guest_os_timezone = var.win_guest_os_timezone
    })
  }

  communicator     = "winrm"
  winrm_username   = var.winrm_username
  winrm_password   = var.winrm_password
  winrm_port       = 5985
  winrm_insecure   = true
  winrm_use_ntlm   = true
  winrm_timeout    = "1h"
  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Shutdown by Packer\""

  # The whole point: turn the built VM into a vSphere template.
  # (Plugin v2.x argument name: convert_to_template.)
  convert_to_template = true
  create_snapshot     = false
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name = "windows-server-2022-golden"

  sources = ["source.vsphere-iso.windows"]

  # In-guest hygiene over the WinRM communicator. Kept as inline
  # powershell — running the Ansible playbook from Packer over WinRM
  # works but needs pywinrm + collections on the build host and env-var
  # credential plumbing; see ansible/windows-playbook.yml for the Ansible
  # version, and the commented block below for how to wire it in.
  provisioner "powershell" {
    inline = [
      "Set-TimeZone -Id '${var.win_guest_os_timezone}'",
      "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", # High performance
      "wevtutil el | ForEach-Object { wevtutil cl $_ }",          # clear event logs (template hygiene)
    ]
  }

  # Optional: drive provisioning with Ansible instead (requires
  # `pip install --user pywinrm` and `ansible-galaxy collection install
  # -r ../requirements.yml` on the build host). Uncomment to use.
  #
  # provisioner "ansible" {
  #   user          = var.winrm_username
  #   use_proxy     = false
  #   playbook_file = "ansible/windows-playbook.yml"
  #   extra_arguments = [
  #     "--extra-vars", "ansible_connection=winrm",
  #     "--extra-vars", "ansible_user='${var.winrm_username}'",
  #     "--extra-vars", "ansible_password='${var.winrm_password}'",
  #     "--extra-vars", "ansible_port=5985",
  #     "--extra-vars", "ansible_winrm_transport=ntlm",
  #     "--extra-vars", "ansible_winrm_server_cert_validation=ignore",
  #   ]
  # }
}
