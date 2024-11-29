@echo off
:: Llamada al fichero ps1 desde un fichero bat usado para el disparador de la tarea programada (taskschd.msc).
:: El script USBDrive-MountUnmount.ps1 será necesario ejecutarlo en una tarea programada en un contexto de un usuario privilegiado.
pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\PATH\Invoke-USBDriveMountUnmount.ps1"
:: powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\PATH\USBDrive-MountUnmount.ps1"
exit