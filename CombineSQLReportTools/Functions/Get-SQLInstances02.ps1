﻿#######################################################################################################################################
#
#    Script: Get-SQLInstances02 function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         This is a replacement for the Get-SQLInstances function within the SQLPS module. The included Get-SQLInstances function is
#         primarily for Azure SQL instances and requires the SQL Cloud Adapter, which doesn't really work. The idea is to pass a host
#         name and return the names of all SQL instances on the host name. It's not elegant, but it works.
#    Usage: 
#           - Simple; source the function and pass the host name as the parameter.
#
#    Examples:
#               . .\Get-SQLInstances02.ps1
#
#               Get-SQLInstances02 -ComputerName HOSTNAME
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

function Get-SQLInstances02
{
    # This is the -Computername parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$True)] [string[]]$ComputerNames,
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$domainCredential
    )

    $parent = Split-Path -Path $PSScriptRoot -Parent
	
	$instanceNames = @()
	
	# Two script blocks are defined here. The first script block uses the the user credentials of the running user.
	# The second script block runs the same commands, but passes the specified domain credential object to query WMI.
	
    $getSQLInstanceScript = {

           Param($server,$parent)

           $instances = @()

        
          # We need to get the correct Namespace name to query, as it changes per version of SQL Serever.
          # For example, SQL 2014 is ROOT\Microsoft\SqlServer\ComputerManagement12 where SQL 2016 is ROOT\Microsoft\SqlServer\ComputerManagement13.
          # Wildcards are not allowed in the Namespace parameter of the Get-WMIObject cmdlet.
          try
          {
            $nameSpaceName = get-wmiobject -Namespace root\Microsoft\SQLServer -Class __Namespace -ComputerName $server -ErrorAction SilentlyContinue| Where-Object {$_.Name -like "ComputerManagement*"} | Select Name
            $nameSpaceString = "ROOT\Microsoft\SqlServer\" + $nameSpaceName.Name
            $instanceArray = get-wmiobject -Namespace $nameSpaceString -class ServerNetworkProtocol -ComputerName $server -ErrorAction SilentlyContinue | Where-Object {$_.ProtocolName -eq "Tcp"} | select PSComputerName,InstanceName
          }
          catch
          {
            Write-Host "No SQL instances found in WMI." -ForegroundColor Cyan
          }       
     
          # Iterate through each SQL instance on the target server and return the object back to the main script.


          foreach ($instance in $instanceArray)
          {
            #Check to see if the SQL service is running as the default instance.

            if ($instance.InstanceName -eq "MSSQLSERVER")
            {
                $instanceName = $server
            }
            # Skip over any SQL Express instances.
            elseif ($instance.DisplayName -match "SQLEXPRESS")
            {
                Write-Host "SQL Express instance...skipping..."
                break;
            }
            else
            {
                # $instanceName = "$Computername\" + ($instance.Name).Replace("MSSQL$","")
                $instanceName = "$server\" + $instance.InstanceName
                # Write-Host $instanceName -ForegroundColor Green
            }

            $instances += $instanceName
          }

          $instances
		
	} # End Script block
	
	$getSQLInstanceScriptDomain = {
		
		Param ($server,
			$parent,
			$domainCred)
		
		$instances = @()
		
		
		# We need to get the correct Namespace name to query, as it changes per version of SQL Serever.
		# For example, SQL 2014 is ROOT\Microsoft\SqlServer\ComputerManagement12 where SQL 2016 is ROOT\Microsoft\SqlServer\ComputerManagement13.
		# Wildcards are not allowed in the Namespace parameter of the Get-WMIObject cmdlet.
		try
		{
			$nameSpaceName = get-wmiobject -Namespace root\Microsoft\SQLServer -Class __Namespace -ComputerName $server -ErrorAction SilentlyContinue -Credential $domainCred | Where-Object { $_.Name -like "ComputerManagement*" } | Select Name
			$nameSpaceString = "ROOT\Microsoft\SqlServer\" + $nameSpaceName.Name
			$instanceArray = get-wmiobject -Namespace $nameSpaceString -class ServerNetworkProtocol -ComputerName $server -ErrorAction SilentlyContinue -Credential $domainCred | Where-Object { $_.ProtocolName -eq "Tcp" } | select PSComputerName, InstanceName
		}
		catch
		{
			Write-Host "No SQL instances found in WMI." -ForegroundColor Cyan
		}
		
		# Iterate through each SQL instance on the target server and return the object back to the main script.
		
		
		foreach ($instance in $instanceArray)
		{
			#Check to see if the SQL service is running as the default instance.
			
			if ($instance.InstanceName -eq "MSSQLSERVER")
			{
				$instanceName = $server
			}
			# Skip over any SQL Express instances.
			elseif ($instance.DisplayName -match "SQLEXPRESS")
			{
				Write-Host "SQL Express instance...skipping..."
				break;
			}
			else
			{
				# $instanceName = "$Computername\" + ($instance.Name).Replace("MSSQL$","")
				$instanceName = "$server\" + $instance.InstanceName
				# Write-Host $instanceName -ForegroundColor Green
			}
			
			$instances += $instanceName
		}
		
		$instances
		
	} # End Script block
     
	$Throttle = 8
	$SQLInitialSessionState =[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

	$SQLRunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$Throttle,$SQLInitialSessionState,$Host)
	$SQLRunspacePool.Open()
	$SQLJobs = @()

    foreach ($server in $ComputerNames)
	{
		if (-not $domainCredential)
		{
			$SQLJob = [powershell]::Create().AddScript($getSQLInstanceScript).AddArgument($server).AddArgument($parent)
			$SQLJob.RunspacePool = $SQLRunspacePool
			$SQLJobs += New-Object PSObject -Property @{
				Pipe    = $SQLJob
				Result  = $SQLJob.BeginInvoke()
			}
		}
		else
		{
			$SQLJob = [powershell]::Create().AddScript($getSQLInstanceScriptDomain).AddArgument($server).AddArgument($parent).AddArgument($domainCredential)
			$SQLJob.RunspacePool = $SQLRunspacePool
			$SQLJobs += New-Object PSObject -Property @{
				Pipe	 = $SQLJob
				Result   = $SQLJob.BeginInvoke()
			}
		}
	}
	
	Write-Host "Getting SQL configuration..." -NoNewline -ForegroundColor Green

	Do
	{
		Write-Host "." -NoNewline -ForegroundColor Green
		Start-Sleep -Milliseconds 200
	} while ($SQLJobs.Result.IsCompleted -contains $false)

	ForEach ($SQLJob in $SQLJobs) 
	{       
		$instanceNames += $SQLJob.Pipe.EndInvoke($SQLJob.Result)
	}

	Write-Host "All jobs completed!" -ForegroundColor Green

	$SQLRunspacePool.Close()
	$SQLRunspacePool.Dispose()

	return $instanceNames
}
 