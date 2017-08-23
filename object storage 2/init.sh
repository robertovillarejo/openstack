#!/bin/bash

echo '
export PS1="\[\e[01;34m\]object2\[\e[0m\]\[\e[01;37m\]:\w\[\e[0m\]\[\e[00;37m\]\n\\$ \[\e[0m\]"
' >> /home/vagrant/.bashrc

## Configure name resolution
sed -i "2i10.0.0.11       controller" /etc/hosts
sed -i "2i10.0.0.31       compute" /etc/hosts
sed -i "2i10.0.0.41       block" /etc/hosts
sed -i "2i10.0.0.51       object1" /etc/hosts
sed -i "2i10.0.0.52       object2" /etc/hosts

apt update

##Prerequisites
apt-get install -y xfsprogs rsync

##Format the devices
mkfs.xfs -f /dev/sdb
mkfs.xfs -f /dev/sdc

## Creating mounting points
mkdir -p /srv/node/sdb
mkdir -p /srv/node/sdc

##/etc/fstab
echo '/dev/sdb /srv/node/sdb xfs noatime,nodiratime,nobarrier,logbufs=8 0 2
/dev/sdc /srv/node/sdc xfs noatime,nodiratime,nobarrier,logbufs=8 0 2' >> /etc/fstab

##Mount the devices
mount /srv/node/sdb
mount /srv/node/sdc

##/etc/rsyncd.conf
echo 'uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 10.0.0.52

[account]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/object.lock' > /etc/rsyncd.conf

##/etc/default/rsync
sed -i '/\RSYNC_ENABLE=false/c RSYNC_ENABLE=true' /etc/default/rsync
service rsync start

##Install and configure components
apt-get install -y swift swift-account swift-container swift-object
curl -o /etc/swift/account-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/account-server.conf-sample?h=stable/newton
curl -o /etc/swift/container-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/container-server.conf-sample?h=stable/newton
curl -o /etc/swift/object-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/object-server.conf-sample?h=stable/newton

##/etc/swift/account-server.conf
##[DEFAULT]
sed -i '/\# bind_ip = 0.0.0.0/c bind_ip = 10.0.0.52' /etc/swift/account-server.conf
##bind_port = 6202
sed -i '/\# user = swift/c user = swift' /etc/swift/account-server.conf
sed -i "s|# swift_dir = /etc/swift|swift_dir = /etc/swift|" /etc/swift/account-server.conf
sed -i "s|# devices = /srv/node|devices = /srv/node|" /etc/swift/account-server.conf
sed -i "s|# mount_check = true|mount_check = True|" /etc/swift/account-server.conf
##[pipeline:main]
##pipeline = healthcheck recon account-server
##[filter:recon]
##use = egg:swift#recon
sed -i "s|# recon_cache_path = /var/cache/swift|recon_cache_path = /var/cache/swift|" /etc/swift/account-server.conf

##/etc/swift/container-server.conf
##[DEFAULT]
sed -i '/\# bind_ip = 0.0.0.0/c bind_ip = 10.0.0.52' /etc/swift/container-server.conf
##bind_port = 6201
sed -i '/\# user = swift/c user = swift' /etc/swift/container-server.conf
sed -i "s|# swift_dir = /etc/swift|swift_dir = /etc/swift|" /etc/swift/container-server.conf
sed -i "s|# devices = /srv/node|devices = /srv/node|" /etc/swift/container-server.conf
sed -i "s|# mount_check = true|mount_check = True|" /etc/swift/container-server.conf
##[pipeline:main]
##pipeline = healthcheck recon container-server
##[filter:recon]
##use = egg:swift#recon
sed -i "s|# recon_cache_path = /var/cache/swift|recon_cache_path = /var/cache/swift|" /etc/swift/container-server.conf

##/etc/swift/object-server.conf
##[DEFAULT]
sed -i '/\# bind_ip = 0.0.0.0/c bind_ip = 10.0.0.52' /etc/swift/object-server.conf
##bind_port = 6201
sed -i '/\# user = swift/c user = swift' /etc/swift/object-server.conf
sed -i "s|# swift_dir = /etc/swift|swift_dir = /etc/swift|" /etc/swift/object-server.conf
sed -i "s|# devices = /srv/node|devices = /srv/node|" /etc/swift/object-server.conf
sed -i "s|# mount_check = true|mount_check = True|" /etc/swift/object-server.conf
##[pipeline:main]
##pipeline = healthcheck recon object-server
##[filter:recon]
##use = egg:swift#recon
sed -i "s|# recon_cache_path = /var/cache/swift|recon_cache_path = /var/cache/swift|" /etc/swift/object-server.conf
sed -i "s|#recon_lock_path = /var/lock|recon_lock_path = /var/lock|" /etc/swift/object-server.conf

##Ensure proper ownership of the mount point directory structure
chown -R swift:swift /srv/node

##Create the recon directory and ensure proper ownership of it
mkdir -p /var/cache/swift
chown -R root:swift /var/cache/swift
chmod -R 775 /var/cache/swift

cp /vagrant/account.ring.gz /etc/swift
cp /vagrant/container.ring.gz /etc/swift
cp /vagrant/object.ring.gz /etc/swiftva
cp /vagrant/swift.conf /etc/swift

chown -R root:swift /etc/swift

swift-init all start
