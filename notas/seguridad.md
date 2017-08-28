# Consideraciones de seguridad

## Servicios de administración continua
1. Vulnerabilidades
* OSSA (OpenStack Security Advisor)
* OSSN (OpenStack Security Notes)
* Triage (clasificación de urgencia de las vulnerabilidades)
* Actualizaciones  
  * Verificar prerrequisitos
  * Preparar el software a instalar
  * Respaldar
  * Programar la actualización


2. Configuraciones
* Chef
* Puppet
* Salt Stack
* Ansible
* Políticas de cambio

3. Respaldo y recuperación
* Frecuencia
  * Un respaldo incremental diario
  * Un respaldo consolidado (completo) cada semana

4. Auditoría
    Es el aseguramiento del correcto funcionamiento y operación de la infraestructura

## Integridad del ciclo de vida

1. Arranque seguro
  * Aprovisionamiento de nodos
  * Verificación del arranque
  * Fortalecimiento de la seguridad
    + Estándares
       - STIG (Security Technical Implementation Guide)
       - CIS (Center for Internet Security)
    + Herramientas de software semi automatizadas
      Estas herramientas proporcionan una gran ayuda al administrador mas no lo sustituye.
      Es importante depurar los servicios y programas instalados en un servidor para reducir la carga de los recursos y aumentar el rendimiento. El comando `netstat` provee información sobre los puertos de red abiertos en un host.  

       - OpenSCAP
       El ecosistema OpenSCAP proporciona múltiples herramientas para ayudar a los administradores y auditores a evaluar, medir y hacer cumplir las líneas de base de seguridad

      - Ansible-hardening
    + *Nada como el trabajo en casa*
       - Verificar usuarios y permisos
       - Eliminar o detener los paquetes que no se utilicen
       - Políticas de solo lectura (solo permitir la escritura en lo que se debe)

2. Verificación de runtime
  * Detección de intrusos
    + En el sistema
      - OSSEC
      - Samhain
      - Tripwire
      - AIDE
    + En las redes
      - Snort
  * Fortalecimiento del servidor
    + Verificación de la integridad de dispositivos de almacenamiento
    + Verificación de la integridad de archivos
      En Linux, el comando `fsck` verifica y repara un sistema de archivos de Linux

3. Seguridad de la base de datos
  * Cada RDBMS tiene sus propias configuraiones de seguridad
  * Uno de los principales problemas de seguridad es el acceso granular a la base de datos
  * Todas las bases de datos deben estar aisladas de la red de administración
  * Se recomienda el uso de TLS para la comunicación entre nodos: `sql_connection = mysql://compute01:NOVA_DBPASS@localhost/nova?charset=utf8&ssl_ca=/etc/mysql/cacert:pem`
  * Crear una sola cuenta para cada base de datos involucrada en OpenStack
  * En medida de lo posible hacer que los administradores  se deban conectar usando protocolo seguro `GRANT ALL ON DBNAME.* TO 'USER'@'CLIENT' IDENTIFIED BY 'PASSWORD' REQUIRE SSL;`

    Véase [Creating SSL Certificates and Keys Using openssl](https://dev.mysql.com/doc/refman/5.7/en/creating-ssl-files-using-openssl.html)

4. Seguridad de la cola de mensajes
  * La manera más simple de establecer estas opciones, es editando el archivo de configuración `rabbitmq.config`. (Consulte la [documentación de RabbitMQ](https://www.rabbitmq.com/ssl.html))

5. Seguridad de instancias
  * Imágenes seguras
    Asegurarse que las imágenes que se ponen a disposición de los usuarios sean seguras, que no tengan vulnerabilidades.

  * Asignación de recursos
    Planificar adecuadamente los recursos a las instancias de los usuarios. Al asignar los recursos debe tomarse en cuenta que puede existir un momento en el que todas las instancias se ejecutan al mismo tiempo.

  * Migración de instancias (Mover de un nodo de cómputo a otro)
    Asegurarse que el nodo de cómputo al que se mueve una instancia cuenta con recursos suficientes.

  * Monitoreo, alerta y reporte

  * Actualizaciones y parches
    Conocer los *bugs* potenciales de cada aplicación y protegerse de manera correcta

  * Controles de seguridad perimetral
      Firewall, control del tráfico de la red, etc.
      *Splunk* es una herramienta con la que se puede buscar, monitorear, analizar y visualizar los *logs* de las nodos.

6. Respuesta a incidentes
    1. Identificación y diagnóstico de fallas **¿Cuáles son los síntomas?**
        * Revisión de archivos de *log*
        * Revisión de *workflow*
          Conocimiento del flujo de trabajo de los servicios instalados en los nodos

    2. Diagnóstico **¿Cuál es el problema?**
        Debido a la carga del trabajo, los dos servicios que usualmente fallan son la cola de mensajes y la base de datos.
    3. Propuesta de soluciones
    4. Selección de solución
    5. Aplicación de la solución
    6. Pruebas y ajustes
    7. Liberación

7. Arquitectura de redes
  * Elementos fíServicios
    + Switches
    + Ruteadores
    + Firewalls
    + Balanceadores de carga
  * Elementos lógicos
    * Protocolos (DNS, NTP, HTTP)
    * Túneles (Canales virtuales de comunicación)
    * NAT
