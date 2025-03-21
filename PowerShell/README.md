<h1 align="center">Backup AWS Bucket S3 Sync - PowerShell</h1>

<div align="center">
  <img src="../screenshots/backup_aws_bucket_s3_sync_logo.png" width="350" />
</div>

<h1>Índice</h1>

- [Descripción](#descripción)
- [Requisitos previos](#requisitos-previos)
  - [Política de permisos en AWS S3](#política-de-permisos-en-aws-s3)
  - [Identity and Access Management (IAM)](#identity-and-access-management-iam)
  - [Configuración "Access Key" y "Secret Access key"](#configuración-access-key-y-secret-access-key)
  - [Configuración de VeraCrypt para el uso de KeePassXC](#configuración-de-veracrypt-para-el-uso-de-keepassxc)
  - [Cambiar la ubicación predeterminada de los archivos *config* y *credentials* de AWS CLI para su uso desde VeraCrypt](#cambiar-la-ubicación-predeterminada-de-los-archivos-config-y-credentials-de-aws-cli-para-su-uso-desde-veracrypt)
- [Descripción de Funciones: Backup-AWS-S3.ps1](#descripción-de-funciones-backup-aws-s3ps1)
  - [Set-USBDriveMount](#set-usbdrivemount)
  - [Set-USBDriveUnmount](#set-usbdriveunmount)
  - [Set-VeraCryptMount](#set-veracryptmount)
  - [Set-VeraCryptUnmount](#set-veracryptunmount)
  - [Compress-7ZipEncryption](#compress-7zipencryption)
  - [Invoke-BackupAWSS3](#invoke-backupawss3)
  - [Send-TelegramBotMessageAndDocument](#send-telegrambotmessageanddocument)
  - [Send-EmailMessageAndDocument](#send-emailmessageanddocument)
- [Backup-AWS-S3-Trigger.bat](#backup-aws-s3-triggerbat)
- [USBDrive-MountUnmount](#usbdrive-mountunmount)
  - [Invoke-USBDriveMountUnmount.ps1](#invoke-usbdrivemountunmountps1)
  - [USBDrive-UnmountStartSystem.bat](#usbdrive-unmountstartsystembat)
- [Start-VeraCrypt-KPXC](#start-veracrypt-kpxc)
  - [Start-VeraCrypt-KPXC.ps1](#start-veracrypt-kpxcps1)
- [PasswdBackup](#passwdbackup)
  - [New-PasswdFile.ps1](#new-passwdfileps1)
- [Recuperación Backup: S3 a Local](#recuperación-backup-s3-a-local)

## Descripción

Script en Powershell para automatizar el proceso de sincronización de datos locales a un bucket S3 (Simple Storage Service) de Amazon Web Services a través de la interfaz de línea de comandos de AWSCLI.

▶ Funciones específicas para montar y desmontar unidades externas USB donde se almacenarán las copias de Veeam Backup.

▶ Funciones para gestionar volúmenes virtuales cifrados que aíslan de forma independiente los archivos kdbx, keyx de KeePassXC, y los archivos config y credentiales de .aws para la conexión con AWS CLI, manteniéndolos fuera del alcance del sistema operativo.

▶ Realizar compresiones 7zip cifrada de forma simétrica, usando adicionalmente un método de capas de archivos comprimidos para almacenar la BBDD (kdbx) y el archivo con la clave de seguridad adicional (keyx) de KeePassXC.

▶ Sincronizar con AWS CLI archivos locales a un bucket S3.

▶ Generar un archivo log de todo el proceso.

▶ Enviar el archivo de log vía Email.

▶ Enviar el archivo de log, contenido en formato de mensaje o ambas vía ChatBot de Telegram.

## Requisitos previos
### Política de permisos en AWS S3

> [!NOTE]
> Por seguridad en la automatización de sincronización de este tipo de backups NO se recomienda usar un usuario raíz y con acceso a la consola de AWS.

Se creará un usuario específico para este fin únicamente con los permisos y accesos necesarios.

### Identity and Access Management (IAM)
1. Crear un nuevo usuario con las siguientes condiciones:
- Sin ningún tipo de privilegio administrativo, tampoco podrá iniciar sesión en la consola de administración de AWS.
- Solo se podrá conectar a través de su ID y clave de acceso, será la que se establezca en el archivo *%USERPROFILE%\\.aws\credentials*.
  - [Mejorar la seguridad local de acceso a estos ficheros](#cambiar-la-ubicación-predeterminada-de-los-archivos-config-y-credentials-de-aws-cli-para-su-uso-desde-veracrypt).

![Credenciales sesion usuario aws](../screenshots/credenciales_sesion_usuario_aws.png)

2. Crear una nueva política donde solo se especifique:
- Servicio: S3
- Acciones y efecto: Permitir enumerar objetos, pero no acceder a los datos de los objetos directamente (ListBucket), permitir cargar objetos (PutObject) y permitir eliminar objetos (DeleteObject).
- Recursos: Especificar únicamente el recurso ARN del bucket S3 "BucketS3Name/folder1/*" que aplicará a todos los objetos dentro de ese directorio. Esto asegura que el usuario no podrá crear ni eliminar objetos en ninguna otra parte del bucket, fuera del prefijo folder1.
  - *BucketS3Name*: Nombre del bucket S3.
  - *Folder1*: Nombre del directorio raíz donde se almacenan los objetos del backup a sincronizar.

**Resumen de la política - JSON**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListBucketWithPrefix",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::BucketS3Name",
            "Condition": {
                "StringLike": {
                    "s3:prefix": "Folder1/*"
                }
            }
        },
        {
            "Sid": "ObjectLevelActions",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::BucketS3Name/Folder1/*"
        }
    ]
}
```

### Configuración "Access Key" y "Secret Access key"

3. [Instalación de AWSCLI en Windows](https://docs.aws.amazon.com/es_es/cli/latest/userguide/install-windows.html).

4. Establecer las access keys en AWSCLI. En un entorno Windows estas keys, por defecto quedarán almacenadas en el archivo "%userprofile%\.aws\credentials" y la configuración de región en "%userprofile%\.aws\config".

> [!NOTE]
> Aunque estas claves sean accesibles para el usuario local, no representan un riesgo, ya que los permisos establecidos solo permiten subir archivos al bucket S3, sin opción de descargarlos.
> 
> Más adelante se comenta como añadir una capa extra para [mejorar la seguridad local de acceso a estos ficheros](#cambiar-la-ubicación-predeterminada-de-los-archivos-config-y-credentials-de-aws-cli-para-su-uso-desde-veracrypt).


```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMIWK7MDENG/bPERfiCYEXAMPLEKEY
Default region name [None]: eu-south-2
Default output format [None]: json
```

### Configuración de VeraCrypt para el uso de KeePassXC

En un gestor de contraseñas local como [KeePassXC](https://keepassxc.org/download/#windows), lo habitual es almacenar localmente la base de datos (kdbx) junto con la clave de seguridad adicional (keyx). Aunque el archivo kdbx es seguro, si el sistema se compromete, un atacante podría acceder a estos archivos. En caso de un ataque de Ransomware que cifre esta información, existe el backup síncrono en la nube para su recuperación. 

No obstante, este enfoque añade una capa extra de aislamiento (sandboxing) para proteger estos archivos. Un posible atacante o ransomware, en un primer momento, solo tendría acceso a los archivos de contenedores en formato .hc de VeraCrypt, los cuales ya están protegidos con un cifrado simétrico AES usando una contraseña robusta.

Con [VeraCrypt](https://www.veracrypt.fr/en/Downloads.html), se crean dos contenedores cifrados en volúmenes virtuales independientes: uno para el archivo kdbx (kpxc_kdbx.hc) y otro para el keyx (kpxc_keyx.hc). Cada uno protegido con un cifrado simétrico AES y una contraseña robusta. Estos volúmenes solo se montan cuando se inicia KeePassXC, asignando una letra de unidad a cada uno, y se desmontan al cerrar KeePassXC, quedando inaccesibles cuando no están en uso y fuera del alcance directo del sistema operativo.

Todo este proceso se automatiza con el script, que se invoca a través de un acceso directo configurando la ruta de destino para llamar a este script.

Para un uso habitual de KeePassXC. El script [Start-VeraCrypt-KPXC.ps1](#start-veracrypt-kpxcps1) automatiza todo el proceso. Se invoca a través de un acceso directo, estableciendo la ruta de destino para llamar a dicho script.

**Configuración de las preferencias de VeraCrypt:**

- Opciones de montaje predeterminadas:
  - Desactivar: Montar volúmenes como medios extraíbles (https://veracrypt.eu/en/Removable%20Medium%20Volume.html)
- VeraCrypt en segundo plano:
  - Activar: Salir cuando no haya volúmenes montados.
- Desmontar automáticamente. Desmontar todo cuando: 
  - Activar: El usuario cierra sesión.
  - Activar: La sesión del usuario es bloqueada.
  - Activar: Cuando se activa el salvapantallas.
  - Activar: Forzar desmontaje automático aunque el volumen tenga archivos abiertos.
- Activar: No mostrar el mensaje de espera mientras se realizan operaciones.
- Caché de contraseñas: 
  - Activar: Eliminar contraseñas guardadas al salir.
  - Activar: Eliminar contraseñas guardadas al desmontar automáticamente.

### Cambiar la ubicación predeterminada de los archivos *config* y *credentials* de AWS CLI para su uso desde VeraCrypt

Siguiendo el principio de aislamiento aplicado en el caso del alamacenamiento de los archivos de KeePassXC, en caso de un incidente de seguridad tipo ransomware o simplemente que se puedan ver comprometidos. Los archivos config y credentials de AWS CLI se almacenarán en un volumen cifrado de VeraCrypt, manteniéndolos inaccesibles e independientes del sistema, excepto en el momento de ejecutarse el script de backup programado.

Por defecto, estos archivos estarán ubicados en:
- %USERPROFILE%\\.aws\config
- %USERPROFILE%\\.aws\credentials

Para evitar que un atacante acceda a la "aws_secret_access_key" y "aws_access_key_id" en el archivo credentials, se almacenarán en un volumen de VeraCrypt. Para ello, se configurarán variables de entorno para que AWS CLI acceda a ellos desde su nueva ubicación.

**Establecer nuevas variables de entorno para los archivos *config* y *credentials***

Se establecen las siguientes variables de entorno a nivel de usuario para [redirigir la ruta de los archivos "config" y "credentials" de AWS CLI](https://docs.aws.amazon.com/sdkref/latest/guide/file-location.html).

- AWS_CONFIG_FILE: Variable de entorno del archivo de "config".
- AWS_SHARED_CREDENTIALS_FILE: Variable de entorno del archivo de "credentials".

Previamente, se copian los archivos config y credentials a uno de los volúmenes de VeraCrypt (Z:\\).

```ps
setx AWS_CONFIG_FILE Z:\config
setx AWS_SHARED_CREDENTIALS_FILE Z:\credentials
```

Cerramos la sesión de PowerShell para actualizar los cambios y verificamos que AWS CLI accede a las nuevas rutas.

```ps
echo $Env:AWS_SHARED_CREDENTIALS_FILE
echo $Env:AWS_CONFIG_FILE
```
```ps
aws configure list
```

## Descripción de Funciones: Backup-AWS-S3.ps1
### Set-USBDriveMount

Esta función monta una unidad externa USB que será necesaria para almacenar la primera copia que se realizarán por parte de [Veeam Backup](https://www.veeam.com/es/windows-endpoint-server-backup-free.html). Esto podría aplicarse a cualquier otro software de backup.

Para conocer y obtener previamente el GUID de un volumen ejecutamos en una consola "mountvol".

**Parámetros de la función:**

- *DriveLetter*: Letra de asignación de la unidad o volumen a montar en el sistema.
- *Guid*: Indentificador global correspondiente al volumen de disco correspondiente a la unidad externa a montar en el sistema.

```ps
Set-USBDriveMount -DriveLetter "X" -Guid "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
```

### Set-USBDriveUnmount

Esta función se ejecutará al final de todo el proceso, desmontará la unidad externa USB montada anteriormente en el principio del flujo de ejecución de la función "Set-USBDriveMount".

**Parámetro de la función:**

- *Seconds*: Tiempo en segundos que estará la unidad externa USB montada antes de ser desmontada del sistema. 

```ps
Set-USBDriveUnmount -Seconds "XXXX"
```

### Set-VeraCryptMount

Esta función monta los volúmenes .hc de VeraCrypt que almacenan los archivos KeePassXC (kdbx y keyx) y los archivos de configuración de AWS CLI (config y credentials). Luego, se invoca la función [Compress-7ZipEncryption](#compress-7zipencryption) y, una vez finalizado ese proceso, se llama a la función [Set-VeraCryptUnmount](#set-veracryptunmount).

Crear los archivos con la password cifrada que se usarán para montar los volúmenes de VeraCrypt.

```ps
"Passw0rd.VCKdbx" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\PasswdVCKdbx"
"Passw0rd.VCKeyx" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\PasswdVCKeyx"
```

**Parámetros de la función:**

- *PasswdFilePath*: Ruta de la carpeta donde se guardan los archivos que contienen las contraseñas cifradas utilizadas en el proceso de compresión.
- *VCFilePath*: Ruta de los archivos de volúmenes .hc de VeraCrypt.
- *DriveLetterVCKdbx*: Letra de unidad que se asigna al montar el volumen donde se almacena el archivo kdbx.
- *DriveLetterVCKeyx*: Letra de unidad que se asigna al montar el volumen donde se almacena el archivo keyx. 

```ps
Set-VeraCryptMount -PasswdFilePath "C:\PATH\PasswdBackup\" -VCFilePath "C:\PATH\VeraCrypt\" `
                   -DriveLetterVCKdbx "Y:" -DriveLetterVCKeyx "Z:"
```

**Parámetros de montaje VeraCrypt.exe:**
- */volume*: Especificar la ruta del volumen. En este caso, el archivo contenedor .hc.
- */letter*: Asigna una letra de unidad disponible al volumen establecido. 
- */password*: Establece la password para descifrar el volumen.
- */protectMemory*: Activa un mecanismo que protege la memoria del proceso VeraCrypt para que otros procesos que no sean administradores no puedan acceder a ella.
- */wipecache*: Borra todas las contraseñas almacenadas en caché en la memoria del controlador.
- */nowaitdlg*: No muestra el diálogo de espera mientras se realizan operaciones como montar volúmenes.
- */quit*: Realiza las acciones solicitadas en los parámetros anteriores sin mostrar la vetana de VeraCrypt y finalizar la aplicación al terminar.

> Referencia VeraCrypt (Command Line): https://veracrypt.eu/en/Command%20Line%20Usage.html

### Set-VeraCryptUnmount

Al finalizar el proceso de compresión y cifrado de los archivos relacionados con la base de datos (kdbx) y el archivo de clave (keyx) de KeePassXC en la función [Compress-7ZipEncryption](#compress-7zipencryption), y tras sincronizar los archivos hacia el bucket S3 en la función [Invoke-BackupAWSS3](#invoke-backupawss3), Set-VeraCryptUnmount desmonta los volúmenes de VeraCrypt y finaliza los procesos "VeraCrypt.exe" y "KeePassXC", que permanecen en segundo plano tras haberse iniciado previamente con la función [Set-VeraCryptMount](#set-veracryptmount) o al comprobar que ya estaban montados manualmente mediante el script [Start-VeraCrypt-KPXC.ps1](#start-veracrypt-kpxc).

**Parámetros de desmontaje VeraCrypt.exe:**
- */dismount*: Si no especifica ninguna letra de unidad, desmontará todos los volúmenes de VeraCrypt montados actualmente.
- */force*: Fuerza el desmontaje aunque tenga archivos en uso.  
- */wipecache*: Borra todas las contraseñas almacenadas en caché en la memoria del controlador.
- */history n*: Deshabilita guardar el historial de volúmenes montados
- */quit*: Realiza las acciones solicitadas en los parámetros anteriores sin mostrar la vetana de VeraCrypt y finalizar la aplicación al terminar.

> Referencia VeraCrypt (Command Line): https://veracrypt.eu/en/Command%20Line%20Usage.html

### Compress-7ZipEncryption

Esta función comprime de forma cifrada en formato 7z (7zip) y usando un método por capas los archivos relacionados con la BBDD (kdbx) + key file (keyx) de KeePassXC.

> [!NOTE]
> **¿Por qué usar el módulo 7zip y no Compress-Archive en formato Zip (System.IO.Compression.ZipArchive)?**
> 
> https://www.sans.org/blog/powershell-7-zip-module-versus-compress-archive-with-encryption/

1. Instalar módulo 7Zip4Powershell.
```ps
Install-Module -Name 7Zip4Powershell
Import-Module -Name 7Zip4Powershell
```

1. Crear los archivos con la password cifrada que se usarán para todas compresiones de estos archivos.

```ps
"Passw0rd.Kdbx" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\Passwd7zKdbx"
"Passw0rd.Keyx" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\Passwd7zKeyx"
"Passw0rd.Kpxc" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\Passwd7zKpxc"
```

**Parámetros de la función:**

- *PathKdbx*: Ruta del archivo de la BBDD kdbx de KeePassXC.
- *PathKeyx*: Ruta del archivo de de seguridad adicional keyx de KeePassXC.
- *File7zKpxc*: Ruta local del archivo final ya comprimido.
- *RemoteFile7zKpxc*: Ruta remota donde se moverá del archivo final ya comprimido.
- *WorkPathTemp*: Ruta temporal donde se realizará el proceso aislado de compresión. Se recomienda crear una carpeta Temp en el mismo directorio donde se ejecute el script.

```ps
Compress-7ZipEncryption -PathKdbx "Y:\file.kdbx" -PathKeyx "Z:\file.keyx" `
                        -File7zKpxc "C:\PATH\file.7z" -RemoteFile7zKpxc "H:\PATH\Datos\" `
                        -WorkPathTemp "C:\PATH\Temp\"
```

### Invoke-BackupAWSS3

Esta función sincroniza los archivos y directorios de una o varias rutas locales origen a un destino en un bucket S3 de AWS.

> [!NOTE]
> AWS CLI lee los archivos *config* y *credentials* desde un volumen de VeraCrypt previammente montado con [Set-VeraCryptMount](#set-veracryptmount), y tras ejecutar esta función, [Set-VeraCryptUnmount](#set-usbdriveunmount) los desmonta para dejarlos nuevamente inaccesibles.

**Parámetros de la función:**

- *SourcePathLocalData*: Ruta absoluta del archivo *PathLocalData.txt*, en este archivo se especifican los directorios donde será el origen de sincronización al bucket S3. Especificar las rutas necesarios en  nuevas líneas.
- *RemotePathBucketS3*: Ruta destino del bucket S3 donde se almacenerá y realizará la sincronización de las rutas locales especificados en el archivo *PathLocalData.txt*.  
- *WorkPath*: Ruta absoluta raíz donde se realizará y tomará de referencia para el proceso de sincronización así como la creación del archivo de log que se creará en la tarea de sincronización.

```ps
Invoke-BackupAWSS3 -SourcePathLocalData "C:\PATH\PathLocalData.txt" -RemotePathBucketS3 "s3://BucketS3Name/Backup" -WorkPath "C:\PATH\"
```

**Fichero PathLocalData.txt:**

Formato de ejemplo de las rutas locales establecidas para realizar el proceso de sincronización.

```
C:\PATH_1\Datos
C:\PATH_2\Fotos
H:\PATH_3\Videos
J:\PATH_4\Musica
```

**Parámetros de sincronización aws s3 sync - Local a S3:**

```ps
aws s3 sync "$($PathLocalData)" "$($RemotePathBucketS3 + $PathRelativeBucketS3)" --sse AES256 --delete --exact-timestamps --include "*" --exclude "*.DS_Store"
```

> [!NOTE]
> La identificación de cambios en los archivos al usar **aws s3 sync** se basa principalmente en comprobar su presencia en local y comparar su tamaño y fecha de última modificación. Cabe aclarar que no se realiza mediante el cálculo de hashes de los archivos.

- *aws s3 sync*: En este caso, sincroniza en forma de espejo los archivos locales a un bucket S3, creándolos o eliminándolos en S3 según sea necesario.
- *--sse AES256*: Server Side Encryption, especifica un cifrado AES256 del lado del servidor para los objetos S3.
- *--delete*: Elimina los archivos en el bucket S3 (RemotePathBucketS3) que ya no existan en el origen local (SourcePathLocalData).
- *--exact-timestamps*: Conserva las fechas originales de los archivos al sincronizarlos desde un bucket S3 a local, asegurando que las marcas de tiempo de modificación se mantengan exactas.
- *--include*: Incluye los archivos en la sincronización. En este caso indicando "*" incluiría todo.
- *--exclude*: Excluye archivos en la sincronización. En este caso, omite los archivos "*.DS_Store", generados automáticamente por sistemas macOS. Este parámetro es opcional.

> Referencia AWS CLI S3 Sync: https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html

```ps
Invoke-BackupAWSS3 -SourcePathLocalData "C:\PATH\PathLocalData.txt" -RemotePathBucketS3 "s3://BucketS3Name/Backup" -WorkPath "C:\PATH\"
```

### Send-TelegramBotMessageAndDocument

Esta función envía una notificación del archivo de log y su contenido adjunto vía ChatBot de Telegram. Según los parámetros especificados en la función es posible enviar el archivo de log adjunto y también el tiempo de comienzo y tiempo total transcurrido del proceso de backup o enviar el archivo adjunto y también el contenido del archivo en formato de mensaje al ChatBot. 

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

**Parámetros de la función:**

- *BotToken*: Token del bot generado con @BotFather.
- *ChatID*: ID de chat obtenido con @RawDataBot o @MyIDBot.
- *SendMessage*: Si este parámetro está presente enviará solamente el contenido del archivo backup log en formato de texto al ChatBot.
- *SendDocument*: Si este parámetro está presente enviará al ChatBot el archivo de backup log adjunto y también enviará formato texto la fecha y hora del comienzo de backup y el tiempo total transcurrido del proceso de sincronización con el bucket S3.

Diferencias entre establecer **SendMessage** y **SendDocument**:

- -SendDocument  

```ps
Send-TelegramBotMessageAndDocument -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendDocument
```
![Envio Telegram Bot archivo backup log SendDocument](../screenshots/envio_telegrambot_backup_log_powershell_sendDocument.png)

- -SendMessage

```ps
Send-TelegramBotMessageAndDocument -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendMessage
```
![Envio Telegram Bot archivo backup log SendMessage](../screenshots/envio_telegrambot_backup_log_powershell_sendMessage.png)

- -SendMessage y -SendDocument

```ps
Send-TelegramBotMessageAndDocument -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendMessage -SendDocument
```
![Envio Telegram Bot archivo backup log SendMessage y SendDocument](../screenshots/envio_telegrambot_backup_log_powershell_sendMessageDocument.png)

### Send-EmailMessageAndDocument

Esta función envía un correo del archivo de log adjunto y su contenido vía procolo SMTP de Outlook. 

> [!NOTE]
> Por seguridad Gmail ya no permite esta opción. https://support.google.com/accounts/answer/6010255

1. Crear el archivo con la password cifrada que será usada para la autenticación de la cuenta de correo de Outlook. Deben respetarse los nombres de salida para que coincida con el de la función.

```ps
"Passw0rd.Email" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -Encoding utf8 "C:\PATH\PasswdBackup\PasswdEmail"
```

- *-UserFromEmail*: Dirección de correo que enviará el mensaje (se usará las credenciales de autenticación y el SMTP de Outook).
- *-UserToEmail*: Dirección de correo destinaría que recibirá el mensaje.

```ps
Send-EmailDocumentAndMessage -UserFromEmail "userFrom@outlook.es" -UserToEmail "userTo@gmail.com"
```

![Envio Email Backup Log Outlook-Gmail](../screenshots/envio_email_backup_log_powershell.png)

## Backup-AWS-S3-Trigger.bat

Esto llamará a un archivo PowerShell .ps1 desde un archivo de proceso por lotes .bat. Establecer la ruta donde se encuentra el archivo Backup-AWS-S3.ps1.

Si creamos una tarea programada en Windows (taskschd.msc) para una ejecución programada, la forma más efectiva sería establecer directamente un archivo de proceso por lotes .bat y que este llame al archivo PowerShell .ps1 donde cargará e invocará al resto de funciones.

## USBDrive-MountUnmount
### Invoke-USBDriveMountUnmount.ps1

Es posible separar el proceso de montaje y desmontaje del dispositivo USB externo para adaptarlo a factores como la duración del tiempo de montaje o la necesidad de cambiar el contexto de privilegios de usuario. Esto sirve como alternativa a las funciones *Set-USBDriveMount* y *Set-USBDriveUnmount* del script *Backup-AWS-S3.ps1*, utilizando solo esas funciones en el script *Invoke-USBDriveMountUnmount.ps1* de manera autónoma.

Para montar unidades con mountvol se requieren privilegios administrativos, pero no para el resto de funciones del script. Usar un usuario sin privilegios en el día a día es una práctica segura, y este enfoque permite separar las acciones en dos tareas programadas: una con privilegios para el montaje y otra sin ellos para las demás funciones.

Implementar esta solución implica crear una tarea programada adicional que ejecute Invoke-USBDriveMountUnmount.ps1. Esto permitirá controlar eficazmente los tiempos de espera durante el montaje y desmontaje del volumen, asegurando que cada acción se ejecute con el nivel de privilegios adecuado.

### USBDrive-UnmountStartSystem.bat

Este script se ejecutará mediante una nueva tarea programada creada en un contexto de privilegios elevados en el Programador de tareas (taskschd.msc). 

Los desencadenadores configurados serán: "al iniciar el sistema" y "en el primer inicio de sesión". Esto garantiza que la unidad externa USB no sea montada automáticamente por el sistema tras estos eventos.

## Start-VeraCrypt-KPXC
### Start-VeraCrypt-KPXC.ps1

Este script trabajar con KeePassXC en el día a día, auto monta los dos volúmenes virtuales de VeraCrypt donde se almacena la base de datos (kdbx) y el archivo de seguridad adicional (keyx). Después de verificar que los volúmenes están montados, inicia KeePassXC y, al cerrarlo, auto desmonta los volúmenes de VeraCrypt para que queden nuevamente inaccesibles a nivel del sistema.

Adicionalmente, realiza las comprobaciones necesarias para detectar si KeePassXC está en ejecución y/o si los volúmenes están previamente montados, con la finalidad de evitar posibles conflictos de condición de carrera entre los procesos.

  **KeePassXC.lnk.txt** (acceso directo)

Para poder ejecutar KeePassXC de forma cómoda a través de este script, se puede iniciar a través de un acceso directo con el siguiente los siguientes parámetros de desinto para invocarlo, y cambiar el icono por el de KeePassXC.

```ps
"C:\Program Files\PowerShell\7\pwsh.exe" -WindowStyle Hidden -ExecutionPolicy Bypass -File "LOCAL_PATH\Start-VeraCrypt-KPXC.ps1"
```

## PasswdBackup
### New-PasswdFile.ps1

Este script automatizará el proceso de creación de los archivos de password cifradas que serán utilizados en las funciones: *Set-VeraCryptMount*, *Compress-7ZipEncryption* y *Send-EmailDocumentAndMessage*.

## Recuperación Backup: S3 a Local

Copiar archivos desde un bucket S3 a una ubicación local.

**Opción 1**

Si realizamos este proceso con el mismo usuario de AWS que utilizamos para la sincronización del backup, será necesario otorgarle permisos adicionales para poder descargar archivos (s3:GetObject) desde el bucket S3 a una ubicación local usando AWS CLI con el comando "aws s3 cp".

> Referencia AWS CLI S3 cp: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/cp.html

**Pull backup: S3 a Local**
```
aws s3 cp s3://bucket/backup/ <LOCAL_PATH> --recursive
```

**Opción 2**

Realizar el mismo proceso que en la opción 1 en relación a los permisos de usuario, pero utilizar una herramienta de terceros para descargar los archivos en lugar de AWS CLI.

- https://s3browser.com
- https://winscp.net
- https://cyberduck.io
- https://mountainduck.io (monta un bucket S3 como una unidad local en el sistema)