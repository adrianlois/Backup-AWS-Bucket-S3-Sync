Function MountDismountUSB {

	param (
		[Parameter(Mandatory=$True)]
		[string]$dl,
		[Parameter(Mandatory=$True)]
		[string]$s
	)

	$id = (Get-Volume | Where-Object {$_.DriveLetter -eq "$dl"}).UniqueId
	mountvol $dl + ":\" $id
	Start-Sleep -Seconds $s
	mountvol $dl + ":\" /p
}
MountDismountUSB -dl "F" -s "2400"
