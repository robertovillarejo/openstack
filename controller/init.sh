#!/bin/bash

echo '
export PS1="\[\e[01;34m\]controller\[\e[0m\]\[\e[01;37m\]:\w\[\e[0m\]\[\e[00;37m\]\n\\$ \[\e[0m\]"
' >> /home/ubuntu/.bashrc

## Configure name resolution
sed -i "2i10.0.0.11       controller" /etc/hosts
sed -i "2i10.0.0.31       compute" /etc/hosts
sed -i "2i10.0.0.41       block" /etc/hosts
sed -i "2i10.0.0.51       object1" /etc/hosts
sed -i "2i10.0.0.52       object2" /etc/hosts

## Configure NTP server (client)
apt install -y chrony
sed -i '/# NTP server./a server cronos.cenam.mx iburst' /etc/chrony/chrony.conf
sed -i '/#allow ::/a allow 10.0.0.0/24' /etc/chrony/chrony.conf
service chrony restart

## Install Open Stack repository
apt install -y software-properties-common
add-apt-repository cloud-archive:ocata -y
apt update && apt dist-upgrade -y
apt install -y python-openstackclient

## Database installation
apt install -y mariadb-server python-pymysql

echo '[mysqld]
bind-address = 10.0.0.11

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8' > /etc/mysql/mariadb.conf.d/99-openstack.cnf

service mysql restart
##mysql_secure_installation

## Install rabbitmqctl
apt install -y rabbitmq-server
rabbitmqctl add_user openstack openstack_pass
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

## Install memchached
apt install -y memcached python-memcache
sed -i '/-l 127.0.0.1/c -l 10.0.0.11' /etc/memcached.conf
service memcached restart

## Install keystone

mysql --execute="CREATE DATABASE keystone;"
mysql --execute="GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'keystone';"
mysql --execute="GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystone';"

apt install -y keystone

## Modify the the file: /etc/keystone/keystone.conf
sed -i '/\#connection = <None>/c connection = mysql+pymysql://keystone:keystone@controller/keystone' /etc/keystone/keystone.conf
sed -i "2842s/\#provider = fernet/provider = fernet/g" /etc/keystone/keystone.conf

## Populate de identity service database
/bin/sh -c "keystone-manage db_sync" keystone

## Adding repositories
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password keystone \
--bootstrap-admin-url http://controller:35357/v3/ \
--bootstrap-internal-url http://controller:5000/v3/ \
--bootstrap-public-url http://controller:5000/v3/ \
--bootstrap-region-id RegionOne

## Configure the HTTP SERVER

sed -i -e 's/#ServerName www.example.com/ServerName controller/g' /etc/apache2/sites-enabled/000-default.conf
service apache2 restart
rm -f /var/lib/keystone/keystone.db

## Configure administration account

echo 'export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=keystone
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2' > /etc/profile.d/admin-openrc.sh

## Configure demo account

echo 'export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=demo
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2' > /etc/profile.d/demo-openrc.sh


source /etc/profile.d/admin-openrc.sh

# Create domain, projects, users and roles

## Create the Service Project
openstack project create --domain default --description "Service Project" service

## Create Demo Project

openstack project create --domain default --description "Demo Project" demo

## Create Demo User

openstack user create --domain default --password demo demo

## Create User rol

openstack role create user

## Add the user role to the demo project and user

openstack role add --project demo --user demo user

## As admin Request an authentication token:

openstack --os-auth-url http://controller:35357/v3 \
--os-project-domain-name default --os-user-domain-name default \
--os-project-name admin --os-username admin token issue

## As demo user Request an authentiction token:

source /etc/profile.d/demo-openrc.sh

openstack --os-auth-url http://controller:5000/v3 \
--os-project-domain-name default --os-user-domain-name default \
--os-project-name demo --os-username demo token issue


## Install Glance (Image Service)

mysql --execute="CREATE DATABASE glance;"
mysql --execute="GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'glance';"
mysql --execute="GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'glance';"

source /etc/profile.d/admin-openrc.sh

openstack user create --domain default --password glance glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292


