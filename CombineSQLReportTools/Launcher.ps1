write-host $PSScriptRoot -ForegroundColor Green

# $script = $PSScriptRoot + "\PS_SQL_DB_Info.ps1"
# $argumentList = "-executionpolicy bypass -windowstyle normal -nologo -file $script"

$servers = Get-Content "C:\Scripts\Projects\SQLCombinedReports\CombineSQLReportTools\myservers.txt"
$reports = "C:\Scripts\Reports"
$sqlCred = Get-Credential
$script = "$PSScriptRoot\CombineSQLReportTools\PS_SQL_DB_Info.ps1 -ServerFileName $servers -ReportPath $reports -SQLCredentials $sqlCred"
$argumentList = "-executionpolicy bypass -windowstyle normal -nologo -file $script"

$message = "The domain account you specify must be a member of the local Administrators group on each server."

Write-Host $script -ForegroundColor Green

# Start-Process powershell -Credential $creds -ArgumentList '-noprofile -command &(Start-Process $script -Verb runAs)'

Start-Process powershell -Credential (Get-Credential -Message $message) -WorkingDirectory $PSScriptRoot -ArgumentList $argumentList -NoNewWindow
