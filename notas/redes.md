# Redes físicas y virtuales

## Comandos de administración de redes virtuales
  * Crear tipos de direcciones
    `openstack address scope create --share --ip-version 6 address-scope-ip6`  
    `openstack address scope create --share --ip-version 4 address-scope-ip4`

  * Crear una subred
    `openstack subnet pool create --address-scope address-scope-ip4 --share --pool-prefix 203.0.113.0/24 --default-prefix-length 26 subnet-pool-ip4`

  * Verificar la red creada públicamente
    `openstack subnet show public-subnet`

  * Creación de redes
    `openstack network create network1`  
    `openstack network create network2`

  * Crear una subred no asociada a redes públicas
    `openstack subnet create --network network1 --subnet-range 198.51.100.0/26 subnet-ip4-1`

  * Crear una subred asociada con una red pública
    `openstack subnet create --subnet-pool subnet-pool-ip4 --network network2 subnet-ip4-2`

  * Crear los ruteadores virtuales para cada subred
    `openstack router add subnet router1 subnet-ip4-1`  
    `openstack router add subnet router1 subnet-ip4-2`
    `openstack router add subnet router1 subnet-ip6-1`
    `openstack router add subnet router1 subnet-ip6-2`

## Usando neutron
  * Se crea la red
    `neutron net-create --shared --provider:physical_network provider --provider:network_type flat provider`

  * Se crea la subred
    `neutron subnet-create --name provider --allocation-pool start=203.0.113.101,end=203.0.113.250 --dns-nameserver 8.8.4.4 --gateway 203.0.113.1 provider 203.0.113.0/24`  
    Ejemplo: `neutron subnet-create --name provider --allocation-pool start=192.168.65.250,end=192.168.65.253 --dns-nameserver 8.8.8.8 --gateway 192.168.65.254 provider 192.168.65.0/24`