apt install -y glance
##/etc/glance/glance-api.conf
#[database]
sed -i '/\#connection = <None>/c connection = mysql+pymysql://glance:glance@controller/glance' /etc/glance/glance-api.conf
#[keystone_authtoken]
sed -i '/\#auth_uri = <None>/c auth_uri = http:\/\/controller:5000' /etc/glance/glance-api.conf
sed -i "3296i auth_url = http:\/\/controller:35357" /etc/glance/glance-api.conf
##sed -i '/\#auth_url = <None>/c auth_url = http://controller:35357' /etc/glance/glance-api.conf
sed -i '/\#memcached_servers = <None>/c memcached_servers = controller:11211' /etc/glance/glance-api.conf
sed -i '/\#auth_type = <None>/c auth_type = password' /etc/glance/glance-api.conf
sed -i "3450i project_domain_name  = default" /etc/glance/glance-api.conf
sed -i "3450i user_domain_name  = default" /etc/glance/glance-api.conf
sed -i "3450i project_name  = service" /etc/glance/glance-api.conf
sed -i "3450i username  = glance" /etc/glance/glance-api.conf
sed -i "3450i password  = glance" /etc/glance/glance-api.conf
#[paste_deploy]
sed -i '/\#flavor = keystone/c flavor = keystone' /etc/glance/glance-api.conf
#[glance_store]
sed -i '/\#stores = file,http/c stores = file,http' /etc/glance/glance-api.conf
sed -i '/\#default_store = file/c default_store = file' /etc/glance/glance-api.conf
sed -i "2294i filesystem_store_datadir = /var/lib/glance/images" /etc/glance/glance-api.conf

#/etc/glance/glance-registry.conf
#[database]
sed -i '/\#connection = <None>/c connection = mysql+pymysql://glance:glance@controller/glance' /etc/glance/glance-registry.conf
#[keystone_authtoken]
sed -i '/\#auth_uri = <None>/c auth_uri = http:\/\/controller:5000' /etc/glance/glance-registry.conf
sed -i "1219i auth_url = http:\/\/controller:35357" /etc/glance/glance-registry.conf
##sed -i '/\#auth_url = <None>/c auth_url = http:\/\/controller:35357' /etc/glance/glance-registry.conf
sed -i '/\#memcached_servers = <None>/c memcached_servers = controller:11211' /etc/glance/glance-registry.conf
sed -i '/\#auth_type = <None>/c auth_type = password' /etc/glance/glance-registry.conf
sed -i "1373i project_domain_name  = default" /etc/glance/glance-registry.conf
sed -i "1373i user_domain_name  = default" /etc/glance/glance-registry.conf
sed -i "1373i project_name  = service" /etc/glance/glance-registry.conf
sed -i "1373i username  = glance" /etc/glance/glance-registry.conf
sed -i "1373i password  = glance" /etc/glance/glance-registry.conf
#[paste_deploy]
sed -i '/\#flavor = keystone/c flavor = keystone' /etc/glance/glance-registry.conf

## Populate the image service database
/bin/sh -c "glance-manage db_sync" glance

service glance-registry restart
service glance-api restart

## Verify operation
source /etc/profile.d/admin-openrc.sh
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

## Compute service installation
mysql --execute="CREATE DATABASE nova_api;"
mysql --execute="CREATE DATABASE nova;"
mysql --execute="CREATE DATABASE nova_cell0;"

mysql --execute="GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'nova';"
mysql --execute="GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'nova';"
mysql --execute="GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'nova';"
mysql --execute="GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'nova';"
mysql --execute="GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'nova';"
mysql --execute="GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'nova';"

source /etc/profile.d/admin-openrc.sh
openstack user create --domain default --password nova nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1

openstack user create --domain default --password placement placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://controller:8778
openstack endpoint create --region RegionOne placement internal http://controller:8778
openstack endpoint create --region RegionOne placement admin http://controller:8778
apt install -y nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api

