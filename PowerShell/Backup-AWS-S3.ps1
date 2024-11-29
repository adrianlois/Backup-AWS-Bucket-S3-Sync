$PSDefaultParameterValues['*:Encoding'] = 'utf8'
# [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Montar unidad externa USB donde se realizará una segunda copia con Veeam Backup.
Function Set-USBDriveMount {
    [CmdletBinding()]
    Param (
        [String]$DriveLetterUsbBck,
        [String]$GuidUsbBck
    )

    # $DriveLetterUsbBck variable de ámbito de script que también será usada en Set-USBDriveUnmount.
    $DriveLetterUsbBck = $DriveLetterUsbBck + ':'
    $script:DriveLetterUsbBck = $DriveLetterUsbBck

    # Se comprueba si la unidad está previamente montada, sino lo está se monta.
    $idDrive = (Get-Volume | Where-Object {$_.DriveLetterUsbBck -eq "$DriveLetterUsbBck"}).UniqueId
    if (-not ($idDrive)) {
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

    # Asignar valores de las variables locales a variables globales del script.
    $DriveLetterVCKdbx = $DriveLetterVCKdbx + ':'
    $DriveLetterVCKeyx = $DriveLetterVCKeyx + ':'
    $script:DriveLetterVCKdbx = $DriveLetterVCKdbx
    $script:DriveLetterVCKeyx = $DriveLetterVCKeyx
    $script:PasswdFilePath = $PasswdFilePath

    # Paths de los ficheros de passwords VeraCrypt. Almacenar la cadena segura de la contraseña en un puntero de memoria.
    $PasswdVCKdbx = Get-Content -Path ($PasswdFilePath + "PasswdVCKdbx") -Encoding utf8 | ConvertTo-SecureString
    $ptr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswdVCKdbx)
    $PlainPasswdVCKdbx = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr1)

    $PasswdVCKeyx = Get-Content -Path ($PasswdFilePath + "PasswdVCKeyx") -Encoding utf8 | ConvertTo-SecureString
    $ptr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswdVCKeyx)
    $PlainPasswdVCKeyx = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr2)

    # Comprobar si los volúmenes V o W están previamente montados en el sistema.
    try {
	if (-not (Test-Path $DriveLetterVCKdbx) -or -not (Test-Path $DriveLetterVCKeyx)) {
		# Montar los volúmenes V y W donde se almacenan los ficheros de kdbx y keyx de KeePassXC.
		& 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /volume ($VCFilePath + "kpxc_kdbx.hc") /letter $DriveLetterVCKdbx /password $PlainPasswdVCKdbx /protectMemory /wipecache /nowaitdlg /quit
		& 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /volume ($VCFilePath + "kpxc_keyx.hc") /letter $DriveLetterVCKeyx /password $PlainPasswdVCKeyx /protectMemory /wipecache /nowaitdlg /quit

  		# Se esperará hasta que ambos volúmenes V y W estén montados para evitar una condición de carrera antes de llamar a la función Compress-7ZipEncryption.
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

# Desmontar los volúmenes donde se almancenan los ficheros de kdbx y keyx de KeePassXC montados previamente en la función Set-VeraCryptMount.
Function Set-VeraCryptUnmount {
    # Lista y comprobar si los procesos VeraCrypt y KeePassXC están corriendo.
    $runningProcs = @("VeraCrypt", "KeePassXC") | `
    ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue } | Where-Object { $_ }

    # Finalizar los procesos de VeraCrypt y KeePassXC desmontará automáticamente los volúmenes de VeraCrypt si estos se montaron previamente con el script Start-VeraCrypt-KPXC.ps1.
    if ($runningProcs -and (Test-Path $DriveLetterVCKdbx) -and (Test-Path $DriveLetterVCKeyx)) {
        $runningProcs | ForEach-Object { Stop-Process -Name $_.ProcessName -Force }
    } else {
        # Desmontar los volúmenes si fueron montados durante la ejecución de este script.
        if ((Test-Path $DriveLetterVCKdbx) -or (Test-Path $DriveLetterVCKeyx)) {
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
    $passwd7zKdbx = Get-Content -Path ($PasswdFilePath + "Passwd7zKdbx") -Encoding utf8 | ConvertTo-SecureString
    $ptr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwd7zKdbx)
	
    $passwd7zKeyx = Get-Content -Path ($PasswdFilePath + "Passwd7zKeyx") -Encoding utf8 | ConvertTo-SecureString
    $ptr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwd7zKeyx)
	
    $passwd7zKpxc = Get-Content -Path ($PasswdFilePath + "Passwd7zKpxc") -Encoding utf8 | ConvertTo-SecureString
    $ptr3 = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwd7zKpxc)

    # Comprobar y eliminar si existen ficheros comprimidos anteriores.
    $checkFileTemp = $WorkPathTemp + "*.7z"
    if (Test-Path -Path $checkFileTemp) {
        Remove-Item -Path $checkFileTemp -Recurse -Force
    }

    # Doble compresión en formato 7z, mover al path destino el fichero final y eliminar los ficheros temporales creados en esta operación.
    try {
        $File7zKdbx = $WorkPathTemp + "File7zKdbx.7z"
        $File7zKeyx = $WorkPathTemp + "File7zKeyx.7z"

        Compress-7zip -Path $PathKdbx -ArchiveFileName $File7zKdbx `
                      -Format SevenZip -CompressionLevel Normal -CompressionMethod Deflate `
		      -SecurePassword $passwd7zKdbx -EncryptFilenames
        if ($PathKeyx) {
            Compress-7zip -Path $PathKeyx -ArchiveFileName $File7zKeyx `
                          -Format SevenZip -CompressionLevel Normal -CompressionMethod Deflate `
			  -SecurePassword $passwd7zKeyx -EncryptFilenames
        }
        Compress-7zip -Path $WorkPathTemp -ArchiveFileName $File7zKpxc `
                      -Format SevenZip -CompressionLevel Normal -CompressionMethod Deflate `
		      -SecurePassword $passwd7zKpxc -EncryptFilenames

	Move-Item -Path $File7zKpxc -Destination $RemoteFile7zKpxc -Force
	Remove-Item $checkFileTemp -Force
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
    $currentDateTime = Get-Date -uformat "%d/%m/%Y - %H:%M:%S"
    # $backupLog variable en ámbito de script del fichero de log con fecha actual que también será usada en Send-EmailMessageAndFile y Send-TelegramLocalFile.
    $script:backupLog = $WorkPath + "Backup_" + (Get-Date -uformat "%d-%m-%Y") + ".log"

    # Comprobar y eliminar si existe un fichero de log anterior.
    $checkLog = $WorkPath + "Backup_*.log"
    if (Test-Path -Path $checkLog) {
        Remove-Item -Path $checkLog -Recurse -Force
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
    $startTime = (Get-Date)
    Write-Output "Backup comienza: $currentDateTime" | Out-File -FilePath $backupLog -Append
    Write-Output "___________________________________`n" | Out-File -FilePath $backupLog -Append

    # Sincronizar datos locales al bucket S3. Importar e iterar las líneas con los paths locales establecidos en el fichero PathLocalData.txt.
    $TXTPathLines | Foreach-Object {
        $PathLocalData = $_

        # Mantener la misma estructura jerárquica de directorios en la subida al bucket S3 cuando se especifacan múltiples paths locales en PathLocalData.txt.
        $pathRelativeBucketS3  = ($PathLocalData.SubString(2) -Replace '\\', '/')

        aws s3 sync "$($PathLocalData)" "$($RemotePathBucketS3 + $pathRelativeBucketS3)" --sse AES256 --delete --include "*" --exclude "*.DS_Store" | `
        # Eliminar líneas del proceso de sincronización en el output del backupLog y quedarse solo con las líneas de los cambios de ficheros y directorios.
        ForEach-Object {
            if (($_ -notlike "*remaining*") -and ($_ -notlike "*calculating*")) {
                # Eliminar espacios en blanco iniciales y finales de cada línea en output al fichero $backupLog.
                $_.Trim() | Out-File -FilePath $backupLog -Encoding utf8 -Append
            }
        }
    }

    Write-Output "___________________________________" | Out-File -FilePath $backupLog -Append
    $endTime = (Get-Date)
    $elapsedTime = $($endTime-$startTime).ToString().SubString(0,8)
    # Resetear $currentDateTime para obtener la hora actual hasta este momento del proceso de backup.
    # Establecer $currentDateTime en este punto como variable de ámbito de script que también será usada en Send-EmailMessageAndFile.
    $currentDateTime = Get-Date -uformat "%d/%m/%Y - %H:%M:%S"
    Write-Output "Backup finaliza: $currentDateTime`n" | Out-File -FilePath $backupLog -Append
    Write-Output "Tiempo total transcurrido: $elapsedTime" | Out-File -FilePath $backupLog -Append
}

# Enviar correo del fichero de log adjunto y su contenido vía procolo SMTP de Outlook.
Function Send-EmailMessageAndFile {
    [CmdletBinding()]
    Param (
        [String]$UserFromEmail,
        [String]$UserToEmail
    )

    # SMTP Outook.
    # $smtpServer = "smtp.office365.com"
    # $smtpPort = "588"
    $smtpServer = "smtp-mail.outlook.com"
    $smtpPort = "587"

    # Establecer credenciales email userFrom.
    # Obtener password cifrada del fichero y establecer credenciales email.
    $secPasswdEmail = Get-Content ($PasswdFilePath + "PasswdEmail") -Encoding utf8 | ConvertTo-SecureString
    $credsEmail = New-Object System.Management.Automation.PSCredential ($UserFromEmail, $secPasswdEmail)
    # Almacenar la cadena segura de la contraseña en un puntero de memoria.
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secPasswdEmail)

    # Asunto y cuerpo email.
    $subjectEmail = "[Backup] AWS S3 Bucket"
    $bodyEmail = [System.IO.File]::ReadAllText($backupLog)
    # Alternativas usando Get-Content.
    # $bodyEmail = Get-Content "$backupLog" | Out-String
    # $bodyEmail = Get-Content "$backupLog" -Raw

    # Enviar el fichero log adjunto vía email usando el SMTP de Outlook.
    try {
        Send-MailMessage -From "$UserFromEmail" -To "$UserToEmail" -Subject "$subjectEmail" -Body "$bodyEmail" -Attachments "$backupLog" `
                         -SmtpServer "$smtpServer" -Port "$smtpPort" -UseSsl -Credential $credsEmail
    }
    # Liberar el puntero de memoria de manera segura.
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)
    }
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

    # Si está presente el flag -SendMessage está presente: enviar todo el contenido del fichero backupLog como mensaje de texto en chatBot.
    if ($SendMessage) {
        # Crear un splat utilizando hashtables anidadas.
        $invokeRestMethodSplat = @{
            Uri = 'https://api.telegram.org/bot{0}/sendMessage' -f $BotToken
            Form = @{
                chat_id = $ChatID
                text = Get-Content -Path $backupLog -Raw
            }
            Method = 'Post'
            ErrorAction = 'Stop'
        }
        $resultSendMessage = Invoke-RestMethod @invokeRestMethodSplat
    }

    # Si está presente el flag -SendFile: enviar el fichero de backupLog como adjunto.
    if ($SendFile) {
        # Enviar también la primera y última línea del contenido del fichero donde se indica cuando comienza y el tiempo total del backup como mensaje de texto en el chatBot.
        if (-not $SendMessage) {
            #$firstLine = Get-Content -Path $backupLog | Select-Object -First 1
            #$lastLine = Get-Content -Path $backupLog | Select-Object -Last 1
            #$shortMessage = "$($firstLine.Trim())`n$($lastLine.Trim())"

            $matchingLines = Get-Content -Path $backupLog | Where-Object { $_ -match "Backup comienza|Tiempo total" }
            $shortMessage = $($matchingLines.Trim()) -join "`n"

            $invokeRestMethodSplat = @{
                Uri = 'https://api.telegram.org/bot{0}/sendMessage' -f $BotToken
                Form = @{
                    chat_id = $ChatID
                    text = $shortMessage
                }
                Method = 'Post'
                ErrorAction = 'Stop'
            }
            $resultSendShortMessage = Invoke-RestMethod @invokeRestMethodSplat
        }

        # Enviar el fichero adjunto backupLog al chatBot.
        $invokeRestMethodSplat = @{
            Uri = 'https://api.telegram.org/bot{0}/sendDocument' -f $BotToken
            Form = @{
                chat_id = $ChatID
                document = [System.IO.FileInfo]$backupLog
            }
            Method = 'Post'
            ErrorAction = 'Stop'
        }
        $resultSendFile = Invoke-RestMethod @invokeRestMethodSplat
    }

     # Devolver resultados en función de los flags indicados.
     if ($SendFile -and $SendMessage) { return $resultSendMessage, $resultSendFile }
     elseif ($SendFile) { return $resultSendShortMessage, $resultSendFile }
     elseif ($SendMessage) { return $resultSendMessage }
}

# Llamada y workflow de funciones
Set-USBDriveMount -DriveLetterUsbBck "X" -GuidUsbBck "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
Set-VeraCryptMount -PasswdFilePath "C:\PATH\PasswdBackup\" -VCFilePath "C:\PATH\VeraCrypt\" `
				   -DriveLetterVCKdbx "Y:" -DriveLetterVCKeyx "Z:"
Compress-7ZipEncryption -PathKdbx "Y:\file.kdbx" -PathKeyx "Z:\file.keyx" `
                        -File7zKpxc "C:\PATH\file.7z" -RemoteFile7zKpxc "H:\PATH\Datos\" `
                        -WorkPathTemp "C:\PATH\Temp\"
Set-VeraCryptUnmount
Invoke-BackupAWSS3 -SourcePathLocalData "C:\PATH\PathLocalData.txt" -RemotePathBucketS3 "s3://BucketS3Name/Backup" -WorkPath "C:\PATH\"
Send-EmailMessageAndFile -UserFromEmail "userFrom@outlook.es" -UserToEmail "userTo@gmail.com"
Send-TelegramBotMessageAndFile -BotToken "XXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -ChatID "XXXXXXXXX" -SendFile
Set-USBDriveUnmount -Seconds "XXXX"
