#!/bin/bash

echo '
export PS1="\[\e[01;34m\]controller\[\e[0m\]\[\e[01;37m\]:\w\[\e[0m\]\[\e[00;37m\]\n\\$ \[\e[0m\]"
' >> /home/ubuntu/.bashrc

## Configure name resolution

sed -i "2i10.0.0.11       controller" /etc/hosts
sed -i "2i10.0.0.31       compute" /etc/hosts

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
sed -i '/#auth_uri=<None>/c auth_uri = http://controller:5000' /etc/nova/nova.conf
sed -i "5610i auth_url = http://controller:35357" /etc/nova/nova.conf
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
sed -i "s|#novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html|novncproxy_base_url = http://controller:6080/vnc_auto.html|" /etc/nova/nova.conf
##[glance]
sed -i '/#api_servers=<None>/c api_servers = http://controller:9292' /etc/nova/nova.conf
##[oslo_concurrency]
sed -i "s|lock_path=/var/lock/nova|lock_path = /var/lib/nova/tmp|" /etc/nova/nova.conf
##[placement]
sed -i '/os_region_name = openstack/c os_region_name = RegionOne' /etc/nova/nova.conf
sed -i "8179i project_domain_name = Default" /etc/nova/nova.conf
sed -i "8173i project_name = service" /etc/nova/nova.conf
sed -i "8155i auth_type = password" /etc/nova/nova.conf
sed -i "8208i user_domain_name = Default" /etc/nova/nova.conf
sed -i "8162i auth_url = http://controller:35357/v3" /etc/nova/nova.conf
sed -i "8203i username = placement" /etc/nova/nova.conf
sed -i "8213i password = placement" /etc/nova/nova.conf

##Determine whether your compute node supports hardware acceleration for virtual machines
set hardware_acceleration=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ "$hardware_acceleration" == "0" ]; then
  sed -i "s|virt_type=kvm|virt_type=qemu|" /etc/nova/nova-compute.conf
fi

service nova-compute restart
