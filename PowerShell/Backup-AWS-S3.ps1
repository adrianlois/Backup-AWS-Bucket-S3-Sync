# Afecta a los cmdlets con parámetro -Encoding	
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
# Afecta a la salida de consola (stdout)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# Afecta la salida de texto cuando se redirecciona ese texto a un archivo.
$OutputEncoding = [System.Text.Encoding]::UTF8

# Montar unidad externa USB donde se realizará una segunda copia con Veeam Backup.
Function Set-USBDriveMount {
    [CmdletBinding()]
    Param (
        [String]$DriveLetterUsbBck,
        [String]$GuidUsbBck
    )

    # $DriveLetterUsbBck variable de ámbito de script que también será usada en Set-USBDriveUnmount.
    $script:DriveLetterUsbBck = $DriveLetterUsbBck + ':'
	$DriveLetterUsbBck = $script:DriveLetterUsbBck

    # Se comprueba si la unidad está previamente montada, sino lo está se monta.
    $IdDrive = (Get-Volume | Where-Object {$_.DriveLetterUsbBck -eq "$DriveLetterUsbBck"}).UniqueId
    if (-not ($IdDrive)) {
        # Montar unidad externa
        $Mount = '"' + $DriveLetterUsbBck + '" "' + '\\?\Volume{' + $GuidUsbBck + '}"'
        Invoke-Expression -Command "mountvol $Mount"
    }
}

# Esperar el tiempo establecido y después desmontar la unidad externa USB montada en la función Set-USBDriveMount.
Function Set-USBDriveUnmount {
    [CmdletBinding()]
    Param (
        [Int]$Seconds
    )

    # Tiempo de espera antes de desmontar la unidad previamente montada en Set-USBDriveMount.
    Start-Sleep -Seconds $Seconds

    # Desmontar unidad externa.
    $Unmount = '"' + $DriveLetterUsbBck + '"'
    Invoke-Expression -Command "mountvol $Unmount /P"
}

# Montar los volúmenes de VeraCrypt a nivel de sistema donde se almacenan los ficheros de KeePassXC (kdbx y keyx).
Function Set-VeraCryptMount {
    [CmdletBinding()]
    Param (
        [String]$PasswdFilePath,
        [String]$VCFilePath,
        [String]$DriveLetterVCKdbx,
        [String]$DriveLetterVCKeyx
    )

    # Verificar y agregar la barra de directorio '\' al final si no existe.
    if (-not $PasswdFilePath.EndsWith('\')) {
        $PasswdFilePath += '\'
    }

    # Asignar valores de las variables locales a variables globales del script.
    $script:DriveLetterVCKdbx = $DriveLetterVCKdbx + ':'
	$DriveLetterVCKdbx = $script:DriveLetterVCKdbx
    $script:DriveLetterVCKeyx = $DriveLetterVCKeyx + ':'
	$DriveLetterVCKeyx = $script:DriveLetterVCKeyx
    $script:PasswdFilePath = $PasswdFilePath

    # Paths de los ficheros de passwords VeraCrypt. Almacenar la cadena segura de la contraseña en un puntero de memoria.
    $PasswdVCKdbx = Get-Content -Path ($PasswdFilePath + "PasswdVCKdbx") -Encoding UTF8 | ConvertTo-SecureString
    $ptr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswdVCKdbx)
    $PlainPasswdVCKdbx = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr1)

    $PasswdVCKeyx = Get-Content -Path ($PasswdFilePath + "PasswdVCKeyx") -Encoding UTF8 | ConvertTo-SecureString
    $ptr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswdVCKeyx)
    $PlainPasswdVCKeyx = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr2)

    # Comprobar si los volúmenes están previamente montados.
    try {
        if (-not $VCFilePath.EndsWith('\')) {
            $VCFilePath += '\'
        }

        if (-not (Test-Path $DriveLetterVCKdbx) -and -not (Test-Path $DriveLetterVCKeyx)) {
            # Montar los volúmenes donde se almacenan los ficheros de kdbx y keyx de KeePassXC.
            & 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /volume ($VCFilePath + "kpxc_kdbx.hc") /letter $DriveLetterVCKdbx /password $PlainPasswdVCKdbx /protectMemory /wipecache /nowaitdlg /quit
            & 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /volume ($VCFilePath + "kpxc_keyx.hc") /letter $DriveLetterVCKeyx /password $PlainPasswdVCKeyx /protectMemory /wipecache /nowaitdlg /quit

            # Se esperará hasta que ambos volúmenes estén montados para evitar una condición de carrera antes de llamar a la función Compress-7ZipEncryption.
            while (-not (Test-Path $DriveLetterVCKdbx) -or -not (Test-Path $DriveLetterVCKeyx)) {
                Start-Sleep -Milliseconds 10
            }
        }
    }
    finally {
        # Liberar los punteros de memoria de manera segura.
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr1)
        $PlainPasswdVCKdbx = $Null
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr2)
        $PlainPasswdVCKeyx = $Null
    }
}

