#######################################################################################################################################
#
#
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
#               .\PS_SQL_DB_Info.ps1
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

# Must be run on server with sql invoke-sqlcmd enabled (i.e. a server/workstation that has the SQL Client Connectivity tools installed).
# Note, the SQL Client Connectivity Tools are not the same as SQL Management studio. SSMS does not need to be installed for this to run.

. $PSScriptRoot\IncludeMe.ps1

# List SQL scripts.
# This is the SQL Query that will return the the database information and average performance data of each database file in the instance.
# This is kept external so as not have issues with formatting within the PS script itself, while also being able to be
# modified independently.

# TO-DO: Possibly make this a parameter instead of hard-coded.

$SQLStatsQuery = $PSScriptRoot + "\SQLScripts\CombinedSQLStats.sql"
# $SQLVersionInfo = $PSScriptRoot + "\SQLScripts\SQLVersionInfo.sql"

# At least one computer name must be passed to the script. For now, the script handles a file with a list of computer names.
# List of server hostnames, one hostname per line
# TO-DO: Allow variables and/or GUI input?

$Servers = Get-Content "$PSScriptRoot\myservers.txt"

# Get the Windows or SQL credentials to be used to connect to the SQL instances.

# $SQLCreds = Get-Credential

# Get the system date to timestamp the files

$datetime = get-date -f MM-dd-yyyy_hh.mm.ss

 # Use the current path and create a sub-directory of Server/Instance if it does not exist.

$targetPath = "$PSScriptRoot\SQLServerInfo\$datetime"
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

# Create a new, empty Excel document for Stand-alone Server Configuration.
$ServerConfigxlsxReportPath =  "$targetPath\ServerConfigReport-$datetime.xlsx"

Write-Host "Server Config will be written to $ServerConfigxlsxReportPath" -ForegroundColor DarkGreen

# Create a new, empty Excel document for SQL Data.
$SQLDataxlsxReportPath =  "$targetPath\SQLServerDBReport-$datetime.xlsx"
$clSQLDataxlsxReportPath =  "$targetPath\clSQLServerDBReport-$datetime.xlsx"
$agSQLDataxlsxReportPath =  "$targetPath\agSQLServerDBReport-$datetime.xlsx"

# Create a new, empty Excel document for Cluster Configuration.
$clClusterConfigxlsxReportPath =  "$targetPath\clConfigReport-$datetime.xlsx"
$agConfigxlsxReportPath =  "$targetPath\agConfigReport-$datetime.xlsx"

# Get all the server config information.

# Set the array name that we will use to hold the cluster names.
$ClusterNames = @()

# Set the array name that we will use to hold the non-cluster server names.
$ServerNames = @()

# Set the array name that we will use to hold the SQL Server configuration data.
$sqlConfig = @()
$sqlVersionConfig = @()

# Output the PowerShell screen text as debug file.

Start-Transcript -Path $logFile

# Create an array for job names.
$jobNames = @()

# Let's start by getting the server config for each of the servers. This will be for all servers, clustered or not.

if ($Servers -ne $null)
{
  Get-ServerConfig -ComputerNames $Servers -Path "$ServerConfigxlsxReportPath"
}
else
{
  Write-Host "There are no servers to check." -ForegroundColor DarkRed
}

# Determine which servers are part of a cluster and which are not.

foreach ($server in $Servers)
{
  # Let's use WMI to see if the server is part of a cluster.
  
  if (Get-IsClustered -ComputerName $server)
  {
    # If it is part of a cluster, get the cluster name from WMI (since may not have the FailoverClusters module installed), and add the cluster name to the ClusterNames array.
    # Note that this is an array of objects, not strings (we'll handle this later).
    
    Write-Host "Server $server is clustered." -ForegroundColor DarkYellow
    $ClusterNames += Get-WmiObject -Namespace root\mscluster -ComputerName $server -class mscluster_cluster | Select-Object Name
  }
  else
  {
    # If the server is not part of a cluster, add the server name to the ServerNames array.
    # Note that this is an array of strings.
    Write-Host "Server $server is NOT clustered. Checking server config..." -ForegroundColor DarkCyan
    $ServerNames += $server
  }
}

# Next, we'll get the clustered SQL instance information and data.

