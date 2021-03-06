﻿#######################################################################################################################################
#
#    Script: SQL Server Reporting Script
#    Author: Andy DeAngelis
#    Descrfiption: 
#         The purpose of this script is to help gather information about SQL Server instances deployed in an environment. It calls various 
#         custom functions to gather server information, clustering information and SQL information. Once gathered, the script then creates
#         reports in Excel format that can be shared with customers, end users, other IT staff, etc.
#    Usage: 
#           - Servers should be listed in the myservers.txt file located in the same directory as the script, one server name per line.
#           - The script should be initiated using the RUN_ME.bat batch file or by using the .\Launcher.ps1 file. This ensures that the
#             ExecutionPolicy scope is properly set, and the proper credentials are passed.
#           - The credential passed in the Get-Credential call needs to be a local administrator on the target servers to gather WMI data.
#           - The credential passed in the Get-Credential call needs to be a SysAdmin in each SQL instance to gather SQL data.
#           - This script also uses dbatools and ImportExcel PowerShell modules
#    Examples:
# 				$sqlCred = Get-Credential
# 				$domainCred = Get-Credential
#               .\PS_SQL_DB_Info.ps1 -ServerFileName C:\temp\myservers.txt -ReportPath C:\temp -SQLCredentials $sqlCred -DomainCredentials $domainCred
#
#				$sqlCredXML = Get-Credential | ExportCliXML sqlCred.xml
# 				$domainCredXML = Get-Credential | Export-CliXML domainCred.XML
# 				.\PS_SQL_DB_Info.ps1 -ServerFileName C:\temp\myservers.txt -ReportPath C:\temp -SQLCredXMLFile $sqlCredXML -DomainCredXMLFile $DomainCredXML
#
#				$sqlCredXML = Get-Credential | ExportCliXML sqlCred.xml
# 				$domainCredXML = Get-Credential | Export-CliXML domainCred.XML
# 				.\PS_SQL_DB_Info.ps1 -ServerFileName C:\temp\myservers.txt -ReportPath C:\temp -SQLCredXMLFile $sqlCredXML -DomainCredXMLFile $DomainCredXML -SaveCreds $true
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

param (
	[parameter(Mandatory = $true, ValueFromPipeline = $True)] [string[]]
	[string]$ServerFileName,
	[parameter(Mandatory = $false, ValueFromPipeline = $True)]
	[string]$ReportPath,
	[parameter(Mandatory = $false, ValueFromPipeline = $True)]
	[string]$SQLCredXMLFile,
	[parameter(Mandatory = $false, ValueFromPipeline = $True)]
	[string]$DomainCredXMLFile,
	[parameter(Mandatory = $false, ValueFromPipeline = $false)]
	[switch]$SaveCreds = $false,
	[parameter(Mandatory = $false, ValueFromPipeline = $false)]
	[switch]$RunSilent = $false,
	[parameter(Mandatory = $false, ValueFromPipeline = $True)]
	[System.Management.Automation.PSCredential]$SQLCredentials,
	[parameter(Mandatory = $false, ValueFromPipeline = $True)]
	[System.Management.Automation.PSCredential]$DomainCredentials
)

# Clear the error log.

# $Error.Clear()

# Add the required .NET assembly for Windows Forms.
Add-Type -AssemblyName System.Windows.Forms

# Check if the SQL Credentials are set. If the user needs to specify a separate SQL logon, they will be prompted with a credential dialog.

