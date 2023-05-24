@echo off
:: Este script se ejecutará en una tarea programada cada vez que inicie el sistema.
:: Sutituir E: por la letra de asignación del disco a desmontar en el arranque del sistema.
mountvol "E:" /D
exit