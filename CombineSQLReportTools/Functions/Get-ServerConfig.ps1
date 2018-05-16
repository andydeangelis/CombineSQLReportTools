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
		[parameter(Mandatory = $true, ValueFromPipeline = $True)]
		$ComputerName,
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$domainCredential
   #   [parameter(Mandatory=$true,ValueFromPipeline=$True)] $Path
  )
  
  # Let's get some data. For each server in the $ComputerNames array. get target computer system information and add it to the array.
  # Since we are using the PoshRSJobs module, we will create the script blobk below.

  $getSvrConfigScript = {

        Param ($server,$parent,$domainCred)

        Import-module "$parent\Modules\dbatools\dbatools.psm1"
        
        # Ping the server to see if it is online.
        if ($server -ne $null)
        {
            # Server is responding to ping, but let's make sure it's a Windows machine.              
      
            try
			{
				if (-not $domainCred)
				{
					$isWindows = (Get-WmiObject Win32_OperatingSystem -ComputerName $server -erroraction 'silentlycontinue').Name
				}
				else
				{
					$isWindows = (Get-WmiObject Win32_OperatingSystem -ComputerName $server -Credential $domainCred -erroraction 'silentlycontinue').Name
				}
			}
			catch
			{
				Write-Host "Unable to connect to $server. Is this a Windows OS?" -ForegroundColor Red
			}
			if ($isWindows)
            {
				
				if (-not $domainCred)
				{
					$ServerConfigObject = Get-DbaComputerSystem -ComputerName $server -WarningAction SilentlyContinue
					$ServerOSObject = Get-DbaOperatingSystem -ComputerName $server -WarningAction SilentlyContinue
				}
				else
				{
					$ServerConfigObject = Get-DbaComputerSystem -ComputerName $server -Credential $domainCred -WarningAction SilentlyContinue
					$ServerOSObject = Get-DbaOperatingSystem -ComputerName $server -Credential $domainCred -WarningAction SilentlyContinue
				}
				
            
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
            
            # $Using:ServerConfigResult += $ServerConfigObject

            $ServerConfigObject  
                
              }           
        }
        else
        {
            Write-Host "Server name is null."
        }
       
    }

  $getDiskConfigScript = {

        Param ($server,$parent,$domainCred)

        Import-module "$parent\Modules\dbatools\dbatools.psm1"

        if ($server -ne $null)
        {
            # Server is responding to ping, but let's make sure it's a Windows machine.              
      
            try
			{
				if (-not $domainCred)
				{
					$isWindows = (Get-WmiObject Win32_OperatingSystem -ComputerName $server -erroraction 'silentlycontinue').Name
				}
				else
				{
					$isWindows = (Get-WmiObject Win32_OperatingSystem -ComputerName $server -Credential $domainCred -erroraction 'silentlycontinue').Name
				}
			}
			catch
			{
				Write-Host "Unable to connect to $server. Is this a Windows OS?" -ForegroundColor Red
			}
			if ($isWindows)
            {
				
				if (-not $domainCred)
				{
					$ServerDiskConfigObject = Get-DbaDiskSpace -ComputerName $server | Select ComputerName, Server, Name, Label, Capacity,
																							  Free, PercentFree, BlockSize, FileSystem, Type,
																							  DriveType, SizeInGB, FreeInGB, SizeInTB, FreeInTB
					
					if ((Get-WMIObject -Namespace root\mscluster -ComputerName $server -Class MSCluster_cluster -ErrorAction SilentlyContinue) -ne $null)
					{
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name IsClustered -Value 'Yes'
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name ClusterName -Value (Get-WMIObject -Namespace root\mscluster -ComputerName $server -Class MSCluster_cluster).Name
					}
					else
					{
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name IsClustered -Value 'No'
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name ClusterName -Value 'NOT CLUSTERED'
					}
				}
				else
				{
					$ServerDiskConfigObject = Get-DbaDiskSpace -ComputerName $server -Credential $domainCred | Select ComputerName, Server, Name, Label, Capacity,
																													  Free, PercentFree, BlockSize, FileSystem, Type,
																													  DriveType, SizeInGB, FreeInGB, SizeInTB, FreeInTB
					
					if ((Get-WMIObject -Namespace root\mscluster -ComputerName $server -Class MSCluster_cluster -Credential $domainCred -ErrorAction SilentlyContinue) -ne $null)
					{
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name IsClustered -Value 'Yes'
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name ClusterName -Value (Get-WMIObject -Namespace root\mscluster -ComputerName $server -Class MSCluster_cluster).Name
					}
					else
					{
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name IsClustered -Value 'No'
						$ServerDiskConfigObject | Add-Member -MemberType NoteProperty -Name ClusterName -Value 'NOT CLUSTERED'
					}
				}
				
				$ServerDiskConfigObject
                
            }
        }
        else
        {
            Write-Host "Server name is null."
        }
       
    }

  $parent = Split-Path -Path $PSScriptRoot -Parent    
  
  # For each server, start a separate runspace job.

  $Throttle = 8
  $svrConfigInitialSessionState =[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $svrConfigRunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$Throttle,$svrConfigInitialSessionState,$Host)
  $svrConfigRunspacePool.Open()
  $svrConfigJobs = @()

  foreach ($server in $ComputerName)
  {
    $svrConfigJob = [powershell]::Create().AddScript($getSvrConfigScript).AddArgument($server).AddArgument($parent).AddArgument($domainCredential)
    $svrConfigJob.RunspacePool = $svrConfigRunspacePool
    $svrConfigJobs += New-Object PSObject -Property @{
      Pipe = $svrConfigJob
      Result = $svrConfigJob.BeginInvoke()
    } 
  }

  $svrDiskConfiginitialSessionState =[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $svrDiskConfigRunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$Throttle,$svrDiskConfigInitialSessionState,$Host)
  $svrDiskConfigRunspacePool.Open()
  $svrDiskConfigJobs = @()

  foreach ($server in $ComputerName)
  {
    $svrDiskConfigJob = [powershell]::Create().AddScript($getDiskConfigScript).AddArgument($server).AddArgument($parent).AddArgument($domainCredential)
    $svrDiskConfigJob.RunspacePool = $svrDiskConfigRunspacePool
    $svrDiskConfigJobs += New-Object PSObject -Property @{
      Pipe = $svrDiskConfigJob
      Result = $svrDiskConfigJob.BeginInvoke()
    } 
  }
  
  $svrConfigResults = @()
  $svrDiskConfigResults = @()

  Write-Host "Getting server configuration..." -NoNewline -ForegroundColor Green

  Do
  {
	Write-Host "." -NoNewline -ForegroundColor Green
	Start-Sleep -Milliseconds 200
  } while (($svrConfigJobs.Result.IsCompleted -contains $false) -or ($svrDiskConfigJobs.Result.IsCompleted -contains $false))

  ForEach ($svrConfigJob in $svrConfigJobs) 
  {       
    $svrConfigResults += $svrConfigJob.Pipe.EndInvoke($svrConfigJob.Result)
  }

  ForEach ($svrDiskConfigJob in $svrDiskConfigJobs) 
  {       
    $svrDiskConfigResults += $svrDiskConfigJob.Pipe.EndInvoke($svrDiskConfigJob.Result)
  }

  Write-Host "All jobs completed!" -ForegroundColor Green

# $Results | Out-GridView
  $svrConfigRunspacePool.Close()
  $svrConfigRunspacePool.Dispose()

  $svrDiskConfigRunspacePool.Close()
  $svrDiskConfigRunspacePool.Dispose()
 
  return $svrConfigResults,$svrDiskConfigResults
  
}