if (-not $RunSilent)
{
	if ((-not $SQLCredentials) -and (-not $SQLCredXMLFile))
	{
		# Show the MsgBox. This is going to ask if the user needs to specify a separate SQL logon.
		$result = [System.Windows.Forms.MessageBox]::Show('Do you need to specify a separate SQL logon account?', 'Warning', 'YesNo', 'Warning')
		
		if ($result -eq 'Yes')
		{
			$sqlCred = Get-Credential -Message "Please specify your SQL username and password."
		}
		else
		{
			Write-Warning 'No SQL logon specifed. Using domain account...'
		}
	}
	elseif ($SQLCredentials -and (-not $SQLCredXMLFile))
	{
		Write-Host "Using SQL Credentials." -ForegroundColor Yellow
		$sqlCred = $SQLCredentials
	}
	elseif ((-not $SQLCredentials) -and $SQLCredXMLFile)
	{
		$sqlCred = Import-Clixml -Path $SQLCredXMLFile
		if (-not $SaveCreds)
		{
			Remove-Item $SQLCredXMLFile -Force
		}
	}
	elseif ($SQLCredentials -and $SQLCredXMLFile)
	{
		Write-Host "Using SQL Credentials." -ForegroundColor Yellow
		$sqlCred = $SQLCredentials
	}
}
else
{
	if (-not $SQLCredXMLFile)
	{
		Write-Host "No SQL Credential file found!" -ForegroundColor Red
		exit
	}
	else
	{
		$sqlCred = Import-Clixml -Path $SQLCredXMLFile
	}
}

# Check if domain credentials are being passed.

if (-not $RunSilent)
{
	if ((-not $DomainCredentials) -and (-not $DomainCredXMLFile))
	{
		# Show the MsgBox. This is going to ask if the user needs to specify a separate Domain logon.
		$result = [System.Windows.Forms.MessageBox]::Show('Do you need to specify a separate Domain logon account?', 'Warning', 'YesNo', 'Warning')
		
		if ($result -eq 'Yes')
		{
			$domainCred = Get-Credential -Message "Please specify your domain name and password that has the rights to query WMI on the target servers."
		}
		else
		{
			Continue
		}
	}
	elseif ($DomainCredentials -and (-not $DomainCredXMLFile))
	{
		$domainCred = $DomainCredentials
	}
	elseif ((-not $DomainCredentials) -and $DomainCredXMLFile)
	{
		$domainCred = Import-Clixml -Path $DomainCredXMLFile
		if (-not $SaveCreds)
		{
			Remove-Item $DomainCredXMLFile -Force
		}
	}
	elseif ($DomainCredentials -and $DomainCredXMLFiles)
	{
		$domainCred = $DomainCredentials
	}
}
else
{
	if (-not $DomainCredXMLFile)
	{
		Write-Host "No Domain credential file found!" -ForegroundColor Red
		exit
	}
	else
	{
		$domainCred = Import-Clixml -Path $DomainCredXMLFile
	}
}

# List SQL scripts.
# This is the SQL Query that will return the the database information and average performance data of each database file in the instance.
# This is kept external so as not have issues with formatting within the PS script itself, while also being able to be
# modified independently.

# TO-DO: Possibly make this a parameter instead of hard-coded.

$SQLStatsQuery = $PSScriptRoot + "\SQLScripts\CombinedSQLStats.sql"
# $SQLVersionInfo = $PSScriptRoot + "\SQLScripts\SQLVersionInfo.sql"

# At least one computer name must be passed to the script. For now, the script handles a file with a list of computer names.
# List of server hostnames, one hostname per line

$Servers = Get-Content "$ServerFileName"

# Get the Windows or SQL credentials to be used to connect to the SQL instances.

# $SQLCreds = Get-Credential

# Get the system date to timestamp the files

$datetime = get-date -f MM-dd-yyyy_hh.mm.ss

# Check to see if the Reports Path variable is set. If not, set launch the folder browser dialog.

if (-not $ReportPath)
{
	# Create a dialog box to select the report target path.
	
	Add-Type -AssemblyName System.Windows.Forms
	$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
	$FolderBrowser.SelectedPath
	
	# If the report path is specified in the FolderBrowser, use that path. Otherwise, use the default path.
	
	if ($FolderBrowser.ShowDialog() -eq "OK")
	{
		$targetPath = $FolderBrowser.SelectedPath + "\SQLServerInfo\$datetime"
	}
	else
	{
		$targetPath = "$PSScriptRoot\SQLServerInfo\$datetime"
	}
}
else
{
	$targetPath = "$ReportPath\SQLServerInfo\$datetime"
}

