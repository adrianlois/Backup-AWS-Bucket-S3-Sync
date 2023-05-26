# Backup AWS Sync S3 - PowerShell

<div align="center">
<img src="https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3/master/screenshots/backup-aws-sync-bucket-s3.png" width="300" />
</div>

## Índice

- [Descripción](#descripcion)
- [Requisitos previos](#requisitos-previos)
  - [Política de permisos en AWS S3](#política-de-permisos-en-aws-s3)
  - [Identity and Access Management - IAM](#identity-and-access-management-iam)
  - [Configuración "Access Key" y "Secret Access key"](#configuración-access-key-y-secret-access-key)
- [Descripción de Funciones: Backup-AWS-S3.ps1](#descripción-de-funciones-backup-aws-s3-ps1)
  - [Set-USBDriveMount](#set-usbdrivemount)
  - [Set-USBDriveUnmount](#set-usbdriveunmount)
  - [Compress-7ZipEncryption](#compress-7zipencryption)
  - [Invoke-BackupAWSS3](#invoke-backupawss3)
  - [Send-EmailMessageAndDocument](#send-emailmessageanddocument)
  - [Send-TelegramBotMessageAndDocument](#send-telegrambotmessageanddocument)
- [USBDrive-MountUnmount](#usbdrive-mountunmount)
- [PasswdBackup](#passwdbackup)
- [Recuperación Backup: S3 a Local](#recuperación-backup-s3-a-local)

## Descripción

Script en Powershell para automatizar el proceso de sincronización de datos locales a un bucket S3 (Simple Storage Service) de Amazon Web Services a través de la interfaz de línea de comandos de AWSCLI.

- Funciones específicas para montar y desmontar unidades externas USB donde se almacenarán las copias de Veeam Backup. 
- Realizar una compresión 7zip cifrada de forma simétrica, usando adicionalmente un método de capas de ficheros comprimidos para almacenar la BBDD + key file de KeePassXC.
- Sincronizar con AWS CLI los datos locales con el objeto (carpeta/directorio) del bucket S3.
- Generar un fichero log de todo el proceso.
- Enviar el fichero de log vía Email.
- Enviar el fichero de log, contenido en formato de mensaje o ambas vía ChatBot de Telegram.

## Requisitos previos
### Política de permisos en AWS S3

> Por seguridad en la automatización de este tipo de "backups" (o mejor dicho sincronización en este caso) NO se recomienda usar un usuario raíz y con acceso a la consola de AWS.

Se creará un usuario específico para este fin únicamente con los permisos y accesos necesarios.

### Identity and Access Management (IAM)
1. Crear un nuevo usuario con las siguientes condiciones:
- Sin ningún tipo de privilegio administrativo, tampoco podrá iniciar sesión en la consola de administración de AWS.
- Solo se podrá conectar a través de su ID y clave de acceso (será la que se establezca posteriormente en el fichero *%USERPROFILE%\\.aws\credentials*).

![Credenciales sesion usuario aws](https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3/master/screenshots/credenciales_sesion_usuario_aws.png)

2. Crear una nueva política donde solo se especifique:
- Servicio: S3
- Acciones: Enumeration (ListBucket), Escritura (DeleteObject, PutObject)
- Recursos: Especificar únicamente el recuro ARN del bucket y un "BucketS3Name/*" que aplicarán a todos los objetos dentro de ese bucket.

Resumen de la política - JSON

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

### Configuración "Access Key" y "Secret Access key"

3. [Instalación de AWSCLI en Windows](https://docs.aws.amazon.com/es_es/cli/latest/userguide/install-windows.html).

4. Establecer las access keys en AWSCLI. En un entorno Windows estas keys quedarán almacenadas en el fichero %userprofile%\.aws\credentials.

```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMIWK7MDENG/bPERfiCYEXAMPLEKEY
Default region name [None]: eu-south-2
Default output format [None]: json
```

## Descripción de Funciones: Backup-AWS-S3.ps1
### **Set-USBDriveMount**

Esta función monta una unidad externa USB que será necesaria para almacenar la primera copia que se realizarán por parte de [Veeam Backup](https://www.veeam.com/es/windows-endpoint-server-backup-free.html). Esto podría aplicarse a cualquier otro software de backup.

Para conocer y obtener previamente el GUID de un volumen ejecutamos en una consola "mountvol".

Parámetros de la función.

- *DriveLetter*: Letra de asignación de la unidad o volumen a montar en el sistema.
- *Guid*: Indentificador global correspondiente al volumen de disco correspondiente a la unidad externa a montar en el sistema.

```ps
Set-USBDriveMount -DriveLetter "X" -Guid "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
```

### **Set-USBDriveUnmount**

Esta función se ejecutará al final de todo el proceso, desmontará la unidad externa USB montada anteriormente en el principio del flujo de ejecución de la función "Set-USBDriveMount".

Parámetro de la función.

- *Seconds*: Tiempo en segundos que estará la unidad externa USB montada antes de ser desmontada del sistema. 

```ps
Set-USBDriveUnmount -Seconds "XXXX"
```

### **Compress-7ZipEncryption**

Esta función comprime de forma cifrada en formato 7z (7zip) y usando un método por capas los ficheros relacionados con la BBDD (kdbx) + key file (keyx) de KeePassXC.

¿Por qué usar el módulo 7zip y no Compress-Archive en formato Zip (System.IO.Compression.ZipArchive)?

Respuesta: https://www.sans.org/blog/powershell-7-zip-module-versus-compress-archive-with-encryption/

1. Instalar módulo 7Zip4Powershell.
```ps
Install-Module -Name 7Zip4Powershell
Import-Module -Name 7Zip4Powershell
```

2. Crear los ficheros con la password cifrada que se usarán para todas compresiones de estos ficheros. Deben respetarse los nombres de salida para que coincida con el de la función.

En caso de que se necesite establecer nombres distintos será necesario cambiarlos manualmente en la propia función.

```ps
"Passw0rd.Kdbx" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\Passwd7zKdbx"
"Passw0rd.Keyx" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\Passwd7zKeyx"
"Passw0rd.Kpxc" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\Passwd7zKpxc"
```

Parámetros de la función.

- *PathKdbx*: Ruta del fichero de la BBDD de KeePassXC .kdbx
- *PathKeyx*: Ruta del fichero de la key file de KeePassXC .keyx, en el caso de que se hubiera establecido en la creación de la BBDD.
- *File7zKpxc*: Ruta local del fichero final ya comprimido.
- *RemoteFile7zKpxc*: Ruta remota donde se moverá del fichero final ya comprimido.
- *PasswdFilePath*: Ruta de la carpeta donde se guardarán los ficheros que almacenan las contraseñas cifradas usadas en el proceso de compresión.
- *WorkPathTemp*: Ruta temporal donde se realizará el proceso aislado de compresión. Se recomienda crear una carpeta Temp en el mismo directorio donde se ejecute el script.

```ps
Compress-7ZipEncryption -PathKdbx "C:\PATH\file.kdbx" -PathKeyx "C:\PATH\file.keyx" `
                        -File7zKpxc "C:\PATH\file.7z" -RemoteFile7zKpxc "H:\PATH\Datos" `
                        -PasswdFilePath "C:\PATH\PasswdBackup\" -WorkPathTemp "C:\PATH\Temp\"
```

### **Invoke-BackupAWSS3**

Esta función sincroniza los ficheros y directorios de una o varias rutas locales origen a un destino en un bucket S3 de AWS.

Parámetros de la función.

- *SourcePathLocalData*: Ruta absoluta del fichero "PathLocalData.txt", en este fichero se especifican los directorios donde será el origen de sincronización al bucket S3. Especificar los paths necesarios en  nuevas líneas.
- *RemotePathBucketS3*: Ruta destino del bucket S3 donde se almacenerá y realizará la sincronización de paths locales especificados en el fichero PathLocalData.txt.  
- *WorkPath*: Ruta absoluta raíz donde se realizará y tomará de referencia para el proceso de sincronización así como la creación del fichero de log que se creará en la tarea de sincronización.

```ps
Invoke-BackupAWSS3 -SourcePathLocalData "C:\PATH\PathLocalData.txt" -RemotePathBucketS3 "s3://BucketS3Name/Backup" -WorkPath "C:\PATH\"
```

**Fichero PathLocalData.txt**

Formato de ejemplo de las rutas locales establecidas para realizar el proceso de sincronización.

```
C:\PATH_1\Datos
C:\PATH_2\Fotos
H:\PATH_3\Videos
J:\PATH_4\Musica
```

**aws s3 sync**

Verifica si uno o más ficheros y/o directorios locales existentes se han actualizado comprobando su nombre, tamaño y el timestamp. Actualmente no creo que compruebe los cambios en los hashes del fichero.

- *--sse AES256*: Server Side Encryption, especifica un cifrado AES256 del lado del servidor para los objetos S3.
- *--delete*: Elimina los ficheros/directorios en el bucket S3 (RemotePathBucketS3) que ya no existan en el origen (SourcePathLocalData).
- *--include*: Incluye los ficheros en la sincronización. En este caso indicando "*" incluiría todo.
- *--exclude*: Excluye ficheros en la sincronización. En este caso omite los ficheros "*.DS_Store" generados automáticamente en sistemas MacOS. Este parámetro es opcional.

- Referencia AWS CLI S3 Sync: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html

```ps
Invoke-BackupAWSS3 -SourcePathLocalData "C:\PATH\PathLocalData.txt" -RemotePathBucketS3 "s3://BucketS3Name/Backup" -WorkPath "C:\PATH\"
```

### **Send-EmailMessageAndDocument**

Esta función envía un correo del fichero de log adjunto y su contenido vía procolo SMTP de Outlook. 

> Por seguridad Gmail ya no permite esta opción. https://support.google.com/accounts/answer/6010255

1. Crear el fichero con la password cifrada que será usada para la autenticación de la cuenta de correo de Outlook. Deben respetarse los nombres de salida para que coincida con el de la función.

```ps
"Passw0rd.Email" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\PasswdEmail"
```

- *-UserFromEmail*: Dirección de correo que enviará el mensaje (se usará las credenciales de autenticación y el SMTP de Outook).
- *-UserToEmail*: Dirección de correo destinaría que recibirá el mensaje.

```ps
Send-EmailDocumentAndMessage -UserFromEmail "userFrom@outlook.es" -UserToEmail "userTo@gmail.com"
```

![Envio Email Backup Log Outlook-Gmail](https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3-Bash-PowerShell/master/screenshots/envio_email_backup_log_gmail_powershell.png)

### **Send-TelegramBotMessageAndDocument**

Esta función envía una notificación del fichero de log y su contenido adjunto vía ChatBot de Telegram. Según los parámetros especificados en la función es posible enviar el fichero de log adjunto y también el tiempo de comienzo y tiempo total transcurrido del proceso de backup o enviar el fichero adjunto y también el contenido del fichero en formato de mensaje al ChatBot. 

Esta función es compatible con versiones de PowerShell 6.1.0 o superiores.

1. Instalar PowerShell versión 7.3 (*pwsh.exe*):

- https://learn.microsoft.com/es-es/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3

2. Añadir el bot de [@BotFather](https://t.me/botfather) y crear un nuevo bot y obtener su Token. Establecer un nombre de bot y un user_bot.
```
/newbot
```
Establecer una imagen a mostrar para para el bot.
```
/mybots > seleccionamos el bot > edit bot > edit botpic > cargamos la imagen como como foto.
```

3. Para obtener el ChatID de nuestro usuario de Telegram agremos el bot [@MyIDBot](https://telegram.me/myidbot) o [@RawDataBot](https://telegram.im/@rawdatabot).
```
/getid
```

Parámetros de la función. Diferencias entre establecer **SendMessage** y **SendDocument**.

- *BotToken*: Token del bot generado con @BotFather.
- *ChatID*: ID de chat obtenido con @RawDataBot o @MyIDBot.
- *SendMessage*: Si este parámetro está presente enviará solamente el contenido del fichero backup log en formato de texto al ChatBot.
- *SendDocument*: Si este parámetro está presente enviará al ChatBot el fichero de backup log adjunto y también enviará formato texto la fecha y hora del comienzo de backup y el tiempo total transcurrido del proceso de sincronización con el bucket S3.

- -SendDocument  

```ps
Send-TelegramBotMessageAndDocument -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendDocument
```
![Envio Telegram Bot fichero backup log SendDocument](https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3/master/screenshots/envio_telegrambot_backup_log_powershell_sendDocument.png)

- -SendMessage

```ps
Send-TelegramBotMessageAndDocument -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendMessage
```
![Envio Telegram Bot fichero backup log SendMessage](https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3/master/screenshots/envio_telegrambot_backup_log_powershell_sendMessage.png)

- -SendMessage y -SendDocument

```ps
Send-TelegramBotMessageAndDocument -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendMessage -SendDocument
```
![Envio Telegram Bot fichero backup log SendMessage y SendDocument](https://raw.githubusercontent.com/adrianlois/Backup-AWS-Sync-Bucket-S3/master/screenshots/envio_telegrambot_backup_log_powershell_sendMessageDocument.png)

## Backup-AWS-S3-Trigger.bat

Esto llamará a un fichero PowerShell .ps1 desde un fichero de proceso por lotes .bat. Establecer el path donde se encuentra el fichero Backup-AWS-S3.ps1.

Si creamos una tarea programada en Windows (taskschd.msc) para una ejecución programada, la forma más efectiva sería establecer directamente un fichero de proceso por lotes .bat y que este llame al fichero PowerShell .ps1 donde cargará e invocará al resto de funciones.

## USBDrive-MountUnmount
### Set-USBDriveMountUnmount.ps1

Podemos usar el script *Set-USBDriveMountUnmount.ps1* en el caso de no querer realizar en el mismo flujo de ejecución el proceso de montaje y desmontaje del dispositivo externo USB utilizado para el alamacenamiento de copias de Veeam Backup.

Será necesario crear otra tarea programada para controlar los tiempos de espera en el montaje y desmontaje del volumen. 

Esto sería una alternativa de control independiente a las funciones *Set-USBDriveMount* y *Set-USBDriveUnmount* indicadas en script principal Backup-AWS-S3.ps1.

### USBDrive-UnmountStartSystem.bat

Este script se llamará desde una nueva tarea programada en la cual los desencadenadores de ejecución serían: "cada inicio nuevo de sistema" y "primer inicio de sesión". Asegurando así que la unidad externa USB no se monte de forma automática por el sistema tras estos eventos.

## PasswdBackup
### New-PasswdFile.ps1

Este script automatizará el proceso de creación de los ficheros de password cifradas que serán utilizados en las funciones *Compress-7ZipEncryption* y *Send-EmailDocumentAndMessage*.

# Recuperación Backup: S3 a Local

Copiar ficheros y directorios del bucket S3 a local.

Si realimos este proceso con el mismo usuario de AWS que estamos usando para la sincronización, será necesario otorgarle permisos adicionales para poder descargar ficheros y carpetas desde un bucket S3 a local.

Referencia AWS CLI S3 cp: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/cp.html

```
aws s3 cp s3://bucket/backup/ <LOCAL_PATH> --recursive
```