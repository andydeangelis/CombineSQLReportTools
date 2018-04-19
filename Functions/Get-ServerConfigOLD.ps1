#######################################################################################################################################
#
#
#
#    Script: Get-ServerConfig function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         Returns all relevant server config data and exports that data to a spreadsheet.
#    Usage: 
#    Usage: 
#           - Multiple servers can be passed to the -ComputerNames paramater.
#           - The user running the script needs to be a local administrator on the target servers to gather WMI data.
#           - This script also uses dbatools.
#           - The result returned is an array of objects that can then be passed to anything (CSV, Excel, other functions, etc.)
#    Examples:
#               . .\Get-ServerConfig.ps1
#
#               Get-ServerConfig -ComputerName SERVER1,SERVER2,SERVER3
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

# Function to get Server Configuration info for all servers in the my_servers.txt file.
# Only works for Windows.
# At some point, add support to query for Linux as well.

function Get-ServerConfig
{

  # This is the -instance.Name parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
  Param(
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $ComputerName
   #   [parameter(Mandatory=$true,ValueFromPipeline=$True)] $Path
  )
  
  $ServerConfigResult = @()
  
  # Let's get some data. For each server in the $ComputerNames array. get target computer system information and add it to the array.
  
  foreach ($server in $ComputerName)
  {
    # Ping the server to see if it is online.
    if ($server -ne $null)
    {
        if (Test-Connection $server -Count 2 -Quiet)
        {
          Write-Host "Server $server is online. Checking OS..." -foregroundcolor Cyan
      
          # Server is responding to ping, but let's make sure it's a Windows machine.
      
          try
          {
            $isWindows = (Get-WmiObject Win32_OperatingSystem -ComputerName $server -erroraction 'silentlycontinue').Name         
          }
          catch
          {
            Write-Host "Unable to connect to $server. Is this a Windows OS?" -ForegroundColor Red
          }
          if ($isWindows)
          {
            Write-Host "Server $server is Windows. Checking cluster membership..." -foregroundcolor Cyan

        
            $ServerConfigObject = Get-DbaComputerSystem -ComputerName $server
            $ServerOSObject = Get-DbaOperatingSystem -ComputerName $server
            
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name TotalVisibleMemory -Value $ServerOSObject.TotalVisibleMemory
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name FreePhysicalMemory -Value $ServerOSObject.FreePhysicalMemory
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name TotalVirtualMemory -Value $ServerOSObject.TotalVirtual
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name FreeVirtualMemory -Value $ServerOSObject.FreeVirtualMemory
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name OperatingSystem -Value (Get-WMIObject win32_OperatingSystem -ComputerName $server).Caption
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name Version -Value (Get-WMIObject win32_OperatingSystem -ComputerName $server).Version
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name ServicePackMajorVersion -Value (Get-WMIObject win32_OperatingSystem -ComputerName $server).ServicePackMajorVersion
            $ServerConfigObject | Add-Member -MemberType NoteProperty -Name ServicePackMinorVersion -Value (Get-WMIObject win32_OperatingSystem -ComputerName $server).ServicePackMinorVersion
            
            if ((Get-WMIObject -Namespace root\mscluster -ComputerName $server -Class MSCluster_cluster -ErrorAction SilentlyContinue) -ne $null)
            {
              $ServerConfigObject | Add-Member -MemberType NoteProperty -Name IsClustered -Value 'Yes'
              $ServerConfigObject | Add-Member -MemberType NoteProperty -Name ClusterName -Value (Get-WMIObject -Namespace root\mscluster -ComputerName $server -Class MSCluster_cluster).Name
            }
            else
            {
              $ServerConfigObject | Add-Member -MemberType NoteProperty -Name IsClustered -Value 'No'
              $ServerConfigObject | Add-Member -MemberType NoteProperty -Name ClusterName -Value 'NOT CLUSTERED'
            }
            
            $ServerConfigObject.PSObject.Properties.Remove('SystemSkuNumber')
            $ServerConfigObject.PSObject.Properties.Remove('IsDaylightSavingsTime')
            $ServerConfigObject.PSObject.Properties.Remove('DaylightInEffect')
            $ServerConfigObject.PSObject.Properties.Remove('AdminPasswordStatus')
            $ServerConfigObject.PSObject.Properties.Remove('TotalPhysicalMemory')
            
            $ServerConfigResult += $ServerConfigObject   
          
          }
        }
        else
        {
          Write-Host "Server $server can not be contacted." -foregroundcolor Red
        }
    }
    else
    {
        Write-Host "Server name is null."
    }
    
  }
 
  return $ServerConfigResult
  
}