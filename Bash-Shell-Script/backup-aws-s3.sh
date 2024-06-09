#!/bin/bash

# Fecha y Hora
fechaHoraActual="$(date +'%d/%m/%Y - %H:%M:%S')"
fechaActual="$(date +'%d-%m-%Y')"

# Email
envioEmailCuentaUsuario="emailCuenta@gmail.com"
asuntoEmail="[Backup - AWS S3 Bucket]"
cuerpoEmail="cuerpoEmail"

# Paths
pathLocalDatos="/pathLocal/datos/"
pathRemotoBucketS3="s3://bucketS3/backup/"
backupLog="backup_$fechaActual.log"

# Comprobar si existen ficheros de log pasados del backup
if [ -f "*backup*.log" ];
then
	rm -f "*backup*.log"
fi

# Mostrar fecha y hora del comienzo del proceso de backup al princpio del log
echo "Backup comienza: $fechaHoraActual" > $backupLog
echo -e "# # # # # # # # # # # # # # # # # # # #\n" >> $backupLog

# Sincronizar datos locales a bucket S3 de AWS
aws s3 sync $pathLocalDatos $pathRemotoBucketS3 --sse AES256 --delete --include "*" --exclude "*.DS_Store" >> $backupLog

echo -e "\n# # # # # # # # # # # # # # # # # # # #" >> $backupLog
# Mostrar fecha y hora de la finalización del proceso de backup al final del log
# Resetear la variable fechaHoraActual para obtener la hora actual hasta este momento del proceso de backup
fechaHoraActual="$(date +'%d/%m/%Y - %H:%M:%S')"
echo "Backup finaliza: $fechaHoraActual" >> $backupLog

# Elegir una opción de envío (a o b)

# a) Envío del fichero log adjunto vía Email usando el comando mail.
echo "$cuerpoEmail" | mail -s "$asuntoEmail" "$envioEmailCuentaUsuario" -A "$backupLog"

# b) Envío del contenido del fichero log en el cuerpo del Email usando el comando mail.
cat "$backupLog" | mail -s "$asuntoEmail" "$envioEmailCuentaUsuario"
