# Packer — Rocky Linux 9.5 vSphere golden image

This pipeline builds a minimal Rocky Linux 9.5 VM on vSphere from ISO +
kickstart, provisions and hardens it with Ansible, and converts the result
into a **vSphere template** named `rocky-95-minimal-v<YYYYMMDD-hhmm>` in the
`Templates/Packer` folder. Each build is date/time-stamped so successive
builds coexist and you can roll a fleet back to an older template.

## Layout

```
packer/
├── rocky-95.pkr.hcl               # pipeline: vars, vsphere-iso source, build
├── rocky-95.pkrvars.hcl.example   # sanitized sample vars (copy, don't commit)
├── http/
│   └── rocky-9.ks                 # kickstart served over HTTP during boot
└── ansible/
    └── playbook.yml               # provisioning + template hygiene
```

## Prerequisites

- Packer ≥ 1.9 on the machine that runs the build.
- The vmware/vsphere plugin: `packer init .` (run inside this directory).
- `Rocky-9.5-x86_64-minimal.iso` uploaded to the target datastore at
  `ISOs/Rocky-9.5-x86_64-minimal.iso` (or use the commented `iso_url` /
  `iso_checksum` block in the template to download it instead).
- Network reachability from the build host to vCenter, and from the temporary
  build VM back to the build host's HTTP server (kickstart fetch + SSH).
- Verify `guest_os_type` (`rockyLinux9_64Guest`) exists on your vCenter
  version; older builds may need `rhel9_64Guest`.

## Credentials — never commit them

Secrets are **not** defaulted in the template. Supply them at build time,
preferably via environment variables:

```sh
export PKR_VAR_vsphere_password='...'
export PKR_VAR_ssh_password='...'          # temporary build-VM password
```

or copy `rocky-95.pkrvars.hcl.example` to `rocky-95.pkrvars.hcl` (keep it
gitignored). The `ssh_password` only authenticates the throwaway `packer`
user created by the kickstart; the playbook deletes that user before the
VM becomes a template.

## Build

```sh
cd packer
packer init .
packer build -var-file=rocky-95.pkrvars.hcl .
```

Do **not** commit the var file if it contains real values.

## Artifact

A vSphere **template** (the builder sets `convert_to_template = true`) named
`rocky-95-minimal-v<timestamp>`, thin-provisioned, 2 vCPU / 4 GiB / ~6 GiB
disk, with:

- machine-id truncated and SSH host keys removed (regenerated on first boot),
- dnf caches and logs cleaned,
- open-vm-tools installed, sshd + firewalld enabled.

## How this fits the repo

1. **Packer (here)** builds the golden template from ISO → hardened template.
2. **`terraform/`** clones production VMs from that template — no ISO
   handling, no kickstart, minutes per VM.
3. **Existing Ansible roles** (`../roles`, wired in via `--roles-path`) do
   day-2 configuration (cis, lvm, bigfix, …) against the cloned VMs; the
   same roles can be layered into `ansible/playbook.yml` at bake time.

## Windows deployments

`windows-server.pkr.hcl` (Server **2022**) and `windows-server-2025.pkr.hcl`
(Server **2025**) build Windows golden images the same way
`rocky-95.pkr.hcl` builds Linux: ISO + unattended install → WinRM →
hygiene → `convert_to_template = true` (templates
`windows-2022-minimal-v<YYYYMMDD-hhmm>` / `windows-2025-minimal-v<...>` in
`Templates/Packer`).

```
packer/
├── windows-server.pkr.hcl                # vsphere-iso Windows Server 2022 builder
├── windows-server.pkrvars.hcl.example    # sanitized sample vars (copy, don't commit)
├── windows-server-2025.pkr.hcl           # Server 2025 builder (EFI+SecureBoot+vTPM)
├── windows-server-2025.pkrvars.hcl.example
├── http/
│   ├── autounattend-2022.xml             # answer file (rendered onto a virtual CD)
│   └── autounattend-2025.xml             # 2025 variant (bigger RE partition, image name)
├── scripts/windows/
│   ├── windows-vmtools.ps1               # FirstLogon: install VMware Tools
│   └── windows-init.ps1                  # FirstLogon: enable WinRM + firewall
└── ansible/
    └── windows-playbook.yml              # optional Ansible hygiene over WinRM
```

