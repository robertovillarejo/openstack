# Administración del servicio compute

## Usando nova
  * Crear sabores
    `openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano`

  * Se crean las llaves de seguridad necesarias
    `ssh-keygen -q -N ""`
    `openstack keypair create --public-key /root/.ssh/id_rsa.pub mykey`

  * Se verifica que se hayan creado las llaves
    `openstack keypair list`

  * Se crea el grupo de seguridad para permitir ping
    `openstack security group rule create --proto icmp default`

  * Se crea el grupo de seguridad para permitir ssh
    `openstack security group rule create --proto tcp --dst-port 22 default`

### Determinar las opciones de la instancia
  * Revisar la lista de sabores
    `openstack flavor list`

  * Revisar las imágenes disponibles
    `openstack image list`

  * Listar las redes disponibles
    `openstack network list`

  * Revisar los grupos de seguridad
    `openstack security group list`

  * Lanzar la instancia
    `openstack server create --flavor m1.nano --image cirros --nic net-id=2f63ae72-405c-4a64-9c41-6a8d590ba600  --security-group default --key-name mykey provider-instance`

  * Verificar el estado de la instancia
    `openstack server list`

## Obtener acceso a una instancia
  * Por VNC mediante Web
    `openstack console url show provider-instance`

  * Verificando el acceso a red via ping
    `ping -c 4 203.0.113.1`

  * Verificando el acceso a Internet
    `ping -c 4 openstack.org`

  * Para acceder vía remota
    + Verificar que esté disponible la instancia desde la red pública
      `ping -c 4 203.0.113.103`

    + Acceder a la instancia vía ssh
      `ssh cirros@203.0.113.103`

## Migraciones
  * Tipos de migración:
    + En frío: la instancia se apagam se mueve a otro hipervisor y se reinicia
    + En vivo: la instancia se mantiene corriendo durante la migración

    `openstack server list`
    `openstack server show ID`
    `openstack compute service list`
    `openstack host show NOMBRE_DEL_HOST`
    `openstack server migrate ID --live NOMBRE_DEL_HOST`
    `openstack server show ID`

## Mostrar estadísticas
  * Uso de los recursos del host
    `openstack host show NOMBRE_DEL_HOST`

  * Uso de los recursos de la instancia
    `nova diagnostics NOMBRE_DEL_SERVIDOR`

  * Uso de recursos por proyecto
    `openstack usage list`

## Evacuación de instancias
  * En caso de una falla que haga fallar al nodo compute donde se aloja una instancia, se puede usar este comando para llevar la instancia a otro nodo.
    `nova evacuate NOMBRE_DEL_SERVIDOR [NOMBRE_DEL_HOST]`

    Si se omite el nombre del host, nova_scheduler decide a donde lo va a mover

## Otras operaciones sobre las instancias
  * Agregar un volumen a un servidor
    `openstack server add volume [--device <device>] <server> <volume>`

    * Pausar un servidor
      `openstack server pause <server> [<server> ...]`

    * Reiniciar un servidor
      `openstack server reboot
      [--hard | --soft]
      [--wait]
      <server>`

    * Reconstruir un servidor
      `openstack server rebuild
      [--image <image>]
      [--password <password>]
      [--wait]
      <server>`

    * Retirar un volumen de un servidor
      `openstack server remove volume <server> <volume>`

    * Escalar un servidor a un nuevo sabor
      `openstack server resize
      [--flavor <flavor> | --confirm | --revert]
      [--wait]
      <server>`

    * Iniciar una sesión en el servidor
      `openstack server ssh
      [--login <login-name>]
      [--port <port> --identity <keyfile> --option <config-options>]
      [-4 | -6]
      [--public | --private | --address-type <address-type>]
      <server>`

    * Iniciar un servidor
      `openstack server start <server> [<server> ---]`

    * Detener un servidor
      `openstack server stop <server> [<server> ---]`

    * Detener un servidor
      `openstack server suspend <server> [<server> ---]`

    * Detener un servidor
      `openstack server unpause <server> [<server> ---]`
