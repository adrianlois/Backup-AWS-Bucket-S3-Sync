@echo off

:: Llamada al fichero ps1 desde un fichero bat
set pathLocalPs1="pathLocalFichero.ps1"
powershell.exe -file %pathLocalPs1%

exit
