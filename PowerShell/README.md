# Backups aws sync bucket S3 - PowerShell
Backups - Script en Powershell para sincronizar datos locales a un bucket S3 (Simple Storage Service) de Amazon Web Services a través de la interfaz de línea de comandos de AWS (AWSCLI).

- 1. Se genera un fichero log de todo el proceso.
- 2. Con awscli se sincronizan los datos locales con el objeto (carpeta/directorio) del bucket S3.
- 3. Se envía el fichero de log vía Email desde el smtp de una cuenta de correo Gmail.

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

4. Previamente se deberá crear un usuario de IAM con permisos en la política "AmazonS3FullAccess" y establecer las keys en AWSCLI. En un entorno Windows estas keys quedarán almacenadas en el fichero %userprofile%\.aws\credentials.

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
- $passwdEmailFile = "pathFicheroPassword.pass"
- $asuntoEmail = "asuntoEmail"
- $cuerpoEmail = Será el contenido del fichero de log adjunto en el envío del mail. 

En el script *"backup-aws-S3.ps1"* se pueden ver varias alternativas con el cmdlet *Get-Content* y el namespace *System.io* usando el método *File.ReadAllText* esto hará que el texto adjunto en el cuerpo del mail se visualice de igual forma que fichero de log origen, respetando los saltos de línea.

#### **Prerrequisito: Crear un fichero con la password cifrada**

Una forma de evitar escribir una password en texto plano en un script ps1, es generar un fichero que contendrá el hash AES256 correspondiente a la string de la password cifrada. 

En la variable anterior *$passwdEmailFile* se indicará el path donde se almacene dicho fichero.

```
"MiPassword" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "C:\PATH\backup-aws-s3.pass"
```

**_Aclaraciones_**

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

- Referencia CLI aws s3 sync: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html

### Envío log cuenta Gmail (Google)
Para el envío del log vía Gmail es necesario activar el acceso a "Aplicaciones menos seguras" en la cuenta Google. Por seguridad, se debería crear una cuenta específica para esta finalidad.
https://myaccount.google.com/lesssecureapps

![Aplicaciones menos seguras Google](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-bucket-S3-Bash-PowerShell/master/screenshots/ejecucion_app_menos_seguras_gmail.png)

![Envio Email Log Gmail Powershell](https://raw.githubusercontent.com/adrianlois/Backups-aws-sync-bucket-S3-Bash-PowerShell/master/screenshots/envio_email_backup_log_gmail_powershell.png)

### Llamada a fichero PowerShell .ps1 desde un fichero de proceso por lotes .bat
Si queremos crear una tarea programada en Windows (taskschd.msc) para la ejecución automatizada de backups a AWS S3. La forma más efectiva sería establecer directamente un fichero de proceso por lotes .bat y que este llame al fichero PowerShell .ps1.

**backup-aws-s3-trigger.bat**: modificar la variable para establecer el path donde se encuentra el fichero .ps1

- pathLocalPs1="pathLocalFichero.ps1"

#### MountDismountUSB_VeeamBackup
Scripts en versiones PowerShell y Batch para montar y desmontar el dispositivo USB extraíble durante el tiempo en el que se realiza el segundo backup con Veeam Backup. 