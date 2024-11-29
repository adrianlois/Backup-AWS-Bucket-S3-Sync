Function Set-VeraCryptMount {
    [CmdletBinding()]
    Param (
		[String]$PasswdFilePath,
        [String]$VCFilePath,
		[String]$DriveLetterVCKdbx,
		[String]$DriveLetterVCKeyx
    )

	$DriveLetterVCKdbx = $DriveLetterVCKdbx + ':'
	$DriveLetterVCKeyx = $DriveLetterVCKeyx + ':'
	$script:DriveLetterVCKdbx = $DriveLetterVCKdbx
	$script:DriveLetterVCKeyx = $DriveLetterVCKeyx

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
			& 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /volume ($VCFilePath + "kpxc_kdbx.hc") /letter $DriveLetterVCKdbx /password $PlainPasswdVCKdbx /protectMemory /nowaitdlg /wipecache /quit
			& 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /volume ($VCFilePath + "kpxc_keyx.hc") /letter $DriveLetterVCKeyx /password $PlainPasswdVCKeyx /protectMemory /nowaitdlg /wipecache /quit

			# Se esperará hasta que ambos volúmenes V y W estén montados para evitar una condición de carrera antes de llamar a la función Compress-7ZipEncryption.
			while (-not (Test-Path "$DriveLetterVCKdbx") -or -not (Test-Path "$DriveLetterVCKeyx")) {
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

Function Start-KeePassXC {
	$procKeePassXC = Get-Process -Name "KeePassXC" -ErrorAction SilentlyContinue
	if ($procKeePassXC) { return $false } # Devuelve false si KeePassXC ya está en ejecución y sale de la función.
	Start-Process "C:\Program Files\KeePassXC\KeePassXC.exe" -Wait # Ejecuta KeePassXC y espera a que se cierre manualmente antes de continuar. 
	return $true # Devuelve true si KeePassXC se inició correctamente y terminó su ejecución.
}

Function Set-VeraCryptUnmount {
	& 'C:\Program Files\VeraCrypt\VeraCrypt.exe' /dismount /force /wipecache /history n /quit

	# Se esperará hasta que ambos volúmenes V y W estén desmontados para evitar una condición de carrera antes de finalizar el proceso de VeraCrypt.exe.
	while ((Test-Path $DriveLetterVCKdbx) -or (Test-Path $DriveLetterVCKeyx)) {
		Start-Sleep -Milliseconds 10
	}

	# Finalizar el proceso de VeraCrypt en caso de que esté en ejecución.
	$procVeraCrypt = Get-Process -Name "VeraCrypt" -ErrorAction SilentlyContinue
	if ($procVeraCrypt) {
		Stop-Process -Name "VeraCrypt" -Force
	}
}

Set-VeraCryptMount -PasswdFilePath "C:\PATH\PasswdBackup\" -VCFilePath "C:\PATH\VeraCrypt\" `
				   -DriveLetterVCKdbx "Y" -DriveLetterVCKeyx "Z"
# Si Start-KeePassXC devuelve true, ejecuta Set-VeraCryptUnmount.
if (Start-KeePassXC) { Set-VeraCryptUnmount }