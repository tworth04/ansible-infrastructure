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
