﻿<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.150
	 Created on:   	5/7/2018 10:46 AM
	 Created by:   	Andy DeAngelis
	 Organization: 	
	 Filename:     	Get-InstalledSQLServices
	===========================================================================
	.DESCRIPTION
		Function to return a list of all SQL services installed on a computer.

	#````Note: Powershellv3 or higher and dbatools is needed.
#>

function Get-InstalledSQLServices
{
	
	# This is the -instance.Name parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $True)]
		[string[]]$ComputerNames,
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$domainCredential
	)
	
	$parent = Split-Path -Path $PSScriptRoot -Parent
	
	$installedSQLScript = {
		
		Param ($computer,
			$parent,
			$domainCred)
		
		Import-module "$parent\Modules\dbatools\dbatools.psm1"
		
		try
		{
			if (-not $domainCred)
			{
				$services = Get-DbaSQLService -ComputerName $computer
				$services
			}
			else
			{
				$services = Get-DbaSQLService -ComputerName $computer -Credential $domainCred
				$services
			}
		}
		catch
		{
			Write-Host "No SQL Services installed."
		}
		
	} # End script block
	
	
	$Throttle = 8
	$sqlConfigInitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
	$sqlConfigRunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Throttle, $sqlConfigInitialSessionState, $Host)
	$sqlConfigRunspacePool.Open()
	$sqlConfigJobs = @()
	
	foreach ($computer in $ComputerNames)
	{
		$sqlConfigJob = [powershell]::Create().AddScript($installedSQLScript).AddArgument($computer).AddArgument($parent).AddArgument($domainCredential)
		$sqlConfigJob.RunspacePool = $sqlConfigRunspacePool
		$sqlConfigJobs += New-Object PSObject -Property @{
			Pipe    = $sqlConfigJob
			Result  = $sqlConfigJob.BeginInvoke()
		}
	}
	
	Write-Host "Getting installed SQL services..." -NoNewline -ForegroundColor Green
	
	Do
	{
		Write-Host "." -NoNewline -ForegroundColor Green
		Start-Sleep -Milliseconds 200
	}
	while ($sqlConfigJobs.Result.IsCompleted -contains $false)
	
	$installedSQLSvcConfig = @()
	
	ForEach ($sqlConfigJob in $sqlConfigJobs)
	{
		$installedSQLSvcConfig += $sqlConfigJob.Pipe.EndInvoke($sqlConfigJob.Result)
	}
	
	Write-Host "All jobs completed!" -ForegroundColor Green
	
	$sqlConfigRunspacePool.Close()
	$sqlConfigRunspacePool.Dispose()
	
	return $installedSQLSvcConfig
	
}

