# terraform/ — VM provisioning from golden templates

The Terraform half of the Packer → Terraform → Ansible pipeline. **Additive** —
the existing `vmware_create` role keeps working; nothing here modifies or
deprecates it.

## What it does

Provisions VMs by cloning the golden template built by `../packer/` (or any
existing template), with static IP customization, into the dev cluster. VMs are
declared in `vms.tf` as a map — one entry per VM, `for_each` in the `vms` module.

## Layout

- `main.tf` — provider (vmware/vsphere), variables
- `vms.tf` — the VM request map (edit this to add VMs)
- `modules/vm/` — one VM = data sources (dc/cluster/datastore/network/template) +
  `vsphere_virtual_machine` resource with guest customization
- `variables.tf` — env-level defaults (datacenter, cluster, datastore, dvPG, IPs)

## Usage

```bash
cd terraform
terraform init          # downloads the vmware/vsphere provider
cp terraform.tfvars.example terraform.tfvars   # fill real values, never commit
terraform plan          # review the diff BEFORE any vCenter change
terraform apply         # clone + customize + wait for guest net
terraform destroy       # clean teardown of what this root created
```

Secrets: `TF_VAR_vsphere_password` env var or gitignored `terraform.tfvars`.
State is local (`terraform.tfstate`, gitignored) — fine for a single operator;
move to remote state (GitLab/TFC/S3) before sharing.

## Conventions

- **Terraform creates/destroys VMs. Ansible configures them.** Day-2 (satellite
  registration, sssd, agents, LVM, patching) stays in `../roles/`.
- `lifecycle.ignore_changes` on `annotation`/`disks` keeps other teams' click-ops
  from showing as drift.
- IPs: reserve in Bluecat first, then reference here — replaces the nmap
  scan-for-free-IPs approach in `roles/vmware_create/tasks/assign_ip.yml`.
- Hand-off to Ansible: `terraform output` gives VM names/IPs — feed to inventory
  (`../dynamic.py`, `../inventory/`).

## Drift / ownership boundary

Terraform owns: existence, name, folder, CPU/RAM, template clone, NIC + IP.
vCenter/other teams own (ignored): annotations, vmotion location, hot-add disks.
Ansible owns: everything inside the guest.

## Windows deployments

Windows VMs ride alongside the Linux fleet without touching `vms.tf`. Two
golden-image editions are supported — Server **2022** (BIOS) and Server
**2025** (EFI + Secure Boot + vTPM; requires vSphere 8+ hosts and a cluster
TPM provisioning policy that escrows vTPM keys). Terraform needs no
per-edition plumbing: guest customization sets computer name + admin
password on every clone, so a 2025 VM only needs its `template` key.

- `modules/vm-windows/` — like `modules/vm` but clones the Windows template
  and uses `customize { windows_options { ... } }`: per-VM `computer_name`
  and a fresh `admin_password` (sensitive) on every clone, which supersedes
  the build-time password baked into the Packer template. `vmxnet3` NIC
  (the template ships VMware Tools + driver). Optional domain join inputs
  (`join_domain` / `domain_user` / `domain_password`) are commented.
- `windows_vms.tf` — the Windows request map (`local.win_vms`, commented
  2022 + 2025 example entries) → `module "windows_vms"`. A per-entry
  `template = "windows-2025-minimal"` overrides `win_template_name` for
  that VM (`lookup(each.value, "template", var.win_template_name)`).
- `windows-variables.tf` — Windows-only vars: `win_template_name`
  (default `windows-2022-minimal`), `win_admin_password` (sensitive, no
  default — `TF_VAR_win_admin_password` or gitignored tfvars), and
  `win_vsphere_datastore` / `win_vsphere_network` / `win_vsphere_folder`
  defaults mirroring the Linux ones.

```bash
export TF_VAR_win_admin_password='***'   # per-apply, never committed
terraform plan  # after adding an entry to local.win_vms in windows_vms.tf
```

Day-2 configuration is Ansible over WinRM: see
`../inventory/windows-example.yml` (example-grade WinRM inventory) and
`../playbooks/windows_baseline.yml` (timezone, power plan, update scan).
Control node needs `pywinrm` + the collections in `../requirements.yml`.
