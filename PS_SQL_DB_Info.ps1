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

# Add the required .NET assembly for Windows Forms.
Add-Type -AssemblyName System.Windows.Forms

# Show the MsgBox. This is going to ask if the user needs to specify a separate SQL logon.
$result = [System.Windows.Forms.MessageBox]::Show('Do you need to specify a separate SQL logon account?', 'Warning', 'YesNo', 'Warning')

# Check the result. If the user needs to specify a separate SQL logon, they will be prompted with a credential dialog.
if ($result -eq 'Yes')
{
  $sqlCred = Get-Credential -Message "Please specify your SQL username and password."  
}
else
{
  Write-Warning 'No SQL logon specifed. Using domain account...'
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

Write-Host "Server Config will be written to $ServerConfigxlsxReportPath" -ForegroundColor DarkGreen

# Create a new, empty Excel document for SQL Data.
$SQLDataxlsxReportPath =  "$targetPath\StandaloneSQLServerDBReport-$datetime.xlsx"
$clSQLDataxlsxReportPath =  "$targetPath\ClusteredSQLServerDBReport-$datetime.xlsx"
$agSQLDataxlsxReportPath =  "$targetPath\AvailabilityGroupSQLServerDBReport-$datetime.xlsx"

# Create a new, empty Excel document for Cluster Configuration.
$clClusterConfigxlsxReportPath =  "$targetPath\ClusterConfigReport-$datetime.xlsx"
$agConfigxlsxReportPath =  "$targetPath\AvailabilityGroupConfigReport-$datetime.xlsx"

# Get all the server config information.

# Set the array name that we will use to hold the cluster names.
$ClusterNames = @()

# Set the array name that we will use to hold the non-cluster server names.
$ServerNames = @()

# Set the array name that we will use to hold the SQL Server configuration data.
$sqlConfig = @()
$sqlVersionConfig = @()

# Create an array that will hold the SQL best practices data.
$sqlBP = @()

# Output the PowerShell screen text as debug file.

Start-Transcript -Path $logFile

# Create an array for job names.
$jobNames = @()

# Let's start by getting the server config for each of the servers. This will be for all servers, clustered or not.

if ($Servers -ne $null)
{
  # First, we'll get the server data returned as an array.

  $ServerConfigResult = Get-ServerConfig -ComputerName $Servers
  
  # Next, let's get the disk configuration data. We'll start by declaring the array that we will hold the disk config objects in.
  
  $ServerDiskCOnfig = @()

  # Now, we'll iterate through each server in the list, get the data, and add it to the array.

  foreach ($server in $Servers)
  {
    if (Test-Connection $server -Count 2 -Quiet)
    {
        $ServerDiskConfig += Get-DbaDiskSpace -ComputerName $server
    }
    else
    {
        Write-Host "Unable to connect to $server." -ForegroundColor Red
    }
  }

  # Set the worksheet names. 
  
  $ServerConfigWorksheet = "Server Config"
  $ServerDiskConfigWorksheet = "Disk Config"
      
  # Set the table names for the worksheet.
  
  $ServerConfigTableName = "ServerConfig"
  $ServerDiskConfigTableName = "DiskConfig"
    
  # TO-DO: Add some error handling here (i.e. check to ensure the arrays are not empty or null).
    
  if (($ServerConfigResult -ne $null) -and ($ServerDiskConfig -ne $null))
  {
    # Create a new, empty Excel document for Stand-alone Server Configuration.
    $ServerConfigxlsxReportPath =  "$targetPath\ServerConfigReport-$datetime.xlsx"
    
    $excel = $ServerConfigResult | Export-Excel -Path $ServerConfigxlsxReportPath -AutoSize -WorksheetName $ServerConfigWorksheet -FreezeTopRow -TableName $ServerConfigTableName -PassThru
    $excel.Save() ; $excel.Dispose()
    $excel2 = $ServerDiskConfig | Export-Excel -Path $ServerConfigxlsxReportPath -AutoSize -WorksheetName $ServerDiskConfigWorksheet -FreezeTopRow -TableName $ServerDiskConfigTableName -PassThru
    $excel2.Save() ; $excel2.Dispose()
    # $ServerOS | Export-Excel -Path $Path -AutoSize -WorksheetName $ServerOSWorksheet -FreezeTopRow -TableName $ServerOSTableName
  }
  else
  {
    Write-Host "No server data found."
  }
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

  # Instantiate an array to hold the core cluster configurations.
    
  $clCoreConfig = @()
    
  # Instantiate an array to hold the resource config.
   
  $clResourceConfig = @()
  
  # For each unique name in the $clNames array (each unique cluster name), call the Get-ClusterConfig function to get the core cluster config info, then output the data to a spreadsheet.

  foreach ($name in $clNames)
  {
    $clCoreConfig += Get-ClusterConfig -ClusterName $name.Name
    $clResources = Get-WmiObject -Namespace root\mscluster -ComputerName $name.Name -Class mscluster_resource | Where-Object {$_.OwnerGroup -ne "Cluster Group"} |
                        Select-Object OwnerGroup,OwnerNode,CoreResource,Type,IsClusterSharedVolume       

    # Set the worksheet name for the server's config.
    $clResourceWorksheet = $name.Name + " Resources"
        
    # Set the table name for the worksheet.
    $clResourceTable = "Table" + $name.Name
        
    # Export the resources to a new tab in the Excel spreadsheet, one tab per customer.
        
    if ($clResources -ne $null)
    {
        $excel = $clResources | Export-Excel -Path $clClusterConfigxlsxReportPath -AutoSize -WorksheetName $clResourceWorksheet -FreezeTopRow -TableName $clResourceTable -PassThru        
        $excel.Save() ; $excel.Dispose()
    }
    else
    {
        Write-Host "No cluster data found."
    }
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
  
  foreach ($clName in $clNames)
  {
    # Call the Get-ClusterSQLInstances function to get the list of cluster SQL instance names.
  
    $clSQLInstances = Get-ClusteredSQLInstances -ClusterNames $clName.Name
    
    # If there are no clustereds SQL instances, we'll check to see if these are AGs.
    
    if (!$clSQLInstances) 
    {
      # We know clustering is installed, but we have no 'SQL Server' type clustered resources.' We're going to check for instances of SQL now.
      # First thing, let's get the nodes of the cluster.
        
      $clNodes = get-wmiobject -Class MSCluster_node -Namespace root\mscluster -ComputerName $clName.Name | select Name
        
      # Now that we have the cluster nodes, let's instantiate an array to hold each of the server objects. This array is only valid during this loop.
        
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
          
          Write-Host "SQL Instances have been found." -ForegroundColor Green
          foreach ($instance in $agSQLInstances)
          {
            # Test the connection to the SQL instance.
            # First we will try to connect to the instance using the domain credentials, then, if specified, we'll use the SQL credentials.

            try
            {
                $testDBAConnectionDomain = Test-DbaConnection -sqlinstance $instance
            }
            catch
            {
              "No connection could be made using domain credentials."
            }
            
            try
            {
               $testDBAConnectionSQL = Test-DbaConnection -sqlinstance $instance -SQLCredential $sqlCred
            }
            catch
            {
              "No connection could be made using SQL credentials."
            }
            
            # If domain credential connections are successful, use domain credentials, regardless if SQL creds are specified or successful.

            if (($testDBAConnectionDomain -and $testDBAConnectionSQL) -or ($testDBAConnectionDomain -and !($testDBAConnectionSQL)))
            {
              # If the connection to the SQL instance is successful, call the Get-SQLData function.       
              Get-SqlData -instanceName $instance -Path $agSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
              
              $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
                              
              $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
              $bpTest = Test-SQLBP -instanceName $instance -ComputerName $node.Name
              
              # Add the SQL configuration to the global variable.
              $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance
              $sqlVersionConfig += $config
              $sqlBP += $bpTest
              
              # We've gotten all the database information and added to the correct file.
              # Now, we're going to check if there are any Availability Groups present.
              
              if (Get-DbaAvailabilityGroup -SqlInstance $instance)
              {
                $agConfigResult = Get-DbaAvailabilityGroup -SqlInstance $instance | select Name,ComputerName,InstanceName,SqlInstance,AvailabilityGroup,DatabaseEngineEdition,
                                                                                                  PrimaryReplica,AutomatedBackupPreference,BasicAvailabilityGroup,FailureConditionLevel,
                                                                                                  HealthCheckTimeout,ID,IsDistributedAvailabilityGroup,LocalReplicaRole,PrimaryReplicaServerName,
                                                                                                  AvailabilityGroupListeners,State                
              }
              else
              {
                Write-Host "No availability groups have been found."
              }
            }
            # If domain credentials are unsuccessful and SQL credentials are successful, use SQL credentials.

            elseif (!($testDBAConnectionDomain) -and $testDBAConnectionSQL)
            {
              # If the connection to the SQL instance is successful, call the Get-SQLData function.       
              Get-SqlData -instanceName $instance -Path $agSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery -Credential $sqlCred
              
              $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
              $edition.ConnectionContext.LoginSecure=$false
              $edition.ConnectionContext.set_Login($sqlCred.UserName)
              $edition.ConnectionContext.set_SecurePassword($sqlCred.Password)
                
              $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
              $bpTest = Test-SQLBP -instanceName $instance -ComputerName $node.Name -Credential $sqlCred
              
              # Add the SQL configuration to the global variable.
              $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance -SQLCredential $sqlCred
              $sqlVersionConfig += $config
              $sqlBP += $bpTest
              
              # We've gotten all the database information and added to the correct file.
              # Now, we're going to check if there are any Availability Groups present.
              
              if (Get-DbaAvailabilityGroup -SqlInstance $instance -Credential $sqlCred)
              {
                $agConfigResult = Get-DbaAvailabilityGroup -SqlInstance $instance -SQLCredential $sqlCred | select Name,ComputerName,InstanceName,SqlInstance,AvailabilityGroup,DatabaseEngineEdition,
                                                                                                  PrimaryReplica,AutomatedBackupPreference,BasicAvailabilityGroup,FailureConditionLevel,
                                                                                                  HealthCheckTimeout,ID,IsDistributedAvailabilityGroup,LocalReplicaRole,PrimaryReplicaServerName,
                                                                                                  AvailabilityGroupListeners,State                
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
              $testConnectMsg = "<$errorDateTime> - No connection could be made to $instance . Authentication or network issue?"
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
        # First we will try to connect to the instance using the domain credentials, then, if specified, we'll use the SQL credentials.

        try
        {
            $testDBAConnectionDomain = Test-DbaConnection -sqlinstance $instance
        }
        catch
        {
          "No connection could be made using Domain credentials."
        }
              
        try
        {
            $testDBAConnectionSQL = Test-DbaConnection -sqlinstance $instance -SQLCredential $sqlCred
        }
        catch
        {
          "No connection could be made using SQL credentials."
        }
          
        if (($testDBAConnectionDomain -and $testDBAConnectionSQL) -or ($testDBAConnectionDomain -and !($testDBAConnectionSQL)))
        {
          # If the connection to the SQL instance is successful, call the Get-SQLData function.       
          Get-SqlData -instanceName $instance -Path $clSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
          
          $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
                
          $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
          $bpTest = Test-SQLBP -instanceName $instance -ComputerName $clName.Name -IsClustered $true
              
          # Add the SQL configuration to the global variable.
          $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance
          $sqlVersionConfig += $config
          $sqlBP += $bptest
        }
        elseif (!($testDBAConnectionDomain) -and $testDBAConnectionSQL)
        {
          # If the connection to the SQL instance is successful, call the Get-SQLData function.       
          Get-SqlData -instanceName $instance -Path $clSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery -Credential $sqlCred
          
          $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
          $edition.ConnectionContext.LoginSecure=$false
          $edition.ConnectionContext.set_Login($sqlCred.UserName)
          $edition.ConnectionContext.set_SecurePassword($sqlCred.Password)
                
          $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
          $bpTest = Test-SQLBP -instanceName $instance -ComputerName $clName.Name -Credential $sqlCred -IsClustered $true
              
          # Add the SQL configuration to the global variable.
          $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance -SQLCredential $sqlCred
          $sqlVersionConfig += $config
          $sqlBP += $bpTest
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
              # First we will try to connect to the instance using the domain credentials, then, if specified, we'll use the SQL credentials.

              try
              {
                  $testDBAConnectionDomain = Test-DbaConnection -sqlinstance $instance
              }
              catch
              {
                "No connection could be made using Domain credentials."
              }
              
              try
              {
                 $testDBAConnectionSQL = Test-DbaConnection -sqlinstance $instance -SQLCredential $sqlCred
              }
              catch
              {
                "No connection could be made using SQL credentials."
              }
                            
              # If domain credential connections are successful, use domain credentials, regardless if SQL creds are specified or successful.
            
              if (($testDBAConnectionDomain -and $testDBAConnectionSQL) -or ($testDBAConnectionDomain -and !($testDBAConnectionSQL)))
              {
                # If the connection to the SQL instance is successful, call the Get-SQLData function.       
                Get-SqlData -instanceName $instance -Path $SQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
                
                $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
                
                $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
                
                $bpTest = Test-SQLBP -instanceName $instance -ComputerName $server                
              
                # Add the SQL configuration to the global variable.
                $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance
                $sqlVersionConfig += $config
                $sqlBP += $bpTest
              }
              elseif (!($testDBAConnectionDomain) -and $testDBAConnectionSQL)
              {
                # If the connection to the SQL instance is successful, call the Get-SQLData function.       
                Get-SqlData -instanceName $instance -Path $SQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery -Credential $sqlCred
                
                $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
                $edition.ConnectionContext.LoginSecure=$false
                $edition.ConnectionContext.set_Login($sqlCred.UserName)
                $edition.ConnectionContext.set_SecurePassword($sqlCred.Password)
                
                $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
                
                $bpTest = Test-SQLBP -instanceName $instance -ComputerName $server -Credential $sqlCred
              
                # Add the SQL configuration to the global variable.
                $sqlConfig += Get-DbaSpConfigure -SqlInstance $instance -SQLCredential $sqlCred
                $sqlVersionConfig += $config
                $sqlBP += $bpTest
              }
              else
              {
                  $errorDateTime1 = get-date -f MM-dd-yyyy_hh.mm.ss
                  $testConnectMsg = "<$errorDateTime1> - No connection could be made to $instance . Authentication or network issue?"
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

# As a last step, we will export all SQL server config and best practices data to a different spreadsheet.

$sqlConfigWorksheet = "SQL Configs"
$sqlConfigTable = "SQL_SP_Configs"

$sqlVersionConfigWorksheet = "SQL Versions"
$sqlVersionConfigTable = "SQLVersionConfigs"

$sqlBPWorksheet = "SQL Best Practices"
$sqlBPTable = "SQLBestPractices"

$sqlConfigSpreadsheet =  "$targetPath\sqlConfig-$datetime.xlsx"

if (($sqlConfig -ne $null) -and ($sqlBP -ne $null))
{
  $excel2 = $sqlVersionConfig | Export-Excel -Path $sqlConfigSpreadsheet -Autosize -Worksheet $sqlVersionConfigWorksheet -FreezeTopRow -TableStyle 'Medium6' -TableName $sqlVersionConfigTable -PassThru
  $excel2.Save() ; $excel2.Dispose()
  $excel = $sqlConfig | Export-Excel -Path $sqlConfigSpreadsheet -AutoSize -WorksheetName $sqlConfigWorksheet -FreezeTopRow -TableStyle 'Medium6' -TableName $sqlConfigTable -PassThru
  $excel.Save() ; $excel.Dispose()
  # $excel3 = $sqlBP | Export-Excel -Path $sqlConfigSpreadsheet -AutoSize -WorksheetName $sqlBPWorksheet -FreezeTopRow -TableStyle 'Medium6' -TableName $sqlBPTable -PassThru
  # $excel3.Save(); $excel3.Dispose()
}
else
{
  Write-Host "No SQL Data to export." -ForegroundColor Red
}

$sqlBP | Out-File -FilePath "$targetPath\BestPractice.txt"
Read-Host -Prompt "Press any key to continue"
Stop-Transcript

# Other stuff TO-DO:
#
#     - Add error handling.
#     - Add optional parameter to scan Active Directory domain/OU for SQL servers (instead of using an array or file). 
#                  - Note: This requires customers to have their own domain. 
