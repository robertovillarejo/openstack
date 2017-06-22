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


