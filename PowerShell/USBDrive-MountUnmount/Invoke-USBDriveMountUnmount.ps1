# Montar unidad externa USB donde se realizará una segunda copia con Veeam Backup.
Function Invoke-USBDriveMountUnmount {
    [CmdletBinding()]
    Param (
        [String]$DriveLetterUsbBck,
        [String]$GuidUsbBck,
        [Int]$Seconds
    )

    $DriveLetterUsbBck = $DriveLetterUsbBck + ':'

    # Se comprueba si la unidad está previamente montada, sino lo está se monta.
    $idDrive = (Get-Volume | Where-Object {$_.DriveLetterUsbBck -eq "$DriveLetterUsbBck"}).UniqueId
    if (-not ($idDrive)) {
        # Montar unidad externa
        $Mount = '"' + $DriveLetterUsbBck + '" "' + '\\?\Volume{' + $GuidUsbBck + '}"'
        Invoke-Expression -Command "mountvol $Mount"
    }
    # Tiempo de espera con la unidad previamente montada en USBDrive-Mount.
    Start-Sleep -Seconds $Seconds

    # Desmontar unidad externa.
    $Unmount = '"' + $DriveLetterUsbBck + '"'
    Invoke-Expression -Command "mountvol $Unmount /P"
}

Invoke-USBDriveMountUnmount -DriveLetterUsbBck "X" -GuidUsbBck "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" -Seconds "XXXX"