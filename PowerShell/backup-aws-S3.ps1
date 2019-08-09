#####################
# Autor @adrianlois_
#####################

# Fecha y Hora
$fechaHoraActual = Get-Date -uformat "%d/%m/%Y - %H:%M:%S"
$fechaActual = Get-Date -uformat "%d-%m-%Y"

# Email
$usuarioEmail = "usuarioEmail@gmail.com" 
$passwdEmail = "passwdEmail"
$asuntoEmail = "asuntoEmail"
$cuerpoEmail = "cuerpoEmail"

# Convertir password a un string seguro
$secPasswdEmail = ConvertTo-SecureString $passwdEmail -AsPlainText -Force
$credencialesEmail = New-Object System.Management.Automation.PSCredential ($usuarioEmail, $secPasswdEMail)

# Paths
# Compatibles en sistemas Windows: "C:/pathLocal/datos/" o "C:\\pathLocal\\datos\\"
$pathLocalDatos = "C:\\pathLocal\\datos\\"
$pathRemotoBucketS3 = "s3://bucketS3/backup/"
$backupLog = "backup_$fechaActual.log"

# Comprobar si existen ficheros de log pasados del backup
if (Test-Path "*backup*.log") { 
    Remove-Item -Path "*backup*.log" -Recurse -Force 
    }

# Mostrar fecha y hora del comienzo del proceso de backup al princpio del log
Write-Output "El backup comienza: $fechaHoraActual" > $backupLog
Write-Output "# # # # # # # # # # # # # # # # # # # # #`n" >> $backupLog

# Sincronizar datos locales a bucket S3 de AWS
aws s3 sync $pathLocalDatos $pathRemotoBucketS3 --sse AES256 --delete --include "*" >> $backupLog

Write-Output "# # # # # # # # # # # # # # # # # # # # #" >> $backupLog
# Mostrar fecha y hora de la finalización del proceso de backup al final del log
# Resetear la variable $fechaHoraActual para obtener la hora actual hasta este momento del proceso de backup
$fechaHoraActual = Get-Date -uformat "%d/%m/%Y - %H:%M:%S"
Write-Output "El backup finaliza: $fechaHoraActual" >> $backupLog

# Envío del fichero log adjunto vía Email usando Gmail.
Send-MailMessage -From $usuarioEmail -To $usuarioEmail -Subject "$asuntoEmail - $fechaHoraActual" -Body "$cuerpoEmail - $fechaHoraActual" -Attachments "$backupLog" -SmtpServer smtp.gmail.com -UseSsl -Credential $credencialesEmail
exit

