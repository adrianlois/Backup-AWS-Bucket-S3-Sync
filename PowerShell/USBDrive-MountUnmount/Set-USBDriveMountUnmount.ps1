# Montar unidad externa USB donde se realizará una segunda copia con Veeam Backup.
Function Set-USBDriveMountUnmount {
    [CmdletBinding()]
    Param (
        [String]$DriveLetter,
        [String]$Guid,
        [Int]$Seconds
    )

    # Se comprueba si la unidad está previamente montada, sino lo está se monta.
    $idDrive = (Get-Volume | Where-Object {$_.DriveLetter -eq "$DriveLetter"}).UniqueId
    if (-not ($idDrive)) {
        # Montar unidad externa
        $Mount = '"' + $DriveLetter + ':' + '" "' + '\\?\Volume{' + $Guid + '}"'
        Invoke-Expression -Command "mountvol $Mount"
    }
	# Tiempo de espera con la unidad previamente montada en USBDrive-Mount.
    Start-Sleep -Seconds $Seconds

    # Desmontar unidad externa.
    $Unmount = '"' + $DriveLetter + ':' + '"'
    Invoke-Expression -Command "mountvol $Unmount /P"
}

Set-USBDriveMountUnmount -DriveLetter "X" -Guid "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" -Seconds "XXXX"