# Let's start our stopwatch.
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

$failedConnections = "$targetPath\FailedConnections-$datetime.txt"
$logFile = "$targetPath\DebugLogFile-$datetime.txt"

if (!(Test-Path $targetPath))
{
    New-Item -ItemType Directory -Force -Path $targetPath    
}

if (!(Test-Path $logFile))
{
    New-Item -ItemType File -Force -Path $logFile
}

# Create a new, empty Excel document for SQL Data.
$SQLDataxlsxReportPath =  "$targetPath\SQLServerDBReport-$datetime.xlsx"

# Create a new, empty Excel document for Cluster Configuration.
$clClusterConfigxlsxReportPath =  "$targetPath\ClusterConfigReport-$datetime.xlsx"
$agConfigxlsxReportPath =  "$targetPath\AvailabilityGroupConfigReport-$datetime.xlsx"

# Create an array that will hold the SQL best practices data.
$sqlBP = @()

. $PSScriptRoot\IncludeMe.ps1

# Output the PowerShell screen text as debug file.

Start-Transcript -Path $logFile

# Let's verify which servers are online and which are not.

if ($Servers -ne $null)
{
    $aliveServers = Get-IsAlive -ComputerNames $Servers
}

# Now, we use the Compare-Object cmdlet to get the list of servers that didn't respond to the Get-IsAlive function.

$deadServers = Compare-Object -ReferenceObject $aliveServers -DifferenceObject $Servers -PassThru

# Let's output the list of dead servers to the failed connection log.

$deadServers | Out-File -FilePath $failedConnections

# Determine which servers are part of a cluster and which are not.

# Set the array name that we will use to hold the cluster names.
$ClusterNames = @()

# Set the array name that we will use to hold the non-cluster server names.
$singleServerNames = @()

