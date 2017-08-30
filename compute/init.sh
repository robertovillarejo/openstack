#!/bin/bash

echo '
export PS1="\[\e[01;34m\]compute\[\e[0m\]\[\e[01;37m\]:\w\[\e[0m\]\[\e[00;37m\]\n\\$ \[\e[0m\]"
' >> /home/ubuntu/.bashrc

## Configure name resolution
sed -i "2i10.0.0.11       controller" /etc/hosts
sed -i "2i10.0.0.31       compute" /etc/hosts
sed -i "2i10.0.0.41       block" /etc/hosts
sed -i "2i10.0.0.51       object1" /etc/hosts
sed -i "2i10.0.0.52       object2" /etc/hosts

## Configure NTP server (client)
apt install -y chrony
sed -i '/# NTP server./a server controller iburst' /etc/chrony/chrony.conf
sed -i '/#allow ::/a allow 10.0.0.0/24' /etc/chrony/chrony.conf
service chrony restart

## Install Open Stack repository
apt install -y software-properties-common
add-apt-repository cloud-archive:ocata -y
apt update && apt dist-upgrade -y
##apt install -y python-openstackclient

##Install compute service
apt install -y nova-compute

##/etc/nova/nova.conf
##[DEFAULT]
sed -i '/#transport_url=<None>/c transport_url = rabbit://openstack:openstack_pass@controller' /etc/nova/nova.conf
sed -i '/#my_ip=10.222.99.93/c my_ip = 10.0.0.31' /etc/nova/nova.conf
sed -i '/#use_neutron=true/c use_neutron = True' /etc/nova/nova.conf
sed -i '/#firewall_driver=<None>/c firewall_driver = nova.virt.firewall.NoopFirewallDriver' /etc/nova/nova.conf
##[api]
sed -i '/#auth_strategy=keystone/c auth_strategy = keystone' /etc/nova/nova.conf
##[keystone_authtoken]
sed -i '/#auth_uri=<None>/c auth_uri = http:\/\/controller:5000' /etc/nova/nova.conf
sed -i "5610i auth_url = http:\/\/controller:35357" /etc/nova/nova.conf
sed -i '/#memcached_servers=<None>/c memcached_servers = controller:11211' /etc/nova/nova.conf
sed -i "5610i auth_type = password" /etc/nova/nova.conf
sed -i "5610i project_domain_name = default" /etc/nova/nova.conf
sed -i "5610i user_domain_name = default" /etc/nova/nova.conf
sed -i "5610i project_name = service" /etc/nova/nova.conf
sed -i "5610i username = nova" /etc/nova/nova.conf
sed -i "5610i password = nova" /etc/nova/nova.conf
##[vnc]
sed -i '/#enabled=true/c enabled = True' /etc/nova/nova.conf
sed -i '/#vncserver_listen=127.0.0.1/c vncserver_listen = 0.0.0.0' /etc/nova/nova.conf
sed -i '/#vncserver_proxyclient_address=127.0.0.1/c vncserver_proxyclient_address = $my_ip' /etc/nova/nova.conf
sed -i "s|#novncproxy_base_url=http:\/\/127.0.0.1:6080\/vnc_auto.html|novncproxy_base_url = http:\/\/controller:6080\/vnc_auto.html|" /etc/nova/nova.conf
##[glance]
sed -i '/#api_servers=<None>/c api_servers = http:\/\/controller:9292' /etc/nova/nova.conf
##[oslo_concurrency]
sed -i "s|lock_path=/var/lock/nova|lock_path = /var/lib/nova/tmp|" /etc/nova/nova.conf
##[placement]
sed -i '/os_region_name = openstack/c os_region_name = RegionOne' /etc/nova/nova.conf
sed -i "8179i project_domain_name = Default" /etc/nova/nova.conf
sed -i "8173i project_name = service" /etc/nova/nova.conf
sed -i "8155i auth_type = password" /etc/nova/nova.conf
sed -i "8208i user_domain_name = Default" /etc/nova/nova.conf
sed -i "8162i auth_url = http:\/\/controller:35357\/v3" /etc/nova/nova.conf
sed -i "8203i username = placement" /etc/nova/nova.conf
sed -i "8213i password = placement" /etc/nova/nova.conf

##Determine whether your compute node supports hardware acceleration for virtual machines
export hardware_acceleration=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ "$hardware_acceleration" == "0" ]; then
  sed -i "s|virt_type=kvm|virt_type=qemu|" /etc/nova/nova-compute.conf
fi

service nova-compute restart

##Neutron
apt install -y neutron-linuxbridge-agent

##/etc/neutron/neutron.conf
##[database]
sed -i "s|connection = sqlite:////var/lib/neutron/neutron.sqlite|#connection = sqlite:////var/lib/neutron/neutron.sqlite|" /etc/neutron/neutron.conf
sed -i '/\#transport_url = <None>/c transport_url = rabbit://openstack:openstack_pass@controller' /etc/neutron/neutron.conf
sed -i '/\#auth_strategy = keystone/c auth_strategy = keystone' /etc/neutron/neutron.conf
sed -i '/\#auth_uri = <None>/c auth_uri = http:\/\/controller:5000' /etc/neutron/neutron.conf
sed -i '/\#auth_url=<None>/c auth_url = http:\/\/controller:35357' /etc/neutron/neutron.conf
## sed -i "769i auth_url = http:\/\/controller:35357" /etc/neutron/neutron.conf
sed -i '/\#memcached_servers = <None>/c memcached_servers = controller:11211' /etc/neutron/neutron.conf
sed -i '/\#auth_type = <None>/c auth_type = password' /etc/neutron/neutron.conf
sed -i "769i project_domain_name = default" /etc/neutron/neutron.conf
sed -i "769i user_domain_name = default" /etc/neutron/neutron.conf
sed -i "769i project_name = service" /etc/neutron/neutron.conf
sed -i "769i username = neutron" /etc/neutron/neutron.conf
sed -i "769i password = neutron" /etc/neutron/neutron.conf

##/etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#physical_interface_mappings =/c physical_interface_mappings = provider:enp0s8' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#enable_vxlan = true/c enable_vxlan = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#local_ip = <None>/c local_ip = 10.0.0.11' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#l2_population = false/c l2_population = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#enable_security_group = true/c enable_security_group = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i '/\#firewall_driver = <None>/c firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' /etc/neutron/plugins/ml2/linuxbridge_agent.ini

##Configure the Compute service to use the Networking service
##/etc/nova/nova.conf
sed -i '/\#url=http:\/\/127.0.0.1:9696/c url = http:\/\/controller:9696' /etc/nova/nova.conf
##auth_url
##auth_type=password

echo '[neutron]
url = http://controller:9696
auth_url = http://controller:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = neutron' >> /etc/nova/nova.conf

##Finalize Installation
service nova-compute restart
service neutron-linuxbridge-agent restart