if ($ClusterNames -ne $null)
{
  # Strip out duplicate cluster names.

  $clNames = $ClusterNames | Select-Object Name -Unique

  # Pass the new array without duplicates to the Get-ClusterNodes function.

  Get-ClusterConfig -ClusterNames $clNames -Path $clClusterConfigxlsxReportPath
  
  foreach ($clName in $clNames)
  {
    # Call the Get-ClusterSQLInstances function to get the list of cluster SQL instance names.
  
    $clSQLInstances = Get-ClusteredSQLInstances -ClusterNames $clName
    
    # If there are no clustereds SQL instances, we'll check to see if these are AGs.
    
    if (!$clSQLInstances) 
    {
      # We know clustering is installed, but we have no 'SQL Server' type clustered resources.' We're going to check for instances of SQL now.
      # First thing, let's get the nodes of the cluster.
        
      $clNodes = get-wmiobject -Class MSCluster_node -Namespace root\mscluster -ComputerName $clName.Name | select Name
        
      # Now that we have the cluster nodes, let's instantiate an array to hold each of the server objects.
        
      $agConfigResult = @()

      foreach ($node in $clNodes)
      {
        # Now, let's check to see if SQL is on these nodes.
          
        $agSQLInstances = Get-SQLInstances02 -ComputerName $node.Name
          
        if (!$agSQLInstances)
        {
          # SQL is not installed; let's write some errors.
          # TO-DO: I'm eventually going to check if Hyper-V is installed.
          
          $errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
          $noSQLMsg = "<$errorDateTime> - Server " + $node.Name + " is online, but no SQL instances could be retrieved. Is SQL installed?"
          Write-Host "<$errorDateTime> - Server " + $node.Name + " is online, but no SQL instances could be retrieved. Is SQL installed?" -ForegroundColor Red
          $noSQLMsg | Out-File -FilePath $failedConnections -Append
        }
        else
        {
          # SQL Instances have been found!
          
          Write-Host "Stand alone SQL Instances have been found." -ForegroundColor Green
          foreach ($instance in $agSQLInstances)
          {
            # Test the connection to the SQL instance.
            # Now that we have the instance, let's check to be sure the user we are running the script can actually log in to the instance.
            
            $testDBAConnection = Test-DbaConnection -sqlinstance $instance.Name
          
            if ($testDBAConnection)
            {
              # If the connection to the SQL instance is successful, call the Get-SQLData function.       
              Get-SqlData -instanceName $instance.Name -Path $agSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
              
              # Add the SQL configuration to the global variable.
              $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance.Name
              $sqlVersionConfig += $instance
              
              # We've gotten all the database information and added to the correct file.
              # Now, we're going to check if there are any Availability Groups present.
              
              if (Get-DbaAvailabilityGroup -SqlInstance $instance.Name)
              {
                $agConfigResult += Get-DbaAvailabilityGroup -SqlInstance $instance.Name                           
              }
              else
              {
                Write-Host "No availability groups have been found."
              }
            }
            else
            {
              # If the testDBAConnection variable returns false, write an error.
              
              $errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
              $testConnectMsg = "<$errorDateTime> - No connection could be made to " + $instance.Name + ". Authentication or network issue?"
              Write-host $testConnectMsg -foregroundcolor "magenta"
              $testConnectMsg | Out-File -FilePath $failedConnections -Append
            }
            
          }
        }        
          
      }
      
      # Now that we have our array of availability groups, let's drop thewm into an excel spreadsheet, one tab per AG.
        
      if ($agConfigResult -ne $null)
      {
        foreach ($item in $agConfigResult)
        {
          # However, to avoid duplicates, let's go ahead and only write out the results that are listed as a Primary replica.
          
          if ($item.LocalReplicaRole -eq "Primary")
          {
            $agWorksheet = $item.AvailabilityGroup + "$" + $item.ComputerName
            $agTableName = $item.AvailabilityGroup + "-" + $item.ComputerName
            $excel = $agConfigResult | Export-Excel -Path $agConfigxlsxReportPath -AutoSize -WorksheetName $agWorksheet -FreezeTopRow -TableName $agTableName -PassThru
            $excel.Save() ; $excel.Dispose()
          }
        }
      }
      else
      {
        # If we have no Availability Groups returned, write a message.
        
        Write-Host "No Availability Group server data."
      }        
    }
    else
    {
      # Server is online and has clustered SQL instances. Iterate through each instance.
            
      foreach($instance in $clSQLInstances)
      {
        # Test the connection to the SQL instance.
        # Now that we have the instance, let's check to be sure the user we are running the script can actually log in to the instance.
          
        $testDBAConnection = Test-DbaConnection -sqlinstance $instance
          
        if ($testDBAConnection)
        {
          # If the connection to the SQL instance is successful, call the Get-SQLData function.       
          Get-SqlData -instanceName $instance -Path $clSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
          
          # Add the SQL configuration to the global variable.
          $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance  
          $sqlVersionConfig += $instance            
        }
        else
        {
          $errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
          $testConnectMsg = "<$errorDateTime> - No connection could be made to " + $instance + ". Authentication or network issue?"
          Write-host $testConnectMsg -foregroundcolor "magenta"
          $testConnectMsg | Out-File -FilePath $failedConnections -Append
        }

      }
    }
  }
}
else
{
  Write-Host "No clusters found." -ForegroundColor DarkRed
}

