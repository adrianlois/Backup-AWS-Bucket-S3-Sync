# Backups aws sync bucket S3 - Bash Shell Script

Backups - Script en Bash para sincronizar datos locales a un bucket S3 (Simple Storage Service) de Amazon Web Services a través de la interfaz de línea de comandos de AWS (AWSCLI).

- 1. Se genera un fichero log de todo el proceso.
- 2. Con awscli se sincronizan los datos locales con el objeto (carpeta/directorio) del bucket S3.
- 3. Se envía el fichero de log vía Email desde el smtp de una cuenta de correo Gmail configurado en SSMTP.

## Requisitos previos
### Configuración "Access Key" y "Secret Access key" para usar aws-cli

1. [Instalación de AWSCLI en Linux](https://docs.aws.amazon.com/es_es/cli/latest/userguide/install-linux.html).

2. Previamente se deberá crear un usuario de IAM con permisos en la política "AmazonS3FullAccess" y establecer las keys en AWSCLI. En un entorno Windows estas keys quedarán almacenadas en el fichero "/home/usuario/.aws/credentials".

```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

#### **backup-aws-S3.sh**: establecer los valores deseados en las variables

- pathLocalDatos="/pathLocal/datos/"
- pathRemotoBucketS3="s3://bucketS3/backup/"
- envioEmailCuentaUsuario="emailCuentaUsuario@gmail.com"
- asuntoEmail="asuntoEmail"
- cuerpoEmail="cuerpoEmail"

**_Detalles a tener en cuenta_**

- *--delete: Elimina los ficheros/directorios en el bucket S3 (pathRemoto) que ya no existan en el origen (pathLocal).*

- *aws s3 sync: Verifica si uno o más ficheros y/o directorios locales existentes se han actualizado comprobando su nombre, tamaño y el timestamp (marca de tiempo). Actualmente no creo que compruebe los cambios en los hashes del fichero.*

- *Se usará el comando "mail" por defecto de Linux para el envío de Emails*

 ## Instalación y configuración de SSMTP para el envío de emails usando el comando mail
 
**Instalar SSMTP Sendmail**
```
apt update -y
apt install -y ssmtp
```
Editar el fichero **/etc/ssmtp/ssmtp.conf**: establecer los valores deseados para los siguientes parámetros

- AuthUser=passwdEmail
- AuthPass=usuarioEmail

### Desactivar el envío de alertas de correo de cron

Por defecto todos los emails se enviarán a la cuenta local del usuario que ejecuta el cron

- Añadir al final de cada línea en la que tengamos una tarea programada, una redirección a /dev/null descartando así su salida.
```
&> /dev/null
o
>/dev/null 2>&1
```
- Otra opción sería agregar al fichero "***crontab -e***" o "***/etc/crontab***" la variable MAILTO con valor vacío.
```
MAILTO=""
```

### Envío log cuenta Gmail (Google)
Para el envío del log vía Gmail es necesario activar el acceso a "Aplicaciones menos seguras" en la cuenta Google. Por seguridad, se debería crear una cuenta específica para esta finalidad.
https://myaccount.google.com/lesssecureapps

![Aplicaciones menos seguras Google](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-bucket-S3-Bash-PowerShell/master/screenshots/ejecucion_app_menos_seguras_gmail.png)
