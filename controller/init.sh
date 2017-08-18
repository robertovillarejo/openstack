#!/bin/bash

echo '
export PS1="\[\e[01;34m\]controller\[\e[0m\]\[\e[01;37m\]:\w\[\e[0m\]\[\e[00;37m\]\n\\$ \[\e[0m\]"
' >> /home/ubuntu/.bashrc

## Configure name resolution

sed -i "2i10.0.0.11       controller" /etc/hosts
sed -i "2i10.0.0.31       compute" /etc/hosts

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
sed -i '/\#auth_uri = <None>/c auth_uri = http://controller:5000' /etc/glance/glance-api.conf
sed -i "3296i auth_url = http://controller:35357" /etc/glance/glance-api.conf
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

#glance-registry.conf
#[database]
sed -i '/\#connection = <None>/c connection = mysql+pymysql://glance:glance@controller/glance' /etc/glance/glance-registry.conf
#[keystone_authtoken]
sed -i '/\#auth_uri = <None>/c auth_uri = http://controller:5000' /etc/glance/glance-registry.conf
sed -i '/\#auth_url = <None>/c auth_url = http://controller:35357' /etc/glance/glance-registry.conf
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
openstack image create "cirros" \
  --file cirros-0.3.5-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public
  openstack image list
