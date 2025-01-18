# Backup AWS Bucket S3 Sync - Bash Shell Script

<div align="center">
  <img src="../screenshots/backup_aws_bucket_s3_sync_logo.png" width="350" />
</div>

## Descripción

Script en Bash para automatizar el proceso de sincronización de datos locales a un bucket S3 (Simple Storage Service) de Amazon Web Services a través de la interfaz de línea de comandos de AWS (AWSCLI).

▶ Generar un fichero log de todo el proceso.

▶ Sincronizar los datos locales con el objeto (carpeta/directorio) del bucket S3 usando AWSCLI.

▶ Enviar el fichero de log vía Email desde el smtp de una cuenta de correo Gmail configurado en SSMTP.

## Requisitos previos
### Política de permisos en AWS S3  

> Por seguridad en la automatización de este tipo de backups NO se recomienda usar un usuario raíz y con acceso a la consola de AWS.

Se creará un usuario específico para este fin únicamente con los permisos y accesos necesarios.

#### Identity and Access Management (IAM)
1. Crear un nuevo usuario con las siguientes condiciones:
- Sin ningún tipo de privilegio administrativo, tampoco podrá iniciar sesión en la consola de administración de AWS.
- Solo se podrá conectar a través de su ID y clave de acceso (será la que se establezca posteriormente en el fichero %userprofile%\.aws\credentials).

![Credenciales sesion usuario aws](https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3/master/screenshots/credenciales_sesion_usuario_aws.png)

2. Crear una nueva política donde solo se especifique:
- Servicio: S3
- Acciones: Enumeration (ListBucket), Escritura (DeleteObject, PutObject)
- Recursos: Especificar únicamente el recuro ARN del bucket donde se realizarán los backups y un * para las acciones de todos los objetos dentro del bucket.

#### Resumen de la política - JSON

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::BucketS3Name",
                "arn:aws:s3:::BucketS3Name/*"
            ]
        }
    ]
}
```

### Configuración "Access Key" y "Secret Access key" para usar aws-cli

3. [Instalación de AWSCLI en Windows](https://docs.aws.amazon.com/es_es/cli/latest/userguide/install-windows.html).

4. Establecer las access keys en AWSCLI. En un entorno Windows estas keys quedarán almacenadas en el fichero %userprofile%\.aws\credentials.

```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: eu-south-2
Default output format [None]: json
```

#### **Backup-AWS-S3.sh**: establecer los valores deseados en las variables.

- pathLocalDatos="/pathLocal/datos/"
- pathRemotoBucketS3="s3://bucketS3/backup/"
- envioEmailCuentaUsuario="Usuario@email.com"
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

- root=EMAIL_OUTLOOK
- hostname=HOSTNAME
- AuthUser=EMAIL_OUTLOOK
- AuthPass=PASSWORD_OUTLOOK

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
Envía un correo del fichero de log adjunto y su contenido vía protocolo SMTP de Outlook. 

> Por seguridad Gmail ya no permite esta opción. https://support.google.com/accounts/answer/6010255

![Envio Email Log](https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3-Bash-PowerShell/master/screenshots/envio_email_backup_log_gmail_powershell.png)

# Recuperación Backup: S3 a Local

Copiar ficheros y directorios de bucket S3 a local.

Hay que tener en cuenta de añadir los permisos adicionales para poder descargar ficheros y carpetas desde un bucket S3 a local. 

https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/cp.html
```
aws s3 cp s3://BucketS3Name/backup/ <LOCAL_PATH> --recursive
```