##/etc/nova/nova.conf
##[api_database]
sed -i "s|connection=sqlite:////var/lib/nova/nova.sqlite|connection=mysql+pymysql://nova:nova@controller/nova_api|" /etc/nova/nova.conf
##[database]
sed -i '/\#connection=<None>/c connection=mysql+pymysql://nova:nova@controller/nova' /etc/nova/nova.conf
##[DEFAULT]
sed -i '/\#transport_url=<None>/c transport_url=rabbit://openstack:openstack_pass@controller' /etc/nova/nova.conf
##[api]
sed -i '/\#auth_strategy=keystone/c auth_strategy=keystone' /etc/nova/nova.conf
##[keystone_authtoken]
sed -i '/\#auth_uri=<None>/c auth_uri=http:\/\/controller:5000' /etc/nova/nova.conf
sed -i "5610i auth_url  = http:\/\/controller:35357" /etc/nova/nova.conf
sed -i '/\#memcached_servers=<None>/c memcached_servers=controller:11211' /etc/nova/nova.conf
sed -i "5802i auth_type  = password" /etc/nova/nova.conf
sed -i "5806i project_domain_name = default" /etc/nova/nova.conf
sed -i "5806i user_domain_name = default" /etc/nova/nova.conf
sed -i "5806i project_name = service" /etc/nova/nova.conf
sed -i "5806i username = nova" /etc/nova/nova.conf
sed -i "5806i password = nova" /etc/nova/nova.conf
##[DEFAULT]
sed -i '/\#my_ip=10.222.99.93/c my_ip=10.0.0.11' /etc/nova/nova.conf
sed -i '/\#use_neutron=true/c use_neutron=True' /etc/nova/nova.conf
sed -i '/\#firewall_driver=<None>/c firewall_driver=nova.virt.firewall.NoopFirewallDriver' /etc/nova/nova.conf
##[vnc]
sed -i '/\#enabled=true/c enabled=true' /etc/nova/nova.conf
sed -i '/\#vncserver_listen=127.0.0.1/c vncserver_listen=$my_ip' /etc/nova/nova.conf
sed -i '/\#vncserver_proxyclient_address=127.0.0.1/c vncserver_proxyclient_address=$my_ip' /etc/nova/nova.conf
##[glance]
sed -i '/\#api_servers=<None>/c api_servers=http:\/\/controller:9292' /etc/nova/nova.conf
##[oslo_concurrency]
sed -i "s|lock_path=/var/lock/nova|lock_path=/var/lib/nova/tmp|" /etc/nova/nova.conf
sed -i "s|log_dir=/var/log/nova|#log_dir=/var/log/nova|" /etc/nova/nova.conf
##[placement]
sed -i '/\os_region_name = openstack/c os_region_name = RegionOne' /etc/nova/nova.conf
sed -i "8180i project_domain_name = Default" /etc/nova/nova.conf
sed -i "8174i project_name = service" /etc/nova/nova.conf
sed -i "8156i auth_type = password" /etc/nova/nova.conf
sed -i "8206i user_domain_name = Default" /etc/nova/nova.conf
sed -i "8162i auth_url = http:\/\/controller:35357\/v3" /etc/nova/nova.conf
sed -i "8200i username = placement" /etc/nova/nova.conf
sed -i "8209i password = placement" /etc/nova/nova.conf

## Populating the nova databases
/bin/sh -c "nova-manage api_db sync" nova
/bin/sh -c "nova-manage cell_v2 map_cell0" nova
/bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
/bin/sh -c "nova-manage db sync" nova

##Verify nova cell0 and cell1 are registered correctly
nova-manage cell_v2 list_cells

service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

## Add the compute node to the cell database
source /etc/profile.d/admin-openrc.sh
openstack hypervisor list
## Discover compute hosts
/bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova

##Verify operation
source /etc/profile.d/admin-openrc.sh
openstack compute service list
openstack catalog list
openstack image list
nova-status upgrade check

##Neutron: Networking service
mysql --execute="CREATE DATABASE neutron;"
mysql --execute="GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'neutron';"
mysql --execute="GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutron';"

source /etc/profile.d/admin-openrc.sh
openstack user create --domain default --password neutron neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696

##Configure networking options
apt-get update
apt install -y neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent

##/etc/neutron/neutron.conf
##[database]
sed -i "s|connection = sqlite:////var/lib/neutron/neutron.sqlite|connection = mysql+pymysql://neutron:neutron@controller/neutron|" /etc/neutron/neutron.conf
##[DEFAULT]
sed -i '/\#service_plugins =/c service_plugins = router' /etc/neutron/neutron.conf
sed -i '/\#allow_overlapping_ips = false/c allow_overlapping_ips = true' /etc/neutron/neutron.conf
sed -i '/\#transport_url = <None>/c transport_url = rabbit://openstack:openstack_pass@controller' /etc/neutron/neutron.conf
sed -i '/\#auth_strategy = keystone/c auth_strategy = keystone' /etc/neutron/neutron.conf
##[keystone_authtoken]
sed -i '/\#auth_uri = <None>/c auth_uri = http:\/\/controller:5000' /etc/neutron/neutron.conf
sed -i "860i auth_url = http:\/\/controller:35357" /etc/neutron/neutron.conf
sed -i '/\#memcached_servers = <None>/c memcached_servers = controller:11211' /etc/neutron/neutron.conf
sed -i '/\#auth_type = <None>/c auth_type = password' /etc/neutron/neutron.conf
sed -i "1054i project_domain_name = default" /etc/neutron/neutron.conf
sed -i "1054i user_domain_name = default" /etc/neutron/neutron.conf
sed -i "1054i project_name = service" /etc/neutron/neutron.conf
sed -i "1054i username = neutron" /etc/neutron/neutron.conf
sed -i "1054i password = neutron" /etc/neutron/neutron.conf
##[DEFAULT]
sed -i '/\#notify_nova_on_port_status_changes = true/c notify_nova_on_port_status_changes = true' /etc/neutron/neutron.conf
sed -i '/\#notify_nova_on_port_data_changes = true/c notify_nova_on_port_data_changes = true' /etc/neutron/neutron.conf
##[nova]
sed -i '/\#auth_url = <None>/c auth_url = http:\/\/controller:35357' /etc/neutron/neutron.conf
##auth_type = password was set before in [keystone_authtoken]
sed -i '/\#project_domain_name = <None>/c project_domain_name = default' /etc/neutron/neutron.conf
sed -i '/\#user_domain_name = <None>/c user_domain_name = default' /etc/neutron/neutron.conf
sed -i "1111i region_name = RegionOne" /etc/neutron/neutron.conf
sed -i '/\#project_name = <None>/c project_name = service' /etc/neutron/neutron.conf
sed -i '/\#username = <None>/c username = nova' /etc/neutron/neutron.conf
sed -i '/\#password = <None>/c password = nova' /etc/neutron/neutron.conf

##/etc/neutron/plugins/ml2/ml2_conf.ini
##[ml2]
sed -i '/\#type_drivers = local,flat,vlan,gre,vxlan,geneve/c type_drivers = flat,vlan,vxlan' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i '/\#tenant_network_types = local/c tenant_network_types = vxlan' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i '/\#mechanism_drivers =/c mechanism_drivers = linuxbridge,l2population' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i '/\#extension_drivers =/c extension_drivers = port_security' /etc/neutron/plugins/ml2/ml2_conf.ini
##[ml2_type_flat]
sed -i '/\#flat_networks = */c flat_networks = provider' /etc/neutron/plugins/ml2/ml2_conf.ini
##[ml2_type_vxlan]
sed -i "224i vni_ranges = 1:1000" /etc/neutron/plugins/ml2/ml2_conf.ini
##[securitygroup]
sed -i '/\#enable_ipset = true/c enable_ipset = true' /etc/neutron/plugins/ml2/ml2_conf.ini

##/etc/neutron/plugins/ml2/linuxbridge_agent.ini
##[linux_bridge]
sed -i '/\#physical_interface_mappings =/c physical_interface_mappings = provider:enp0s8' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
##[vxlan]
sed -i '/\#enable_vxlan = true/c enable_vxlan = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#local_ip = <None>/c local_ip = 10.0.0.11' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#l2_population = false/c l2_population = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
##[securitygroup]
sed -i '/\#enable_security_group = true/c enable_security_group = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#firewall_driver = <None>/c firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' /etc/neutron/plugins/ml2/linuxbridge_agent.ini

