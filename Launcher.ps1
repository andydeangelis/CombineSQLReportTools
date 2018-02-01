write-host $PSScriptRoot -ForegroundColor Green

$script = $PSScriptRoot + "\PS_SQL_DB_Info.ps1"
$argumentList = "-executionpolicy bypass -windowstyle normal -nologo -file $script"

Write-Host $script -ForegroundColor Green

# Start-Process powershell -Credential $creds -ArgumentList '-noprofile -command &(Start-Process $script -Verb runAs)'

Start-Process powershell -Credential (Get-Credential) -WorkingDirectory $PSScriptRoot -ArgumentList $argumentList -NoNewWindow
