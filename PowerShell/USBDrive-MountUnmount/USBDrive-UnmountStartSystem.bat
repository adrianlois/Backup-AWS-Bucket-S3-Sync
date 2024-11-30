@echo off
:: Este script se ejecutará en una tarea programada cada vez que inicie el sistema o en el primer inicio de sesión.
:: Sutituir X: por la letra de asignación del disco a desmontar en el arranque del sistema.
mountvol "X:" /P
exit