##/etc/neutron/l3_agent.ini
##[DEFAULT]
sed -i '/\#interface_driver = <None>/c interface_driver = linuxbridge' /etc/neutron/l3_agent.ini

##/etc/neutron/dhcp_agent.ini
##[DEFAULT]
sed -i '/\#interface_driver = <None>/c interface_driver = linuxbridge' /etc/neutron/dhcp_agent.ini
sed -i '/\#dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq/c dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq' /etc/neutron/dhcp_agent.ini
sed -i '/\#enable_isolated_metadata = false/c enable_isolated_metadata = true' /etc/neutron/dhcp_agent.ini

##/etc/neutron/metadata_agent.ini
##[DEFAULT]
sed -i '/\#nova_metadata_ip = 127.0.0.1/c nova_metadata_ip = controller' /etc/neutron/metadata_agent.ini
sed -i '/\#metadata_proxy_shared_secret =/c metadata_proxy_shared_secret = openstack_pass' /etc/neutron/metadata_agent.ini

##/etc/nova/nova.conf
##[neutron]
sed -i "s|#url=http:\/\/127.0.0.1:9696|url = http:\/\/controller:9696|" /etc/nova/nova.conf
sed -i '/\#auth_url=<None>/c auth_url = http:\/\/controller:35357' /etc/nova/nova.conf
sed -i '/\#auth_type=<None>/c auth_type = password' /etc/nova/nova.conf
sed -i '/\#project_domain_name=<None>/c project_domain_name = default' /etc/nova/nova.conf
sed -i '/\#user_domain_name=<None>/c user_domain_name = default' /etc/nova/nova.conf
sed -i '/\#region_name=RegionOne/c region_name = RegionOne' /etc/nova/nova.conf
sed -i '/\#project_name=<None>/c project_name = service' /etc/nova/nova.conf
sed -i '/\#username=<None>/c username = neutron' /etc/nova/nova.conf
sed -i '/\#password=<None>/c password=neutron' /etc/nova/nova.conf
sed -i '/\#service_metadata_proxy=false/c service_metadata_proxy = true' /etc/nova/nova.conf
sed -i '/\#metadata_proxy_shared_secret =/c metadata_proxy_shared_secret = openstack_pass' /etc/nova/nova.conf

##Populating neutron database
/bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
service nova-api restart
service neutron-server restart
service neutron-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart

##Verify operation
source /etc/profile.d/admin-openrc.sh
openstack extension list --network
openstack network agent list

##Installing dashboard
apt install -y openstack-dashboard
##/etc/openstack-dashboard/local_settings.py
sed -i "s|OPENSTACK_HOST = \"127.0.0.1\"|OPENSTACK_HOST = \"controller\"|" /etc/openstack-dashboard/local_settings.py
sed -i "s|#ALLOWED_HOSTS = \['horizon.example.com', \]|ALLOWED_HOSTS = \['*'\]|" /etc/openstack-dashboard/local_settings.py
sed -i "137i SESSION_ENGINE = 'django.contrib.sessions.backends.cache'" /etc/openstack-dashboard/local_settings.py
sed -i "s|        'LOCATION': '127.0.0.1:11211'|         'LOCATION': 'controller:11211'|" /etc/openstack-dashboard/local_settings.py
sed -i "s|OPENSTACK_KEYSTONE_URL = \"http:\/\/%s:5000\/v2.0\" % OPENSTACK_HOST|OPENSTACK_KEYSTONE_URL = \"http:\/\/%s:5000\/v3\" % OPENSTACK_HOST|" /etc/openstack-dashboard/local_settings.py
sed -i "s|#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = False|OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True|" /etc/openstack-dashboard/local_settings.py
sed -i "55i OPENSTACK_API_VERSIONS = { \"identity\": 3, \"image\": 2, \"volume\": 2, }" /etc/openstack-dashboard/local_settings.py
sed -i "s|#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'|OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"Default\"|" /etc/openstack-dashboard/local_settings.py
sed -i "s|OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"_member_\"|OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"|" /etc/openstack-dashboard/local_settings.py
sed -i "s|    'enable_router': True,|    'enable_router': False,|" /etc/openstack-dashboard/local_settings.py
sed -i "s|    'enable_quotas': True,|    'enable_quotas': False,|" /etc/openstack-dashboard/local_settings.py
sed -i "s|    'enable_ipv6': True,|    'enable_ipv6': False,|" /etc/openstack-dashboard/local_settings.py
sed -i "s|    'enable_lb': True,|    'enable_lb': False,|" /etc/openstack-dashboard/local_settings.py
sed -i "s|    'enable_firewall': True,|    'enable_firewall': False,|" /etc/openstack-dashboard/local_settings.py
sed -i "s|    'enable_vpn': True,|    'enable_vpn': False,|" /etc/openstack-dashboard/local_settings.py
sed -i "s|    'enable_fip_topology_check': True,|    'enable_fip_topology_check': False,|" /etc/openstack-dashboard/local_settings.py

