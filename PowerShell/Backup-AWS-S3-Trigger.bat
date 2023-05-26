@echo off
:: Llamada al fichero ps1 desde un fichero bat usado para el disparador de la tarea programada (taskschd.msc)
pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\PATH\Backup-AWS-S3.ps1"
:: Si no se hace uso de la función Send-TelegramLocalFile podemos seguir ejecutando PowerShell v5.1
:: powershell.exe -ExecutionPolicy Bypass -File "C:\PATH\Backup-AWS-S3.ps1"
exit
