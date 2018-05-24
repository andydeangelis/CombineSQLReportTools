$ServerFileName = "C:\Scripts\test\myservers.txt"
$ReportPath = "C:\Scripts\Test\"
$sqlCred = "C:\Scripts\test\sqlCred.XML"
$domainCred = "C:\Scripts\test\domainCred.XML"

$scriptFile = "PS_SQL_DB_Info.ps1 -ServerFileName $ServerFileName -ReportPath $ReportPath -SQLCredXMLFile $sqlCred -DomainCredXMLFile $domainCred -SaveCreds -RunSilent"

$argumentList = "-executionpolicy bypass", "-mta", "-noninteractive", "-windowstyle normal", "-nologo", "-file $scriptFile"

# Start-Process powershell -WorkingDirectory $PSScriptRoot -ArgumentList $argumentList -NoNewWindow

.\PS_SQL_DB_Info.ps1 -ServerFileName $ServerFileName -ReportPath $ReportPath -SQLCredXMLFile $sqlCred -DomainCredXMLFile $domainCred -SaveCreds -RunSilent