# Generate token for a new bot with @BotFather
$BotToken = "XXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# Get ChatID of our Telegram user with @IDBot
$ChatID = "XXXXXXXXX"
# Set the path of the binary file to be sent
$File = "C:\path\file.log"

function Send-TelegramLocalFile {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]$BotToken,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]$ChatID,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]$File
	)
	# $fileContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($File))
	$form = @{
		chat_id		= $ChatID
		document	= [System.IO.FileInfo]$File
	}
	# -f or -format string formatting operator in PowerShell. Represents a placeholder for the value of $BotToken.
	$uri = 'https://api.telegram.org/bot{0}/sendDocument' -f $BotToken
	$invokeRestMethodSplat = @{
		Uri = $uri
		ErrorAction = 'Stop'
		Form = $form
		Method = 'Post'
	}
	$results = Invoke-RestMethod @invokeRestMethodSplat
	return $results
}

Send-TelegramLocalFile -BotToken $BotToken -ChatID $ChatID -File $File