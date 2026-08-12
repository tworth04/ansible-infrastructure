import os
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import ssl
import configparser

# Function to connect to vSphere
def connect_to_vsphere(host, user, password):
    context = ssl._create_unverified_context()
    si = SmartConnect(host=host, user=user, pwd=password, sslContext=context)
    return si

# Function to get VMs with specific guestFullName attributes
def get_filtered_vms(content, filter_list):
    vm_list = []
    for child in content.viewManager.CreateContainerView(content.rootFolder, [vim.VirtualMachine], True):
        if child.config.guestFullName and any(filter_str.lower() in child.config.guestFullName.lower() for filter_str in filter_list):
            vm_list.append(child)
    return vm_list

# Function to create INI file from VMs
def create_ini_file(vms, output_file):
    config = configparser.ConfigParser()
    
    for vm in vms:
        os_name = vm.config.guestFullName if vm.config.guestFullName else 'Other'
        if not config.has_section(os_name):
            config.add_section(os_name)
        
        config.set(os_name, vm.name, vm.runtime.host.name)
    
    with open(output_file, 'w') as f:
        config.write(f)

# Main script
if __name__ == "__main__":
    vcenter_host = os.environ.get("VCENTER_HOST", "vcenter.example.com")
    username = os.environ.get("VCENTER_USER", "ansible-svc@vsphere.local")
    password = os.environ.get("VCENTER_PASSWORD")
    if not password:
        raise ValueError("VCENTER_PASSWORD environment variable is required")
    output_ini_file = "vsphere_inventory.ini"

    filter_list = ['Rocky', 'Red Hat']

    # Connect to vSphere
    si = connect_to_vsphere(vcenter_host, username, password)
    content = si.RetrieveContent()

    # Get filtered VMs
    vms = get_filtered_vms(content, filter_list)

    # Create INI file
    create_ini_file(vms, output_ini_file)

    # Disconnect from vSphere
    Disconnect(si)

    print(f"INI file created: {output_ini_file}")
