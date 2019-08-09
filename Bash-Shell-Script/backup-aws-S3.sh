#!/bin/bash

#####################
# Autor @adrianlois_
#####################

# Fecha y Hora
fechaHoraActual="$(date +'%d/%m/%Y - %H:%M:%S')"
fechaActual="$(date +'%d-%m-%Y')"

# Email
envioEmailCuentaUsuario="emailCuentaUsuario@gmail.com"
asuntoEmail="asuntoEmail"
cuerpoEmail="cuerpoEmail"

# Paths
pathLocalDatos="/pathLocal/datos/"
pathRemotoBucketS3="s3://bucketS3/backup/"
backuplog="backup_$fechaActual.log"

# Comprobar si existen ficheros de log pasados del backup
if [ -f "*backup*.log" ];
then
	rm -f "*backup*.log"
fi

# Mostrar fecha y hora del comienzo del proceso de backup al princpio del log
echo "El backup comienza: $fechaHoraActual" > $backuplog
echo -e "# # # # # # # # # # # # # # # # # # # # #\n" >> $backuplog

# Sincronizar datos locales a bucket S3 de AWS
aws s3 sync $pathLocalDatos $pathRemotoBucketS3 --sse AES256 --delete --include "*" >> $backuplog

echo -e "\n# # # # # # # # # # # # # # # # # # # # #" >> $backuplog
# Mostrar fecha y hora de la finalización del proceso de backup al final del log
# Resetear la variable fechaHoraActual para obtener la hora actual hasta este momento del proceso de backup
fechaHoraActual="$(date +'%d/%m/%Y - %H:%M:%S')"
echo "El backup finaliza: $fechaHoraActual" >> $backuplog

# Envío del fichero log adjunto vía Email usando el comando mail.
echo "$cuerpoEmail - $fechaHoraActual" | mail -s "$asuntoEmail" "$envioEmailCuentaUsuario" -A "$backuplog"