foreach ($server in $aliveServers)
{
  # Let's use WMI to see if the server is part of a cluster.
  
  if (Get-IsClustered -ComputerName $server -domainCredential $domainCred)
  {
    # If it is part of a cluster, get the cluster name from WMI (since may not have the FailoverClusters module installed), and add the cluster name to the ClusterNames array.
    # Note that this is an array of objects, not strings (we'll handle this later).
		
		if (Get-WmiObject -Namespace root\mscluster -ComputerName $server -class mscluster_cluster -Credential $domainCred -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
		{
			Write-Host "Server $server is clustered." -ForegroundColor DarkYellow
			$tmpClObj = Get-WmiObject -Namespace root\mscluster -ComputerName $server -class mscluster_cluster -Credential $domainCred | Select-Object Name
			$ClusterNames += $tmpClObj.Name
		}
		else
		{
			Write-Host "Server $server is clustered." -ForegroundColor DarkYellow
			$tmpClObj = Get-WmiObject -Namespace root\mscluster -ComputerName $server -class mscluster_cluster -Credential $domainCred | Select-Object Name
			$ClusterNames += $tmpClObj.Name
		}
	}
	else
	{
		# If the server is not part of a cluster, add the server name to the ServerNames array.
		# Note that this is an array of strings.
		Write-Host "Server $server is NOT clustered. " -ForegroundColor DarkCyan
		$singleServerNames += $server
	}
}

# Next, we'll get the clustered SQL instance information and data.

if ($ClusterNames -ne $null)
{
  # Strip out duplicate cluster names.
  
  $clNames = $ClusterNames | Select -Unique
    
  # Instantiate an array to hold the resource config.
   
  $clResourceConfig = @()
  
  # Now that we have the unique set of cluster names, lets send the array of names to the Get-ClusterConfig function.

  $clCoreConfig = Get-ClusterConfig -ClusterNames $clNames -domainCredential $domainCred

  # We'll also instantiate an array to hold the cluster nodes names.

  $clNodes = @()

  foreach ($clname in $clNames)
  {
		# $clCoreConfig += Get-ClusterConfig -ClusterNames $name.Name
		
		if (-not $domainCred)
		{
			$clResources = Get-WmiObject -Namespace root\mscluster -ComputerName $clname -Class mscluster_resource | Where-Object { $_.OwnerGroup -ne "Cluster Group" } |
			Select-Object OwnerGroup, OwnerNode, CoreResource, Type, IsClusterSharedVolume
			$clNodes += Get-WmiObject -Namespace root\mscluster -ComputerName $clName -Class mscluster_node | Select-Object Name
		}
		else
		{
			$clResources = Get-WmiObject -Namespace root\mscluster -ComputerName $clname -Class mscluster_resource -Credential $domainCred| Where-Object { $_.OwnerGroup -ne "Cluster Group" } |
			Select-Object OwnerGroup, OwnerNode, CoreResource, Type, IsClusterSharedVolume
			$clNodes += Get-WmiObject -Namespace root\mscluster -ComputerName $clName -Class mscluster_node -Credential $domainCred | Select-Object Name
		}
		
		# Set the worksheet name for the server's config.
    $clResourceWorksheet = $clname + " Resources"
        
    # Set the table name for the worksheet.
    $clResourceTable = "Table" + $clname
        
    # Export the resources to a new tab in the Excel spreadsheet, one tab per cluster name.
        
    if ($clResources -ne $null)
    {
        $excel = $clResources | Export-Excel -Path $clClusterConfigxlsxReportPath -AutoSize -WorksheetName $clResourceWorksheet -FreezeTopRow -TableName $clResourceTable -PassThru        
        $excel.Save() ; $excel.Dispose()
    }
    else
    {
        Write-Host "No cluster data found."
    }

    # Get the cluster node names.

    # $clNodes += Get-WmiObject -Namespace root\mscluster -ComputerName $clName -Class mscluster_node | Select-Object Name
  } 

    # Set the worksheet name. We will have a single tab that will hold each cluster's config for easy reference..
  
    $clConfigWorksheet = "Cluster Configs"

    # Set the table names for the worksheet.
  
    $clConfigTableName = "ClusterConfigs"

    if ($clCoreConfig -ne $null)
    {
        $excel = $clCoreConfig | Export-Excel -Path $clClusterConfigxlsxReportPath -AutoSize -WorksheetName $clConfigWorksheet -FreezeTopRow -TableName $clConfigTableName -PassThru        
        $excel.Save() ; $excel.Dispose()
    }
    else
    {
        Write-Host "No cluster data found."
    }    
}

# We now need to get all the SQL instance names, however, retrieving them from clusters is a bit different than stand-alone servers.
# Since we have separated cluster servers and non cluster servers, we can get two separate lists of instances, clustered and not.
  
# Call the Get-ClusterSQLInstances function to get the list of SQL instance names on cluster nodes.
# This will return both failover cluster node instances, as well as stand-alone instances on servers that are part of an Always On Availability Group.

if ($clNames -ne $null)
{  
    $clSQLInstances = Get-ClusteredSQLInstances -ClusterNames $clNames -domainCredential $domainCred
}

# Now, let's get the list of stand-alone instance names by call the Get-SQLInstances02 function.

if ($singleServerNames -ne $null)
{
    $SQLInstances = Get-SQLInstances02 -ComputerNames $singleServerNames -domainCredential $domainCred
}

# Finally, we will combine both lists into a single array.

if (($clSQLInstances -ne $null) -and ($SQLInstances -ne $null))
{
    $allSQLInstances = $clSQLInstances + $SQLInstances
}
elseif (($clSQLInstances -eq $null) -and ($SQLInstances -ne $null))
{
    $allSQLInstances = $SQLInstances
}
elseif (($clSQLInstances -ne $null) -and ($SQLInstances -eq $null))
{
    $allSQLInstances = $clSQLInstances
}
else
{
    Write-Host "No SQL instances found..." -ForegroundColor Red
}

$allSQLInstances = $allSQLInstances | Select -Unique

# Set the array name that we will use to hold the SQL Server configuration data.
$sqlConfig = @()
$sqlVersionConfig = @()

# Set the array name that we will use to hold the Availability Group Configuration.
$agConfigResult = @()

# Set the array name we will use to store the backup history.
$backupHistory = @()

# Now that we've retrieved all the SQL instances, let's get some info...

if ($allSQLInstances -ne $null)
{
    $sqlConfig += Get-SQLConfig -instanceNames $allSQLInstances -SQLCredential $sqlCred -domainCredential $domainCred
    $sqlVersionConfig += Get-SQLVersion -InstanceNames $allSQLInstances -SQLCredential $sqlCred -domainCredential $domainCred
	$agConfigResult += Get-SQLAGConfig -InstanceNames $allSQLInstances -SQLCredential $sqlCred -domainCredential $domainCred
	$backupHistory += Get-BackupHistory -InstanceNames $allSQLInstances -SQLCredential $sqlCred -domainCredential $domainCred
	
	# TO-DO: Need to multi-thread this function.
	
    foreach ($instance in $allSQLInstances)
    {
		Get-SQLData -InstanceName $instance -ReportExportFileName $SQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery -SQLCredential $sqlCred -domainCredential $domainCred
    }
}

# Now, let's join the cluster node names stand-alone nodes into a single array.
$ServerList = @()

if ($clNodes -ne $null)
{
    foreach ($item in $clNodes)
    {
        $ServerList += $item.Name
    }
}

if($singleServerNames -ne $null)
{
    foreach ($item in $singleServerNames)
    {
        $ServerList += $item
    }
}

$ServerList = $ServerList | Select -Unique


#######################################################################################################################################
#
#
# Spreadsheet Generation Section
#
#
#######################################################################################################################################

# Gemerate the Server configuration and installed SQL services spreadsheets.

if ($ServerList -ne $null)
{
  # Next, we'll get the server data returned as an array.
	
	$ServerConfigResult = Get-ServerConfig -ComputerName $ServerList -domainCredential $domainCred
	
	# Set the worksheet names. 
  
  $ServerConfigWorksheet = "Server Config"
  $ServerDiskConfigWorksheet = "Disk Config"
      
  # Set the table names for the worksheet.
  
  $ServerConfigTableName = "ServerConfig"
  $ServerDiskConfigTableName = "DiskConfig"
    
  # TO-DO: Add some error handling here (i.e. check to ensure the arrays are not empty or null).
    
  if ($ServerConfigResult -ne $null)
  {
    # Create a new, empty Excel document for Stand-alone Server Configuration.
    $ServerConfigxlsxReportPath =  "$targetPath\ServerConfigReport-$datetime.xlsx"
    
    $excel = $ServerConfigResult[0] | Export-Excel -Path $ServerConfigxlsxReportPath -AutoSize -WorksheetName $ServerConfigWorksheet -FreezeTopRow -TableName $ServerConfigTableName -PassThru
    $excel.Save() ; $excel.Dispose()
    $excel2 = $ServerConfigResult[1] | Export-Excel -Path $ServerConfigxlsxReportPath -AutoSize -WorksheetName $ServerDiskConfigWorksheet -FreezeTopRow -TableName $ServerDiskConfigTableName -PassThru
    $excel2.Save() ; $excel2.Dispose()
  }
  else
  {
    Write-Host "No server data found."
  }	
	
	# Let's get a list of all SQL services installed.
	
	$installedSQLSvcs = Get-InstalledSQLServices -ComputerNames $ServerList -domainCredential $domainCred
	
	$SQLSvcsConfigWorksheet = "SQL Services"
	
	# Set the table names for the worksheet.
	
	$SQLSvcsConfigTableName = "SQLSvcs"
	
	# TO-DO: Add some error handling here (i.e. check to ensure the arrays are not empty or null).
	
	if ($installedSQLSvcs -ne $null)
	{
		# Create a new, empty Excel document for Stand-alone Server Configuration.
		$installedSQLSvcsxlsxReportPath = "$targetPath\InstalledSQLServicesReport-$datetime.xlsx"
		
		$excel = $installedSQLSvcs | Export-Excel -Path $installedSQLSvcsxlsxReportPath -AutoSize -WorksheetName $SQLSvcsConfigWorksheet -FreezeTopRow -TableName $SQLSvcsConfigTableName -PassThru
		$excel.Save(); $excel.Dispose()
	}
	else
	{
		Write-Host "No SQL services found."
	}
}
else
{
	Write-Host "There are no servers to check." -ForegroundColor DarkRed
}

# Let's output the Always On AG config to a spreadsheet.

if ($agConfigResult -ne $null)
{
	$agNames = $agConfigResult | Select -Unique Name
	
	foreach ($ag in $agNames)
	{
		$agsUnique = $agConfigResult | ?{$_.Name -eq $ag.Name}
		
		$agWorksheet = "AG - " + $ag.Name
        $agTableName = "AG-" + $ag.Name
        $excel = $agsUnique | Export-Excel -Path $agConfigxlsxReportPath -AutoSize -WorksheetName $agWorksheet -FreezeTopRow -TableName $agTableName -PassThru
        $excel.Save() ; $excel.Dispose()
        
    }
}
else
{
    # If we have no Availability Groups returned, write a message.
        
    Write-Host "No Availability Group server data."
}

# Export the backup history to a spreadsheet.

if ($backupHistory -ne $null)
{
	$backupHistorySpreadsheet = "$targetPath\BackupHistory-$datetime.xlsx"
	
	# $instanceBackupHistory = $backupHistory | ?{ $_.SqlInstance -eq $sqlInstanceName.SqlInstance }
	<#
	$backupWorksheet = "Backups"
	$backupTable = "BackupTable"
	
	$excel = $backupHistory | Export-Excel -Path $backupHistorySpreadsheet -AutoSize -WorksheetName $backupWorksheet -FreezeTopRow -TableName $backupTable -PassThru
	$excel.Save(); $excel.Dispose()
	/#>
	
	$sqlInstanceNames = $backupHistory | select -Unique SqlInstance
	
	foreach ($sqlInstanceName in $sqlInstanceNames)
	{
		$instanceBackupHistory = $backupHistory | ?{ $_.SqlInstance -eq $sqlInstanceName.SqlInstance }
		
		$backupWorksheet = "$($sqlInstanceName.SqlInstance)" -replace "\\", "-"
		$backupTable = "$($sqlInstanceName.SqlInstance)" -replace "\\", "-"
		
		$excel = $instanceBackupHistory | Export-Excel -Path $backupHistorySpreadsheet -AutoSize -WorksheetName $backupWorksheet -FreezeTopRow -TableName $backupTable -PassThru
		$excel.Save(); $excel.Dispose()
	}
}

# Next, export all SQL server config and best practices data to a different spreadsheet.

if ($sqlConfig -ne $null)
{
	$sqlConfigWorksheet = "SQL Configs"
	$sqlConfigTable = "SQL_SP_Configs"
	
	$sqlVersionConfigWorksheet = "SQL Versions"
	$sqlVersionConfigTable = "SQLVersionConfigs"
	
	$sqlBPWorksheet = "SQL Best Practices"
	$sqlBPTable = "SQLBestPractices"
	
	$sqlConfigSpreadsheet = "$targetPath\sqlConfig-$datetime.xlsx"
	
  $excel2 = $sqlVersionConfig | Export-Excel -Path $sqlConfigSpreadsheet -Autosize -Worksheet $sqlVersionConfigWorksheet -FreezeTopRow -TableStyle 'Medium6' -TableName $sqlVersionConfigTable -PassThru
  $excel2.Save() ; $excel2.Dispose()
  $excel = $sqlConfig | Export-Excel -Path $sqlConfigSpreadsheet -AutoSize -WorksheetName $sqlConfigWorksheet -FreezeTopRow -TableStyle 'Medium6' -TableName $sqlConfigTable -PassThru
  $excel.Save() ; $excel.Dispose()
}
else
{
  Write-Host "No SQL Data to export." -ForegroundColor Red
}

# Last, export the $Error variable to a log file.

# $Error | Out-File "$target\ErrorLog.log"

Write-Host "###############################################" -ForegroundColor DarkYellow
Write-Host "############ Report Locations #################" -ForegroundColor DarkYellow
Write-Host "###############################################" -ForegroundColor DarkYellow

Write-Host "The Transcript log file location:" -ForegroundColor Cyan -NoNewLine
Write-Host "$logFile." -ForegroundColor Yellow
Write-Host "The Failed Connections log file location:" -ForegroundColor Cyan -NoNewLine
Write-Host "$failedConnections" -ForegroundColor Yellow
Write-Host "The SQL Server DB Report log file location:" -ForegroundColor Cyan -NoNewLine
Write-Host "$SQLDataxlsxReportPath" -ForegroundColor Yellow
Write-Host "The Cluster Configuration Report file location:" -ForegroundColor Cyan -NoNewLine
Write-Host "$clClusterConfigxlsxReportPath" -ForegroundColor Yellow
Write-Host "The SQL Always On Availability Group Configuration Report file location:" -ForegroundColor Cyan -NoNewLine
Write-Host "$agConfigxlsxReportPath" -ForegroundColor Yellow
Write-Host "The SQL Backup History Report file location:" -ForegroundColor Cyan -NoNewLine
Write-Host "$backupHistorySpreadsheet" -ForegroundColor Yellow

Write-Host "###############################################" -ForegroundColor DarkYellow
Write-Host "############ Execution Times ##################" -ForegroundColor DarkYellow
Write-Host "###############################################" -ForegroundColor DarkYellow

Write-Host "The total number of Servers/Clusters checked is:" -ForegroundColor Cyan -NoNewline
Write-Host "$($Servers.Count)" -ForegroundColor Yellow
Write-Host "The number of alive servers is:" -ForegroundColor Cyan -NoNewline
Write-Host "$($ServerList.Count)" -ForegroundColor Yellow
Write-Host "The number of clusters is:" -ForegroundColor Cyan -NoNewline
Write-Host "$($clNames.Count)" -ForegroundColor Yellow
Write-Host "The number of SQL instances is:" -ForegroundColor Cyan -NoNewline
Write-Host "$($allSQLInstances.Count)" -ForegroundColor Yellow
Write-Host "The number of SQL AlwaysOn Availability Groups is:" -ForegroundColor Cyan -NoNewline
Write-Host "$($agNames.Count)" -ForegroundColor Yellow

$stopWatch.Stop()

Write-Host "Total script run time (ms): " -ForegroundColor Cyan -NoNewline
Write-Host "$($stopWatch.Elapsed.TotalMilliseconds)" -ForegroundColor Yellow

Write-Host "Total script run time (sec): " -ForegroundColor Cyan -NoNewline
Write-Host "$($stopWatch.Elapsed.TotalSeconds)" -ForegroundColor Yellow

Write-Host "Total script run time (min): " -ForegroundColor Cyan -NoNewline
Write-Host "$($stopWatch.Elapsed.TotalMinutes)" -ForegroundColor Yellow

Stop-Transcript

Write-Host "Data collection completed..."
# Read-Host -Prompt "Jobs completed. Press any key to continue"

# Other stuff TO-DO:
#
#     - Add error handling.
#     - Add optional parameter to scan Active Directory domain/OU for SQL servers (instead of using an array or file). 
#                  - Note: This requires customers to have their own domain. 
