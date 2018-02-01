#######################################################################################################################################
#
#    Script: Get-SQLInstances02 function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         This is a replacement for the Get-SQLInstances function within the SQLPS module. The included Get-SQLInstances function is
#         primarily for Azure SQL instances and requires the SQL Cloud Adapter, which doesn't really work. The idea is to pass a host
#         name and return the names of all SQL instances on the host name. It's not elegant, and will be re-written to use WMI eventually.
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
        [parameter(Mandatory=$true,ValueFromPipeline=$True)] [string[]]$ComputerName
    )

    # Generate instances on target machine from service list. Not the most elegant, but if the SQL Browser Service isn't running, we can't use the GetDataSources method.
    # Should probably change this to use WMI instead of the Get-Service cmdlet.
     
    if(Test-Connection $ComputerName -Count 2 -Quiet)
    {
      # We need to get the correct Namespace name to query, as it changes per version of SQL Serever.
      # For example, SQL 2014 is ROOT\Microsoft\SqlServer\ComputerManagement12 where SQL 2016 is ROOT\Microsoft\SqlServer\ComputerManagement13.
      # Wildcards are not allowed in the Namespace parameter of the Get-WMIObject cmdlet.
      try
      {
        $nameSpaceName = get-wmiobject -Namespace root\Microsoft\SQLServer -Class __Namespace -ComputerName $ComputerName -ErrorAction SilentlyContinue| Where-Object {$_.Name -like "ComputerManagement*"} | Select Name
        $nameSpaceString = "ROOT\Microsoft\SqlServer\" + $nameSpaceName.Name
        $instanceArray = get-wmiobject -Namespace $nameSpaceString -class ServerNetworkProtocol -ComputerName $ComputerName -ErrorAction SilentlyContinue | Where-Object {$_.ProtocolName -eq "Tcp"} | select PSComputerName,InstanceName
      }
      catch
      {
        Write-Host "No SQL instances found in WMI." -ForegroundColor Cyan
      }
    }
     
      # Iterate through each SQL instance on the target server and return the object back to the main script.

      foreach ($instance in $instanceArray)
      {
        #Check to see if the SQL service is running as the default instance.

        if ($instance.InstanceName -eq "MSSQLSERVER")
        {
            $instanceName = $ComputerName
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
            $instanceName = "$Computername\" + $instance.InstanceName
            # Write-Host $instanceName -ForegroundColor Green
        }
        # For the SQL instance, create a new SQL Management Object to retrieve data and connect.

        $svr = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instanceName
        # $svr | get-member

        # Return the listed data. There are more members available, so this can be modified if need be.
        # $svr | Select-Object Name
        $svr | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
      } 
}
 