# Desmontar los volúmenes de VeraCrypt donde se almancenan los ficheros de kdbx y keyx de KeePassXC.
Function Set-VeraCryptUnmount {
    # Procesos esperados
    $expectedProcs = @("VeraCrypt", "KeePassXC")
    # Buscar los procesos activos
    $runningProcs = $expectedProcs | `
        ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue } | Where-Object { $_ }
    # Extraer los nombres de los procesos encontrados
    $actualProcs = $runningProcs.ProcessName

    # Comprobar si ambos procesos están en ejecución y ambos volúmenes están montados
    $allProcessesRunning = ($expectedProcs | ForEach-Object { $_ -in $actualProcs }) -notcontains $false
    $allPathsExist = (Test-Path $DriveLetterVCKdbx) -and (Test-Path $DriveLetterVCKeyx)

    if ($allProcessesRunning -and $allPathsExist) {
        # Finalizar los procesos de VeraCrypt y KeePassXC desmontará automáticamente los volúmenes de VeraCrypt si estos se montaron previamente con el script Start-VeraCrypt-KPXC.ps1.
        $runningProcs | ForEach-Object { Stop-Process -Name $_.ProcessName -Force }
    }
    else {
        # Desmontar los volúmenes si fueron montados durante la ejecución de este script con la función Set-VeraCryptMount.
        if ((Test-Path $DriveLetterVCKdbx) -and (Test-Path $DriveLetterVCKeyx)) {
            & 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /dismount /force /wipecache /history n /quit
            
            # Se esperará hasta que ambos volúmenes V y W estén desmontados para evitar una condición de carrera antes de finalizar el proceso de VeraCrypt.exe.
            while ((Test-Path $DriveLetterVCKdbx) -or (Test-Path $DriveLetterVCKeyx)) {
                Start-Sleep -Milliseconds 10
            }
        }
        # Finalizar los procesos de VeraCrypt y KeePassXC en caso de que estén en ejecución.
        if ($runningProcs) {
            $runningProcs | ForEach-Object { Stop-Process -Name $_.ProcessName -Force }
        }
    }
}

# Comprimir de forma cifrada y usando un método por capas los ficheros relacionados con la BBDD + key file de KeePassXC.
Function Compress-7ZipEncryption {
    [CmdletBinding()]
    Param (
        [String]$PathKdbx,
        [String]$PathKeyx,
        [String]$File7zKpxc,
        [String]$RemoteFile7zKpxc,
        [String]$WorkPathTemp
    )

    # Paths de los ficheros de passwords 7zip. Almacenar la cadena segura de la contraseña en un puntero de memoria.
    $Passwd7zKdbx = Get-Content -Path ($PasswdFilePath + "Passwd7zKdbx") -Encoding UTF8 | ConvertTo-SecureString
    $ptr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($Passwd7zKdbx)

    $Passwd7zKeyx = Get-Content -Path ($PasswdFilePath + "Passwd7zKeyx") -Encoding UTF8 | ConvertTo-SecureString
    $ptr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($Passwd7zKeyx)

    $Passwd7zKpxc = Get-Content -Path ($PasswdFilePath + "Passwd7zKpxc") -Encoding UTF8 | ConvertTo-SecureString
    $ptr3 = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($Passwd7zKpxc)

    if (-not $WorkPathTemp.EndsWith('\')) {
        $WorkPathTemp += '\'
    }

    # Comprobar y eliminar si existen ficheros comprimidos anteriores.
    $CheckFileTemp = $WorkPathTemp + "*.7z"
    if (Test-Path -Path $CheckFileTemp) {
        Remove-Item -Path $CheckFileTemp -Recurse -Force
    }

    # Doble compresión en formato 7z, mover al path destino el fichero final y eliminar los ficheros temporales creados en esta operación.
    try {
        $File7zKdbx = $WorkPathTemp + "File7zKdbx.7z"
        $File7zKeyx = $WorkPathTemp + "File7zKeyx.7z"

        Compress-7zip -Path $PathKdbx -ArchiveFileName $File7zKdbx `
                      -Format SevenZip -CompressionLevel Normal -CompressionMethod Deflate `
                      -SecurePassword $Passwd7zKdbx -EncryptFilenames
        if ($PathKeyx) {
            Compress-7zip -Path $PathKeyx -ArchiveFileName $File7zKeyx `
                          -Format SevenZip -CompressionLevel Normal -CompressionMethod Deflate `
                          -SecurePassword $Passwd7zKeyx -EncryptFilenames
        }
        Compress-7zip -Path $WorkPathTemp -ArchiveFileName $File7zKpxc `
                      -Format SevenZip -CompressionLevel Normal -CompressionMethod Deflate `
                      -SecurePassword $Passwd7zKpxc -EncryptFilenames

        if (-not $RemoteFile7zKpxc.EndsWith('\')) {
            $RemoteFile7zKpxc += '\'
        }

        Move-Item -Path $File7zKpxc -Destination $RemoteFile7zKpxc -Force
        Remove-Item $CheckFileTemp -Force
    }
    finally {
        # Liberar los punteros de memoria de manera segura.
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr1)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr2)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr3)
    }
}

# Backup: Sincronización local a Bucket S3 de AWS.
Function Invoke-BackupAWSS3 {
    [CmdletBinding()]
    Param (
        [String]$SourcePathLocalData,
        [String]$RemotePathBucketS3,
        [String]$WorkPath
    )

    # Fecha y hora.
    $CurrentDateTime = Get-Date -Format "dd/MM/yyyy - HH:mm:ss"
    # $BackupLog variable en ámbito de script del fichero de log con fecha actual que también será usada en Send-EmailMessageAndFile y Send-TelegramLocalFile.
    if (-not $WorkPath.EndsWith('\')) {
        $WorkPath += '\'
    }
    $script:BackupLog = $WorkPath + "Backup_" + (Get-Date -Format "dd/MM/yyyy") + ".log"
    $BackupLog = $script:BackupLog

    # Comprobar y eliminar si existe un fichero de log anterior.
    $CheckLog = $WorkPath + "Backup_*.log"
    if (Test-Path -Path $CheckLog) {
        Remove-Item -Path $CheckLog -Recurse -Force
    }

<#
    # Alternativa si no se hace uso del fichero externo PathLocalData.txt.
    # Establecer los paths locales a sincronizar con el bucket S3 dentro de la propia función.
    $SourcePathLocalData = @"
C:\PATH_1\Datos
C:\PATH_2\Fotos
H:\PATH_3\Videos
J:\PATH_4\Musica
"@
    # $TXTPathLines almacena una matriz que contiene solo las líneas con contenido válido del fichero especificado $SourcePathLocalData. Dividir en líneas y eliminar espacios en blanco iniciales y finales de cada línea.
    $TXTPathLines = $SourcePathLocalData -split "`n" | Where-Object { $_.Trim() -ne "" }
#>
    # $TXTPathLines almacena en una matriz las líneas de paths especificados el fichero PathLocalData.txt.
    $TXTPathLines = Get-Content -Path $SourcePathLocalData

    # Mostrar fecha y hora del comienzo del proceso de backup al princpio del log.
    $StartTime = (Get-Date)
    Write-Output "Backup comienza: $CurrentDateTime" | Out-File -FilePath $BackupLog -Append -Encoding UTF8
    Write-Output "--------------------------------------`n" | Out-File -FilePath $BackupLog -Append -Encoding UTF8

    # Sincronizar datos locales al bucket S3. Importar e iterar las líneas con los paths locales establecidos en el fichero PathLocalData.txt.
    $TXTPathLines | Foreach-Object {
        $PathLocalData = $_

        # Mantener la misma estructura jerárquica de directorios en la subida al bucket S3 cuando se especifacan múltiples paths locales en PathLocalData.txt.
        $PathRelativeBucketS3  = ($PathLocalData.SubString(2) -Replace '\\', '/')

        # Realizar la sincronización del backup de Local a S3.
        aws s3 sync "$($PathLocalData)" "$($RemotePathBucketS3 + $PathRelativeBucketS3)" --sse AES256 --delete --exact-timestamps --include "*" --exclude "*.DS_Store" | `
        # Eliminar líneas del proceso de sincronización en el output del BackupLog y quedarse solo con las líneas de los cambios de ficheros y directorios.
        ForEach-Object {
            if (($_ -notlike "*remaining*") -and ($_ -notlike "*calculating*")) {
                # Eliminar espacios en blanco iniciales y finales de cada línea en output al fichero $BackupLog.
                $_.Trim() | Out-File -FilePath $BackupLog -Append -Encoding UTF8
            }
        }
    }

    Write-Output "--------------------------------------" | Out-File -FilePath $BackupLog -Append -Encoding UTF8
    $EndTime = (Get-Date)
    $ElapsedTime = $($EndTime-$StartTime).ToString().SubString(0,8)
    # Resetear $CurrentDateTime para obtener la hora actual hasta este momento del proceso de backup.
    # Establecer $CurrentDateTime en este punto como variable de ámbito de script que también será usada en Send-EmailMessageAndFile.
    $CurrentDateTime = Get-Date -Format "dd/MM/yyyy - HH:mm:ss"
    Write-Output "Backup finaliza: $CurrentDateTime`n" | Out-File -FilePath $BackupLog -Append -Encoding UTF8
    Write-Output "Tiempo total transcurrido: $ElapsedTime" | Out-File -FilePath $BackupLog -Append -Encoding UTF8
}

# Enviar notificación del fichero de log y su contenido adjunto vía ChatBot de Telegram.
Function Send-TelegramBotMessageAndFile {
    [CmdletBinding()]
    Param (
        [String]$BotToken,
        [String]$ChatID,
        [Switch]$SendMessage,
        [Switch]$SendFile
    )

    # Si está presente el flag -SendMessage está presente: enviar todo el contenido del fichero BackupLog como mensaje de texto en chatBot.
    if ($SendMessage) {
        # Crear un splat utilizando hashtables anidadas.
        $InvokeRestMethodSplat = @{
            Uri = 'https://api.telegram.org/bot{0}/sendMessage' -f $BotToken
            Form = @{
                chat_id = $ChatID
                text = Get-Content -Path $BackupLog -Raw
            }
            Method = 'Post'
            ErrorAction = 'Stop'
        }
        $ResultSendMessage = Invoke-RestMethod @InvokeRestMethodSplat
    }

    # Si está presente el flag -SendFile: enviar el fichero de BackupLog como adjunto.
    if ($SendFile) {
        # Enviar también la primera y última línea del contenido del fichero donde se indica cuando comienza y el tiempo total del backup como mensaje de texto en el chatBot.
        if (-not $SendMessage) {
            #$firstLine = Get-Content -Path $BackupLog | Select-Object -First 1
            #$lastLine = Get-Content -Path $BackupLog | Select-Object -Last 1
            #$ShortMessage = "$($firstLine.Trim())`n$($lastLine.Trim())"

            $MatchingLines = Get-Content -Path $BackupLog | Where-Object { $_ -match "Backup comienza|Tiempo total" }
            $ShortMessage = $($MatchingLines.Trim()) -join "`n"

            $InvokeRestMethodSplat = @{
                Uri = 'https://api.telegram.org/bot{0}/sendMessage' -f $BotToken
                Form = @{
                    chat_id = $ChatID
                    text = $ShortMessage
                }
                Method = 'Post'
                ErrorAction = 'Stop'
            }
            $ResultSendShortMessage = Invoke-RestMethod @InvokeRestMethodSplat
        }

        # Enviar el fichero adjunto BackupLog al chatBot.
        $InvokeRestMethodSplat = @{
            Uri = 'https://api.telegram.org/bot{0}/sendDocument' -f $BotToken
            Form = @{
                chat_id = $ChatID
                document = [System.IO.FileInfo]$BackupLog
            }
            Method = 'Post'
            ErrorAction = 'Stop'
        }
        $ResultSendFile = Invoke-RestMethod @InvokeRestMethodSplat
    }

    # Devolver resultados en función de los flags indicados.
    if ($SendFile -and $SendMessage) { return $ResultSendMessage, $ResultSendFile }
    elseif ($SendFile) { return $ResultSendShortMessage, $ResultSendFile }
    elseif ($SendMessage) { return $ResultSendMessage }
}

# Enviar correo del fichero de log adjunto y su contenido vía procolo SMTP de Outlook.
Function Send-EmailMessageAndFile {
    [CmdletBinding()]
    Param (
        [String]$UserFromEmail,
        [String]$UserToEmail
    )

    # SMTP Outook.
    # $SmtpServer = "smtp.office365.com"
    # $SmtpPort = "588"
    $SmtpServer = "smtp-mail.outlook.com"
    $SmtpPort = "587"

    # Establecer credenciales email userFrom.
    # Obtener password cifrada del fichero y establecer credenciales email.
    $SecPasswdEmail = Get-Content ($PasswdFilePath + "PasswdEmail") -Encoding UTF8 | ConvertTo-SecureString
    $CredsEmail = New-Object System.Management.Automation.PSCredential ($UserFromEmail, $SecPasswdEmail)
    # Almacenar la cadena segura de la contraseña en un puntero de memoria.
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecPasswdEmail)

    # Asunto y cuerpo email.
    $SubjectEmail = "[Backup] AWS S3 Bucket"
    $BodyEmail = [System.IO.File]::ReadAllText($BackupLog)
    # Alternativas usando Get-Content.
    # $BodyEmail = Get-Content "$BackupLog" | Out-String
    # $BodyEmail = Get-Content "$BackupLog" -Raw

    # Enviar el fichero log adjunto vía email usando el SMTP de Outlook.
    try {
        Send-MailMessage -From "$UserFromEmail" -To "$UserToEmail" -Subject "$SubjectEmail" -Body "$BodyEmail" -Attachments "$BackupLog" `
                         -SmtpServer "$SmtpServer" -Port "$SmtpPort" -UseSsl -Credential $CredsEmail
    }
    finally {
        # Liberar el puntero de memoria de manera segura.
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)
    }
}

# Llamada y workflow de funciones
Set-USBDriveMount -DriveLetterUsbBck "X" -GuidUsbBck "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
Set-VeraCryptMount -PasswdFilePath "C:\PATH\PasswdBackup\" -VCFilePath "C:\PATH\VeraCrypt\" `
                   -DriveLetterVCKdbx "Y:" -DriveLetterVCKeyx "Z:"
Compress-7ZipEncryption -PathKdbx "Y:\file.kdbx" -PathKeyx "Z:\file.keyx" `
                        -File7zKpxc "C:\PATH\file.7z" -RemoteFile7zKpxc "H:\PATH\Datos\" `
                        -WorkPathTemp "C:\PATH\Temp\"
Invoke-BackupAWSS3 -SourcePathLocalData "C:\PATH\PathLocalData.txt" -RemotePathBucketS3 "s3://BucketS3Name/Backup" -WorkPath "C:\PATH\"
Set-VeraCryptUnmount
Send-TelegramBotMessageAndFile -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendFile
Send-EmailMessageAndFile -UserFromEmail "userFrom@outlook.es" -UserToEmail "userTo@gmail.com"
Set-USBDriveUnmount -Seconds "XXXX"
