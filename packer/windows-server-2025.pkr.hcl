# Windows Server 2025 golden-image pipeline for vSphere.
# Sibling of windows-server.pkr.hcl (2022) — same pipeline, 2025-specific
# firmware/guest-id/answer file. Layout mirrors the reference repo's
# per-OS directory structure (builds/windows/server/2022 + /2025).
#
# Structure cribbed from vmware/packer-examples-for-vsphere
# (github.com/vmware/packer-examples-for-vsphere, BSD-2-Clause) —
# builds/windows/server/2025. Trimmed to one Standard/Desktop build.
#
# Windows Server 2025 hard requirements (vs. 2022):
#   - EFI firmware + Secure Boot  -> firmware = "efi-secure" (below)
#   - ESXi 8 / vSphere 8+ hosts (2025 guest family unsupported on 7.x)
#   - vTPM is NOT required to install, but recommended: our vmware/vsphere
#     plugin v2.5.0 exposes `vbs_enabled = true` to attach a vTPM + enable
#     virtualization-based security (the plugin rejects it unless
#     firmware = "efi-secure", and it also forces `vvtd_enabled = true` and
#     `nested_hv_enabled = true` (exact plugin arg name) — all three set below). The cluster's TPM
#     provisioning policy must allow key escrow/backup for vTPMs, or the VM
#     can become unrecoverable after host maintenance.
#
# required_plugins + the vsphere_* environment variables are declared once
# in rocky-95.pkr.hcl — Packer shares one plugin/variable scope per
# directory, so nothing global is redeclared here. VM-shape variables are
# win25_-prefixed so both editions can live side by side in this directory.

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "win25_vm_name" {
  type    = string
  default = "windows-2025-minimal"
}

# Guest ID for Server 2025 taken from the reference repo's 2025
# pkrvars (windows2022srvNext_64Guest is vSphere's ID for the 2025 guest
# family). Verify against your vCenter version.
variable "win25_guest_os_type" {
  type    = string
  default = "windows2022srvNext_64Guest"
}

variable "win25_cpus" {
  type    = number
  default = 2
}

variable "win25_memory" {
  type    = number
  default = 4096
}

# Sensitive credentials are SHARED with the 2022 template (same directory
# scope): winrm_username / winrm_password — the build-time-only
# Administrator password. Rotation story: Terraform guest customization
# sets a fresh per-VM admin password on every clone.

variable "win25_iso_path" {
  type    = string
  default = "ISOs/Windows-Server-2025.iso"
}

# Eval ISO needs no key; set for retail/vl media (referenced by the
# commented ProductKey block in http/autounattend-2025.xml).
variable "win25_inst_os_key" {
  type    = string
  default = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
}

# Image name inside the 2025 install.wim — edition name changed from 2022.
variable "win25_inst_os_image" {
  type    = string
  default = "Windows Server 2025 SERVERSTANDARD"
}

variable "win25_inst_os_language" {
  type    = string
  default = "en-US"
}

variable "win25_inst_os_keyboard" {
  type    = string
  default = "0x00000409"
}

variable "win25_guest_os_timezone" {
  type    = string
  default = "Eastern Standard Time"
}

# Attach a vTPM (+ virtualization-based security). Plugin v2.5.0 requires
# firmware efi-secure when this is true (verified against the plugin
# binary). Keep true for the 2025 golden image.
variable "win25_vbs_enabled" {
  type    = bool
  default = true
}

# ---------------------------------------------------------------------------
# Alternative: download the ISO instead of using a datastore path.
# Same commented pattern as windows-server.pkr.hcl / rocky-95.pkr.hcl.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

source "vsphere-iso" "windows-2025" {
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
  vm_name       = "${var.win25_vm_name}"
  guest_os_type = var.win25_guest_os_type

  # Server 2025: UEFI + Secure Boot mandatory ("efi-secure" = EFI + secure
  # boot in plugin arg space). vbs_enabled adds the vTPM device and — per
  # plugin v2.5.0 validation — requires vvtd_enabled + NestedHV=true.
  firmware             = "efi-secure"
  vbs_enabled          = var.win25_vbs_enabled
  vvtd_enabled         = var.win25_vbs_enabled
  NestedHV             = var.win25_vbs_enabled
  CPUs                 = var.win25_cpus
  RAM                  = var.win25_memory
  disk_controller_type = ["pvscsi"]

  storage {
    disk_size             = 81920 # MiB (80 GiB — Windows needs room for updates)
    disk_thin_provisioned = true
  }

  # Second entry: the built-in VMware Tools ISO served by vCenter (the
  # "[]" datastore-less form) — autounattend's pvscsi driver and
  # windows-vmtools.ps1 both read it from E:.
  iso_paths = [
    "/${var.vsphere_datacenter}/datastore/${var.vsphere_datastore}/${var.win25_iso_path}",
    "[] /vmimages/tools-isoimages/windows.iso",
  ]

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  # The Windows ISO drops to "Press any key to boot from CD" — the spacebar
  # is the "any key" (reference repo's proven boot_command).
  boot_order = "disk,cdrom"
  boot_wait  = "30s"
  boot_command = [
    "<spacebar>",
  ]

  # autounattend.xml rides on a virtual CD (F:) alongside the helper
  # scripts, so Setup finds it at install-media root — no HTTP needed at
  # boot time. Rendered from http/autounattend-2025.xml with var
  # substitution (2025 answer file: larger RE partition, 2025 image name).
  cd_files = ["scripts/windows/"]
  cd_content = {
    "autounattend.xml" = templatefile("http/autounattend-2025.xml", {
      build_username       = var.winrm_username
      build_password       = var.winrm_password
      vm_inst_os_language  = var.win25_inst_os_language
      vm_inst_os_keyboard  = var.win25_inst_os_keyboard
      vm_inst_os_image     = var.win25_inst_os_image
      vm_inst_os_key       = var.win25_inst_os_key
      vm_guest_os_timezone = var.win25_guest_os_timezone
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
  name = "windows-server-2025-golden"

  sources = ["source.vsphere-iso.windows-2025"]

  # In-guest hygiene over the WinRM communicator — identical to the 2022
  # build; the Ansible alternative is commented in windows-server.pkr.hcl.
  provisioner "powershell" {
    inline = [
      "Set-TimeZone -Id '${var.win25_guest_os_timezone}'",
      "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", # High performance
      "wevtutil el | ForEach-Object { wevtutil cl $_ }",          # clear event logs (template hygiene)
    ]
  }
}
