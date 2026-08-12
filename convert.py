import yaml
import configparser

def read_vsphere_inventory(yaml_file):
    with open(yaml_file, 'r') as file:
        inventory_data = yaml.safe_load(file)
    
    return inventory_data

def filter_vms_by_os(vms, os_names):
    filtered_vms = {}
    for host_name, host_info in vms.items():
        if host_info.get('guest.guestFullName'):
            for os_name in os_names:
                if os_name.lower() in host_info['gust.guestFullName'].lower():
                    if 'children' not in filtered_vms:
                        filtered_vms['children'] = []
                    filtered_vms['children'].append(host_name)
                    break
    return filtered_vms

def create_ini_file(filtered_vms, ini_file):
    config = configparser.ConfigParser()
    
    for group_name, hosts in filtered_vms.items():
        if isinstance(hosts, list):
            config[group_name] = {'hosts': ', '.join(hosts)}
        else:
            config[group_name] = {group_name: 'host_group'}
    
    with open(ini_file, 'w') as file:
        config.write(file)

if __name__ == "__main__":
    yaml_inventory_file = '/etc/ansible/inventory.yml'  # Path to your inventory.yml file
    ini_output_file = 'output.ini'         # Output INI file

    #os_names_to_filter = ['Rocky', 'Red Hat']  # List of OS names to filter by
    os_names_to_filter = ['Linux']  # List of OS names to filter by

    vms = read_vsphere_inventory(yaml_inventory_file)
    filtered_vms = filter_vms_by_os(vms, os_names_to_filter)
    create_ini_file(filtered_vms, ini_output_file)

    print(f"INI file created at {ini_output_file}")
