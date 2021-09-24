# Backups aws sync bucket S3 - Bash Shell Script

Backups - Script en Bash para sincronizar datos locales a un bucket S3 (Simple Storage Service) de Amazon Web Services a través de la interfaz de línea de comandos de AWS (AWSCLI).

- 1. Se genera un fichero log de todo el proceso.
- 2. Con awscli se sincronizan los datos locales con el objeto (carpeta/directorio) del bucket S3.
- 3. Se envía el fichero de log vía Email desde el smtp de una cuenta de correo Gmail configurado en SSMTP.

## Requisitos previos
### Política de permisos en AWS S3  

> Por seguridad en la automatización de este tipo de backups NO se recomienda usar un usuario raíz y con acceso a la consola de AWS.

Se creará un usuario específico para este fin únicamente con los permisos y accesos necesarios.

#### Identity and Access Management (IAM)
1. Crear un nuevo usuario con las siguientes condiciones:
- Sin ningún tipo de privilegio administrativo, tampoco podrá iniciar sesión en la consola de administración de AWS.
- Solo se podrá conectar a través de su ID y clave de acceso (será la que se establezca posteriormente en el fichero %userprofile%\.aws\credentials).

![Credenciales sesion usuario aws](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-Bucket-S3/master/screenshots/credenciales_sesion_usuario_aws.png)

2. Crear una nueva política donde solo se especifique:
- Servicio: S3
- Acciones: Enumeration (ListBucket), Escritura (DeleteObject, PutObject)
- Recursos: Especificar únicamente el recuro ARN del bucket donde se realizarán los backups y un * para las acciones de todos los objetos dentro del bucket.

![Política permisos accesos s3 aws](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-Bucket-S3/master/screenshots/politica_permisos_acceso_s3_aws.png)

### Configuración "Access Key" y "Secret Access key" para usar aws-cli

3. [Instalación de AWSCLI en Windows](https://docs.aws.amazon.com/es_es/cli/latest/userguide/install-windows.html).

4. Establecer las access keys en AWSCLI. En un entorno Windows estas keys quedarán almacenadas en el fichero %userprofile%\.aws\credentials.

```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

#### **backup-aws-S3.sh**: establecer los valores deseados en las variables.

- pathLocalDatos="/pathLocal/datos/"
- pathRemotoBucketS3="s3://bucketS3/backup/"
- envioEmailCuentaUsuario="emailCuentaUsuario@gmail.com"
- asuntoEmail="asuntoEmail"
- cuerpoEmail ="cuerpoEmail"

Podemos elegir entre enviar el fichero de log adjunto o adjuntar el contenido del fichero de log en el cuerpo del mail.

**_Detalles a tener en cuenta_**

- *--delete: Elimina los ficheros/directorios en el bucket S3 (pathRemoto) que ya no existan en el origen (pathLocal).*

- *--sse AES256: (Server Side Encryption) Especifica un cifrado AES256 del lado del servidor para los objetos S3.*

- *aws s3 sync: Verifica si uno o más ficheros y/o directorios locales existentes se han actualizado comprobando su nombre, tamaño y el timestamp (marca de tiempo). Actualmente no creo que compruebe los cambios en los hashes del fichero.*

- *Se usará el comando "mail" por defecto de Linux para el envío de Emails*

- Ayuda comando aws s3 sync: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html

 ## Instalación y configuración de SSMTP para el envío de emails usando el comando mail
 
**Instalar ssmtp sendmail y mailutils**
```
apt update -y
apt install -y ssmtp mailutils
```
Editar el fichero **/etc/ssmtp/ssmtp.conf**: establecer los valores deseados para los siguientes parámetros.

- root=EMAIL_GMAIL
- hostname=HOSTNAME
- AuthUser=EMAIL_GMAIL
- AuthPass=PASSWORD_GMAIL

### Desactivar el envío de alertas de correo de cron

Por defecto todos los emails se enviarán a la cuenta local del usuario que ejecuta el cron.

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

![Envio Email Log Gmail Powershell](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-bucket-S3-Bash-PowerShell/master/screenshots/envio_email_backup_log_gmail_powershell.png)
