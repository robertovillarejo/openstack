# OpenStack
This repository contains the Vagrantfiles and scripts needed for the [OpenStack installation tutorial for Ubuntu](https://docs.openstack.org/ocata/install-guide-ubuntu/)  

For each machine in infraestructure a directory was created which contains a Vagrantfile.
Before creating machines please [install Vagrant](https://www.vagrantup.com/intro/getting-started/install.html) and [VirtualBox](https://www.virtualbox.org/)  

# Vagrant
To create a machine with Vagrant move to a directory of your choice and then run `vagrant up`.  
Once created and configured run `vagrant ssh` to login

# Passwords

| user          | password      |
|:-------------:|:-------------:|
| admin         | keystone      |
| cinder (DB)   | cinder        |
| cinder        | cinder        |
| demo          | demo          |
| glance (DB)   | glance        |
| glance        | glance        |
| keystone (DB) | keystone      |
| metadata proxy| openstack_pass|
| neutron (DB)  | neutron       |
| neutron       | neutron       |
| nova (DB)     | nova          |
| nova          | nova          |
| placement     | placement     |
| rabbit        | openstack_pass|

# Infraestructure

| hostname   | role                |
|:----------:|:-------------------:|
| controller | controller node     |
| compute    | compute node        |
| block      | block storage node  |
| object1    | object storage node |
| object2    | object storage node |

# Inventory
| host       | RAM  | hard disk         | network if's | type    | IP addresses |
|:----------:|:----:|:------------------|:------------:|:-------:|:------------:|
| controller | 6 GB | sda 10 GB dynamic | enp0s8       | private | 10.0.0.11    |
|            |      |                   | enp0s3       | public  | dhcp         |
| compute    | 2 GB | sda 10 GB dynamic | enp0s8       | private | 10.0.0.31    |
|            |      |                   | enp0s3       | public  | dhcp         |
| block      | 2 GB | sda 80 GB dynamic | enp0s8       | private | 10.0.0.41    |
|            |      | sdb 5 GB fixed    | enp0s3       | public  | dhcp         |
| object1    | 2 GB | sda 80 GB dynamic | enp0s8       | private | 10.0.0.51    |
|            |      | sdb 5 GB fixed    | enp0s3       | public  | dhcp         |
|            |      | sdc 5 GB fixed    |              |         |              |
| object2    | 2 GB | sda 80 GB dynamic | enp0s8       | private | 10.0.0.52    |
|            |      | sdb 5 GB fixed    | enp0s3       | public  | dhcp         |
|            |      | sdc 5 GB fixed    |              |         |              |

In this infraestructure example each node has connection to the Internet for automatic installation purposes. However, should be similar to the image.  
![Network layout](https://docs.openstack.org/ocata/install-guide-ubuntu/_images/networklayout.png)