# Now that we have all the clusters out of the way, get SQL information for stand-alone servers only.

foreach ($server in $ServerNames)
{
    # Ping the server to see if it is online.
    if (Test-Connection $server -Count 2 -Quiet)
      {   
        # Determine if server is part of a cluster.

        # Since the server is online and not clustered, get the SQL instances, if they exist.
        
        $SQLInstances = Get-SQLInstances02 -ComputerName $server
        
        # Server replies to ping, but check to ensure the SQL instances were returned.
        # If no instances are returned, write an error message to the log file.

        if (!$SQLInstances) 
        { 
            $errorDateTime3 = get-date -f MM-dd-yyyy_hh.mm.ss
            $noSQLMsg = "<$errorDateTime3> - Server $server is online, but no SQL instances could be retrieved. Do you have access to the server, and is SQL installed?"
            Write-Host "No SQL Instances found on server $server." -ForegroundColor Red
            $noSQLMsg | Out-File -FilePath $failedConnections -Append
        }
        else
        {
            # Server is online and has SQL instances. Iterate through each instance.
            
            foreach($instance in $SQLInstances)
            {
                # Test the connection to the SQL instance.
                $testDBAConnection = Test-DbaConnection -sqlinstance $instance.Name
                
                # Now that we have the instance, let's check to be sure the user we are running the script can actually log in to the instance.

                if ($testDBAConnection)
                {
                    # If the connection to the SQL instance is successful, call the Get-SQLData function.       
                    Get-SqlData -instanceName $instance.Name -Path $SQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
                    
                    # Add the SQL configuration to the global variable.
                    $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance.Name   
                    $sqlVersionConfig += $instance        
                }
                else
                {
                    $errorDateTime1 = get-date -f MM-dd-yyyy_hh.mm.ss
                    $testConnectMsg = "<$errorDateTime1> - No connection could be made to " + $instance.Name + ". Authentication or network issue?"
                    Write-host $testConnectMsg -foregroundcolor "magenta"
                    $testConnectMsg | Out-File -FilePath $failedConnections -Append
                }

            }
        }
        
      }
      else
      {
        $errorDateTime2 = get-date -f MM-dd-yyyy_hh.mm.ss
        $errorMsg = "<$errorDateTime2> - No connection to $server could be made." 
        Write-host $errorMsg -foregroundcolor "magenta"
        $errorMsg | Out-File -FilePath $failedConnections -Append                
    }

}

# As a last step, we will export all SQL server config data to a different spreadsheet.

$sqlConfigWorksheet = "SQL Configs"
$sqlConfigTable = "SQL_SP_Configs"

$sqlVersionConfigWorksheet = "SQL Versions"
$sqlVersionConfigTable = "SQLVersionConfigs"

$sqlConfigSpreadsheet =  "$targetPath\sqlConfig-$datetime.xlsx"

if ($sqlConfig -ne $null)
{
  $excel2 = $sqlVersionConfig | Export-Excel -Path $sqlConfigSpreadsheet -Autosize -Worksheet $sqlVersionConfigWorksheet -FreezeTopRow -TableStyle 'Medium6' -TableName $sqlVersionConfigTable -PassThru
  $excel2.Save() ; $excel2.Dispose()
  $excel = $sqlConfig | Export-Excel -Path $sqlConfigSpreadsheet -AutoSize -WorksheetName $sqlConfigWorksheet -FreezeTopRow -TableStyle 'Medium6' -TableName $sqlConfigTable -PassThru
  $excel.Save() ; $excel.Dispose()
}
else
{
  Write-Host "No SQL Data to export." -ForegroundColor Red
}


# Write-Host "Press any key to continue ..."
# $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Get-Job
Stop-Transcript

# Other stuff TO-DO:
#
#     - Add error handling.
#     - Add credential parameter to specify SQL logon credentials.
#     - Add script auto-elevation prompt.
#     - Add optional parameter to scan Active Directory domain/OU for SQL servers (instead of using an array or file). 
#                  - Note: This requires customers to have their own domain. 
#     - Determine if we can use an Excel portable dll to create spreadsheets/pivot tables.
#     - Add date time stamp to files for historical records.