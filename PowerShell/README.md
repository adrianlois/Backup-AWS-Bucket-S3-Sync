# Backups aws sync bucket S3 - PowerShell
Backups - Script en Powershell para sincronizar datos locales a un bucket S3 (Simple Storage Service) de Amazon Web Services a través de la interfaz de línea de comandos de AWS (AWSCLI).

- 1. Se genera un fichero log de todo el proceso.
- 2. Con awscli se sincronizan los datos locales con el objeto (carpeta/directorio) del bucket S3.
- 3. Se envía el fichero de log vía Email desde el smtp de una cuenta de correo Gmail.

## Requisitos previos
### Configuración "Access Key" y "Secret Access key" para usar aws-cli

1. [Instalación de AWSCLI en Windows](https://docs.aws.amazon.com/es_es/cli/latest/userguide/install-windows.html).

2. Previamente se deberá crear un usuario de IAM con permisos en la política "AmazonS3FullAccess" y establecer las keys en AWSCLI. En un entorno Windows estas keys quedarán almacenadas en el fichero %userprofile%\.aws\credentials.

```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

#### **backup-aws-S3.ps1**: establecer los valores deseados en las variables

- $pathLocalDatos = "C:\\\pathLocal\\\datos\\\\"
- $pathRemotoBucketS3 = "s3://bucketS3/backup/"
- $usuarioEmail = "usuarioEmail@gmail.com" 
- $passwdEmail = "passwdEmail"
- $asuntoEmail = "asuntoEmail"
- $cuerpoEmail = Será el contenido del fichero de log adjunto en el envío del mail. 

En el script *"backup-aws-S3.ps1"* se pueden ver varias alternativas con el cmdlet *Get-Content* y el namespace *System.io* usando el método *File.ReadAllText* esto hará que el texto adjunto en el cuerpo del mail se visualice de igual forma que fichero de log origen, respetando los saltos de línea.

**_Detalles a tener en cuenta_**

- *Para paths de Windows es necesario establecer un doble slash invertido para separar los directorios "\\\\" , un único slash invertido "\\" se interpretaría como carácter de escape en aws-cli. Windows también admite paths separados con un único slash no invertido "/".*

*Ejemplo de formatos compatibles para referenciar paths en sistemas Windows:*
```
c:\\directorio\\backup\\
c:/directorio/backup/
```

- *--delete: Elimina los ficheros/directorios en el bucket S3 (pathRemoto) que ya no existan en el origen (pathLocal).*

- *--sse AES256: (Server Side Encryption) Especifica un cifrado AES256 del lado del servidor para los objetos S3.*

- *aws s3 sync: Verifica si uno o más ficheros y/o directorios locales existentes se han actualizado comprobando su nombre, tamaño y el timestamp (marca de tiempo). Actualmente no creo que compruebe los cambios en los hashes del fichero.*

- *Se usará el cmdlet "Send-MailMessage" de PowerShell para el envío de Emails*

- Ayuda comando aws s3 sync: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html

### Envío log cuenta Gmail (Google)
Para el envío del log vía Gmail es necesario activar el acceso a "Aplicaciones menos seguras" en la cuenta Google. Por seguridad, se debería crear una cuenta específica para esta finalidad.
https://myaccount.google.com/lesssecureapps

![Aplicaciones menos seguras Google](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-bucket-S3-Bash-PowerShell/master/screenshots/ejecucion_app_menos_seguras_gmail.png)

![Envio Email Log Gmail Powershell](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-bucket-S3-Bash-PowerShell/master/screenshots/envio_email_backup_log_gmail_powershell.png)

### Llamada a fichero PowerShell .ps1 desde un fichero de proceso por lotes .bat
Si queremos crear una tarea programada en Windows (taskschd.msc) para la ejecución automatizada de backups a AWS S3. La forma más efectiva sería establecer directamente un fichero de proceso por lotes .bat y que este llame al fichero PowerShell .ps1.

**call-ps1-backup-aws-S3.bat**: Modificar la variable para establecer el path donde se encuentra el fichero .ps1

- pathLocalPs1="pathLocalFichero.ps1"
