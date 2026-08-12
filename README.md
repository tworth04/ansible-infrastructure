# Ansible Infrastructure Automation

Production Ansible playbooks and roles for enterprise Linux infrastructure
management — RHEL 5-10, VMware vSphere, Zabbix monitoring, and GCP compute.

## Playbooks

| Playbook | Purpose |
|----------|---------|
| `deploy.yml` | Server deployment and configuration |
| `all_servers.yml` | Fleet-wide configuration management |
| `cis_audit.yml` | CIS benchmark compliance auditing |
| `secure_boot.yaml` | Secure boot configuration |
| `lv_extend.yml` | LVM volume extension automation |
| `add_storage.yml` | Storage provisioning (datastores, LUNs) |
| `bluecat.yml` | BlueCat DNS/IPAM management |
| `awx-deploy.yml` | AWX (Ansible Automation Platform) deployment |
| `ssh_deploy.yml` | SSH key deployment across fleet |
| `zabbix` role | Zabbix agent deployment and configuration |

## Roles

- **zabbix** — Zabbix agent2 installation, config, and RHEL 8/9 patching
- **vmware_create** — VMware VM provisioning via vSphere API
- **sssd** — SSSD/AD integration configuration

## Inventory

Dynamic inventory via:
- VMware vSphere (`community.vmware.vmware_vm_inventory`)
- GCP Compute (`gcp_compute`)
- Custom vSphere Python script (`dynamic.py`)

## Structure

```
├── *.yml              # Playbooks
├── roles/             # Ansible roles
├── group_vars/        # Environment variables (dev/prod)
├── inventory/         # Dynamic inventory configs
├── templates/         # Jinja2 templates
└── ansible.cfg        # Ansible configuration
```

## Notes

- Credentials managed via Ansible Vault (`vault_*` variables)
- Inventory files scrubbed of company-specific hostnames/IPs
- Designed for RHEL 5-10 + VMware vSphere 6.x-8.x environments