chown www-data /var/lib/openstack-dashboard/secret_key
service apache2 reload

##Installing cinder
mysql --execute="CREATE DATABASE cinder;"
mysql --execute="GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'cinder';"
mysql --execute="GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'cinder';"
source /etc/profile.d/admin-openrc.sh
openstack user create --domain default --password cinder cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s

apt install -y cinder-api cinder-scheduler
##/etc/cinder/cinder.conf
echo '[database]
connection = mysql+pymysql://cinder:cinder@controller/cinder' >> /etc/cinder/cinder.conf
sed -i "12i transport_url = rabbit://openstack:openstack_pass@controller" /etc/cinder/cinder.conf
echo '[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = cinder
password = cinder' >> /etc/cinder/cinder.conf
sed -i "12i my_ip = 10.0.0.11" /etc/cinder/cinder.conf
echo '[oslo_concurrency]
lock_path = /var/lib/cinder/tmp' >> /etc/cinder/cinder.conf
/bin/sh -c "cinder-manage db sync" cinder

##Finalize cinder installation
##/etc/nova/nova.conf
##[cinder]
sed -i '/\#os_region_name=<None>/c os_region_name = RegionOne' /etc/nova/nova.conf
service nova-api restart
service cinder-scheduler restart
service apache2 restart

##Verify cinder operation
source /etc/profile.d/admin-openrc.sh
openstack volume service list

##Swift installation
source /etc/profile.d/admin-openrc.sh
openstack user create --domain default --password swift swift
openstack role add --project service --user swift admin
openstack service create --name swift --description "OpenStack Object Storage" object-store
openstack endpoint create --region RegionOne object-store public http://controller:8080/v1/AUTH_%\(tenant_id\)s
openstack endpoint create --region RegionOne object-store internal http://controller:8080/v1/AUTH_%\(tenant_id\)s
openstack endpoint create --region RegionOne object-store admin http://controller:8080/v1
apt-get install -y swift swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware memcached
mkdir /etc/swift
curl -o /etc/swift/proxy-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/proxy-server.conf-sample?h=stable/newton

