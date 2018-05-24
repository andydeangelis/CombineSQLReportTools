<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.150
	 Created on:   	5/23/2018 9:40 AM
	 Created by:   	andy-user
	 Organization: 	
	 Filename:     	Get-BackupHistory.ps1
	===========================================================================
	.DESCRIPTION
		Retrieves the backup history for each SQL instance passed.
#>

function Get-BackupHistory
{
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $True)]
		$InstanceNames,		
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$SQLCredential,
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$domainCredential
	)
	
	$parent = Split-Path -Path $PSScriptRoot -Parent
	
	$backupHistoryScript = {
		
		Param ($instance,
			$parent,
			$credential)
		
		Import-module "$parent\Modules\dbatools\dbatools.psm1"
		
		# First, test connectivity to the specified SQL instance using the logged on user credentials
		
		$sqlObj = Connect-DBAInstance -SqlInstance $instance -Credential $credential
		
		$backupHistoryResult = @()
	
		$backupHistoryResult = $sqlObj | Get-DBABackupHistory
		
		$backupHistoryResult
			
	} # End script block
	
	
	$Throttle = 8
	$backupInitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
	$backupRunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Throttle, $backupInitialSessionState, $Host)
	$backupRunspacePool.Open()
	$backupConfigJobs = @()
	
	foreach ($instance in $instanceNames)
	{
		# Start by creating a SQL management object.
		
		$testConnectionSQL = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
		
		# Next, attempt to connect using SQL credentials (if provided).
		
		try
		{
			$testConnectionSQL.ConnectionContext.LoginSecure = $false
			$testConnectionSQL.ConnectionContext.set_Login($SQLCredential.UserName)
			$testConnectionSQL.ConnectionContext.set_SecurePassword($SQLCredential.Password)
			$testDBAConnectionSQL = $testConnectionSQL.ConnectionContext.ExecuteWithResults("select @@version")
		}
		catch
		{
			Write-Host "Unable to connect using SQL Credentials to $instance."
		}
		
		# Then, try to connect using Domain credentials.
		
		try
		{
			$user = $domainCredential.UserName.Split("\")
			$username = "$($user[1])@$($user[0])"
			
			$testConnectionSQL.ConnectionContext.LoginSecure = $true
			$testConnectionSQL.ConnectionContext.ConnectAsUser = $true
			$testConnectionSQL.ConnectionContext.ConnectAsUserName = $username
			$testConnectionSQL.ConnectionContext.ConnectAsUserPassword = $domainCredential.GetNetworkCredential().Password
			
			$testDBAConnectionDomain = $testConnectionSQL.ConnectionContext.ExecuteWithResults("select @@version")
		}
		catch
		{
			Write-Host "Unable to connect using Domain Credentials to $instance."
		}
		
		# If the SQL credentials passed are successful, add the job to the Runspace pool using SQL credentials.
		
		if ($testDBAConnectionSQL)
		{
			$backupConfigJob = [powershell]::Create().AddScript($backupHistoryScript).AddArgument($instance).AddArgument($parent).AddArgument($SQLCredential)
			$backupConfigJob.RunspacePool = $backupRunspacePool
			$backupConfigJobs += New-Object PSObject -Property @{
				Pipe	   = $backupConfigJob
				Result	   = $backupConfigJob.BeginInvoke()
			}
		}
		# Else, if the Domain credential connection is successful, add the job to the Runspace pool using Domain Credentials.
		
		elseif ($testDBAConnectionDomain)
		{
			$backupConfigJob = [powershell]::Create().AddScript($backupHistoryScript).AddArgument($instance).AddArgument($parent).AddArgument($domainCredential)
			$backupConfigJob.RunspacePool = $backupRunspacePool
			$backupConfigJobs += New-Object PSObject -Property @{
				Pipe	   = $backupConfigJob
				Result	   = $backupConfigJob.BeginInvoke()
			}
		}
		
		# Otherwise, throw a message.
		
		else
		{
			Write-Host "Unable to connect to SQL server $instance."
		}
		
		if ($testConnectionSQL) {Clear-Variable testConnectionSQL}
		if ($testDBAConnectionSQL) {Clear-Variable testDBAConnectionSQL}
		if ($testDBAConnectionDomain) {Clear-Variable testDBAConnectionDomain}
		
	}
	
	Write-Host "Getting Backup History..." -NoNewline -ForegroundColor Green
	
	Do
	{
		Write-Host "." -NoNewline -ForegroundColor Green
		Start-Sleep -Milliseconds 200
	}
	while ($backupConfigJobs.Result.IsCompleted -contains $false)
	
	$backupHistory = @()
	
	ForEach ($backupConfigJob in $backupConfigJobs)
	{
		$backupHistory += $backupConfigJob.Pipe.EndInvoke($backupConfigJob.Result)
	}
	
	Write-Host "All jobs completed!" -ForegroundColor Green
	
	$backupRunspacePool.Close()
	$backupRunspacePool.Dispose()
	
	return $backupHistory
}