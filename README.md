# OpenStack
This repository contains the Vagrantfiles and scripts needed for the [OpenStack installation tutorial for Ubuntu](https://docs.openstack.org/ocata/install-guide-ubuntu/)  

For each machine in infraestructure a directory was created which contains a Vagrantfile

# Vagrant
Before creating machines please [install Vagrant](https://www.vagrantup.com/intro/getting-started/install.html) and [VirtualBox](https://www.virtualbox.org/)  

To create a machine with Vagrant move to a directory of your choice and then run `vagrant up`.  
Once created and configured run `vagrant ssh` to login

# Passwords

| user          | password      |
| ------------- |:-------------:|
| cinder (DB)   | cinder        |
| cinder        | cinder        |
| demo          | demo          |
| glance (DB)   | glance        |
| glance        | glance        |
| keystone (DB) | keystone      |
| metadata proxy| are neat      |
| neutron (DB)  | neutron       |
| neutron       | neutron       |
| nova (DB)     | nova          |
| nova          | nova          |
| placement     | placement     |
| rabbit        | openstack_pass|
