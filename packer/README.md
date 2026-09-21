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
