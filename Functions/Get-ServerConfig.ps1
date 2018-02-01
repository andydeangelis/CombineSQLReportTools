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
#           - This script also uses dbatools and ImportExcel PowerShell modules.
#    Examples:
#               . .\Get-ServerConfig.ps1
#
#               Get-ServerConfig -ComputerName SERVER1,SERVER2,SERVER3 -Path <PATH_TO_EXCEL_OUTPUT>
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
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $ComputerNames,
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $Path
  )
  
  Write-Host "Stand-alone server config will be stored in $Path" -ForegroundColor DarkMagenta
  
  $ServerConfigResult = @()
  $ServerDiskCOnfig = @()
  # $ServerOS = @()
  
  # Let's get some data. For each server in the $ComputerNames array. get target computer system information and add it to the array.
  
  foreach ($server in $ComputerNames)
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
            
            $ServerDiskConfig += Get-DbaDiskSpace -ComputerName $server                                                                    
        
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

  # Set the worksheet name. We will have a single Excel file with one tab per Server.
  
  $ServerConfigWorksheet = "Server Config"
  $ServerDiskConfigWorksheet = "Disk Config"
  # $ServerOSWorksheet = "Operating Systems"
    
  # Set the table names for the worksheet.
  
  $ServerConfigTableName = "ServerConfig"
  $ServerDiskConfigTableName = "DiskConfig"
  # $ServerOSTableName = "OSConfig"
  
  # TO-DO: Add some error handling here (i.e. check to ensure the arrays are not empty or null).
    
  if (($ServerConfigResult -ne $null) -and ($ServerDiskConfig -ne $null))
  {
    $excel = $ServerConfigResult | Export-Excel -Path $Path -AutoSize -WorksheetName $ServerConfigWorksheet -FreezeTopRow -TableName $ServerConfigTableName -PassThru
    $excel.Save() ; $excel.Dispose()
    $excel2 = $ServerDiskConfig | Export-Excel -Path $Path -AutoSize -WorksheetName $ServerDiskConfigWorksheet -FreezeTopRow -TableName $ServerDiskConfigTableName -PassThru
    $excel2.Save() ; $excel2.Dispose()
    # $ServerOS | Export-Excel -Path $Path -AutoSize -WorksheetName $ServerOSWorksheet -FreezeTopRow -TableName $ServerOSTableName
  }
  else
  {
    Write-Host "No stand-alone server data."
  }
    
}