##/etc/swift/proxy-server.conf
##[DEFAULT]
##bind_port = 8080
sed -i '/\# user = swift/c user = swift' /etc/swift/proxy-server.conf
sed -i "s|# swift_dir = /etc/swift|swift_dir = /etc/swift|" /etc/swift/proxy-server.conf
##[pipeline:main]
sed -i '/\pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk tempurl ratelimit tempauth copy container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server/c pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server' /etc/swift/proxy-server.conf
##[app:proxy-server]
##use = egg:swift#proxy already set
sed -i '/\# account_autocreate = false/c account_autocreate = True' /etc/swift/proxy-server.conf
##[filter:keystoneauth]
sed -i '/\# \[filter:keystoneauth\]/c \[filter:keystoneauth\]' /etc/swift/proxy-server.conf
sed -i '/\# use = egg:swift#keystoneauth/c use = egg:swift#keystoneauth' /etc/swift/proxy-server.conf
sed -i '/\# operator_roles = admin, swiftoperator/c operator_roles = admin,user' /etc/swift/proxy-server.conf
##[filter:authtoken]
sed -i '/\# \[filter:authtoken\]/c \[filter:authtoken\]' /etc/swift/proxy-server.conf
sed -i '/\# paste.filter_factory = keystonemiddleware.auth_token:filter_factory/c paste.filter_factory = keystonemiddleware.auth_token:filter_factory' /etc/swift/proxy-server.conf
sed -i "s|# auth_uri = http:\/\/keystonehost:5000|auth_uri = http:\/\/controller:5000|" /etc/swift/proxy-server.conf
sed -i "s|# auth_url = http:\/\/keystonehost:35357|auth_url = http:\/\/controller:35357|" /etc/swift/proxy-server.conf
sed -i "335i memcached_servers = controller:11211" /etc/swift/proxy-server.conf
sed -i "335i auth_type = password" /etc/swift/proxy-server.conf
sed -i "335i project_domain_name = default" /etc/swift/proxy-server.conf
sed -i "335i user_domain_name = default" /etc/swift/proxy-server.conf
sed -i '/\# project_name = service/c project_name = service' /etc/swift/proxy-server.conf
sed -i '/\# username = swift/c username = swift' /etc/swift/proxy-server.conf
sed -i '/\# password = password/c password = swift' /etc/swift/proxy-server.conf
sed -i '/\# delay_auth_decision = True/c delay_auth_decision = True' /etc/swift/proxy-server.conf
##[filter:cache]
##use = egg:swift#memcache
sed -i '/\# memcache_servers = 127.0.0.1:11211/c memcache_servers = controller:11211' /etc/swift/proxy-server.conf

##Create and distribute initial rings
cd /etc/swift
swift-ring-builder account.builder create 10 3 1

##Add each storage node to the ring
##Object storage 1
swift-ring-builder account.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6202 --device sdb --weight 100
swift-ring-builder account.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6202 --device sdc --weight 100
##Object storage 2
swift-ring-builder account.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6202 --device sdb --weight 100
swift-ring-builder account.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6202 --device sdc --weight 100

##Verify the ring contents
swift-ring-builder account.builder

##Rebalance the ring
swift-ring-builder account.builder rebalance

##Create container ring
cd /etc/swift
swift-ring-builder container.builder create 10 3 1

##Add each storage node to the ring
swift-ring-builder container.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6201 --device sdb --weight 100
swift-ring-builder container.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6201 --device sdc --weight 100
swift-ring-builder container.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6201 --device sdb --weight 100
swift-ring-builder container.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6201 --device sdc --weight 100

##Verify the ring contents
swift-ring-builder container.builder

##Rebalance the ring
swift-ring-builder container.builder rebalance

##Create object ring
cd /etc/swift
swift-ring-builder object.builder create 10 3 1

##Add each storage node to the ring
swift-ring-builder object.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6200 --device sdb --weight 100
swift-ring-builder object.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6200 --device sdc --weight 100
swift-ring-builder object.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6200 --device sdb --weight 100
swift-ring-builder object.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6200 --device sdc --weight 100

##Verify the ring contents
swift-ring-builder object.builder

##Rebalance the ring
swift-ring-builder object.builder rebalance

##Distribute ring configuration files
## Copy the account.ring.gz, container.ring.gz, and object.ring.gz files to the /etc/swift directory on each storage node and any additional nodes running the proxy service.

##Finalize installation
curl -o /etc/swift/swift.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/swift.conf-sample?h=stable/newton

##/etc/swift/swift.conf
##[swift-hash]
sed -i "s|swift_hash_path_suffix = changeme|swift_hash_path_suffix = dads|" /etc/swift/swift.conf
sed -i "s|swift_hash_path_prefix = changeme|swift_hash_path_prefix = infotec|" /etc/swift/swift.conf
##[storage-policy:0]
##name = Policy-0
##default = yes

service memcached restart
service swift-proxy restart

##Verify operation
source /etc/profile.d/admin-openrc.sh
swift stat
openstack container create container1
openstack object create container1 cirros-0.3.5-x86_64-disk.img
openstack object list container1
openstack object save container1 cirros-0.3.5-x86_64-disk.img