How it works (cribbed from [vmware/packer-examples-for-vsphere](https://github.com/vmware/packer-examples-for-vsphere),
BSD-2-Clause — see header comments in `http/autounattend.xml` and
`scripts/windows/*.ps1`):

- `autounattend.xml` is rendered with `templatefile()` into `cd_content`
  (a virtual CD), together with the two PowerShell helpers via `cd_files`.
  No HTTP boot fetch is involved, unlike the kickstart path.
- First boot: Setup partitions UEFI-style/BIOS, installs
  `Windows Server 2022 SERVERSTANDARD`, then FirstLogonCommands set the
  execution policy, install **VMware Tools** from the auto-mounted Tools ISO
  (`[] /vmimages/tools-isoimages/windows.iso` — also the pvscsi driver
  source), and enable **WinRM** (HTTP 5985, basic+NTLM, unencrypted — build
  VM on a trusted port group only).
- `communicator = "winrm"` (Administrator / `winrm_password`), inline
  `powershell` hygiene; the Ansible alternative is commented in the build.

### Credentials

```sh
export PKR_VAR_vsphere_password='...'
export PKR_VAR_winrm_password='***'   # BUILD-TIME-ONLY Administrator password
cd packer
packer init .
packer build -only='windows-server-2022-golden.*' -var-file=windows-server.pkrvars.hcl .
```

The build password becomes the template's local Administrator password.
Terraform's `modules/vm-windows` sets a **fresh per-VM admin password via
guest customization on every clone** — never use the build password on a
deployed VM, and never commit it.

### Windows Server 2025

Server 2025 lives in its own template: **`windows-server-2025.pkr.hcl`** +
**`http/autounattend-2025.xml`** + `windows-server-2025.pkrvars.hcl.example`
(mirrors the reference repo's per-OS file layout; the 2022 pipeline is
untouched). Differences from 2022, cribbed from the reference repo's
`builds/windows/server/2025` and verified against plugin v2.5.0:

- `firmware = "efi-secure"` — UEFI + Secure Boot are install-time
  requirements for the 2025 ISO.
- `vbs_enabled = true` (+ `vvtd_enabled = true`, `NestedHV = true`, which
  plugin v2.5.0 forces alongside it) — attaches a vTPM +
  virtualization-based security (actual field names in vmware/vsphere
  plugin v2.5.0; the plugin rejects `vbs_enabled` unless firmware is
  `efi-secure`). The cluster's **TPM
  provisioning policy** must allow vTPM key escrow/backup, or VMs become
  unrecoverable after host maintenance.
- **vSphere 8+ hosts required** (ESXi 7 does not support the 2025 guest
  family).
- Guest ID `windows2022srvNext_64Guest` (vSphere's ID for the 2025 family,
  per the reference repo — counterintuitive, don't "fix" it).
- Image name `Windows Server 2025 SERVERSTANDARD` and a larger (800 MB)
  WinRE partition in the 2025 answer file.

Both templates validate in one directory: shared `vsphere_*`/`winrm_*`
variables and `required_plugins` are declared once (rocky-95.pkr.hcl +
windows-server.pkr.hcl scope); 2025-only vars are `win25_`-prefixed. Build
one edition with `-only`:

```sh
packer build -only='windows-server-2025-golden.*' -var-file=windows-server-2025.pkrvars.hcl .
```

### Control-node requirements

`pip install --user pywinrm` plus `ansible-galaxy collection install -r
../requirements.yml -p ~/.ansible/collections` (ansible.windows,
community.windows, microsoft.ad) before running the Windows playbooks or the
commented Ansible-from-Packer provisioner.
