terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere" # moved from hashicorp/vsphere — maintained by VMware by Broadcom
      version = "~> 2.17"
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.vsphere_endpoint
  user                 = var.vsphere_username
  password             = var.vsphere_password
  allow_unverified_ssl = true # self-signed vCenter cert — replace with a real CA in production
}
