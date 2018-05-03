#######################################################################################################################################
#
#
#
#    Script: Get-SQLAGConfig function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         Returns the configuration of all availability groups in a list of SQL instances.
#    Usage: 
#           - Source the function and pass the instance name as a parameter.
#           - This script also uses dbatools PowerShell module.
#
#    Examples:
#               . .\Get-SQLAGConfig
#
#               Get-SQLAGConfig -instanceNames "SERVER\Instance01","SERVER02\Instance02" -SQLCredential (Get-Credential)
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

function Get-SQLAGConfig
{

  # This is the -instance.Name parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
  Param(
      [parameter(Mandatory=$true,ValueFromPipeline=$True)][string[]]$instanceNames,
      [parameter(Mandatory=$false,ValueFromPipeline=$True)] $SQLCredential
  )

  $parent = Split-Path -Path $PSScriptRoot -Parent

  $SQLConfigScript = {

        Param ($instance,$parent,$sqlCred)

        Import-module "$parent\Modules\dbatools\dbatools.psm1"

        
      try
        {
            $testDBAConnectionDomain = Test-DbaConnection -sqlinstance $instance
        }
        catch
        {            
            "No connection could be made using Domain credentials."
        }
        if (!$testDBAConnectionDomain)
        {     
            try
            {
                $testDBAConnectionSQL = Test-DbaConnection -sqlinstance $instance -SQLCredential $sqlCred
            }
            catch
            {
                "No connection could be made using SQL credentials."
            }
        }
          
        if (($testDBAConnectionDomain -and $testDBAConnectionSQL) -or ($testDBAConnectionDomain -and !($testDBAConnectionSQL)))
        {
            if (Get-DbaAvailabilityGroup -SqlInstance $instance -WarningAction SilentlyContinue)
            {
                $agConfigResult += Get-DbaAvailabilityGroup -SqlInstance $instance | select ComputerName,Name, InstanceName,SqlInstance,AvailabilityGroup,DatabaseEngineEdition,
                                                                                                PrimaryReplica,AutomatedBackupPreference,BasicAvailabilityGroup,FailureConditionLevel,
                                                                                                HealthCheckTimeout,ID,IsDistributedAvailabilityGroup,LocalReplicaRole,PrimaryReplicaServerName,
                                                                                                AvailabilityGroupListeners,State                
            }
        }
        elseif (!($testDBAConnectionDomain) -and $testDBAConnectionSQL)
        {
            $testAG = Get-DbaAvailabilityGroup -SqlInstance $instance -Credential $sqlCred -WarningAction SilentlyContinue

            if ($testAG)
            {
                $agConfigResult += Get-DbaAvailabilityGroup -SqlInstance $instance -SQLCredential $sqlCred | select ComputerName, Name,InstanceName,SqlInstance,AvailabilityGroup,DatabaseEngineEdition,
                                                                                                PrimaryReplica,AutomatedBackupPreference,BasicAvailabilityGroup,FailureConditionLevel,
                                                                                                HealthCheckTimeout,ID,IsDistributedAvailabilityGroup,LocalReplicaRole,PrimaryReplicaServerName,
                                                                                                AvailabilityGroupListeners,State                
            }
        }        
        else
        {
            $errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
            $testConnectMsg = "<$errorDateTime> - No connection could be made to " + $instance + ". Authentication or network issue?"
            Write-host $testConnectMsg -foregroundcolor "magenta"
            # $testConnectMsg | Out-File -FilePath $failedConnections -Append
        }

        $agConfigResult
    } # End script block

  
  $Throttle = 8
  $sqlConfigInitialSessionState =[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $sqlConfigRunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$Throttle,$sqlConfigInitialSessionState,$Host)
  $sqlConfigRunspacePool.Open()
  $sqlConfigJobs = @()

  foreach ($instance in $instanceNames)
  {
    $sqlConfigJob = [powershell]::Create().AddScript($SQLConfigScript).AddArgument($instance).AddArgument($parent).AddArgument($SQLCredential)
    $sqlConfigJob.RunspacePool = $sqlConfigRunspacePool
    $sqlConfigJobs += New-Object PSObject -Property @{
      Pipe = $sqlConfigJob
      Result = $sqlConfigJob.BeginInvoke()
    } 
  }

  Write-Host "Getting Availability Group Configuration..." -NoNewline -ForegroundColor Green

  Do
  {
    Write-Host "." -NoNewline -ForegroundColor Green
    Start-Sleep -Milliseconds 200
  } while ($sqlConfigJobs.Result.IsCompleted -contains $false)

  $agsqlConfig = @()

  ForEach ($sqlConfigJob in $sqlConfigJobs) 
  {     
    $agsqlConfig += $sqlConfigJob.Pipe.EndInvoke($sqlConfigJob.Result)
  }

  Write-Host "All jobs completed!" -ForegroundColor Green

  $sqlConfigRunspacePool.Close()
  $sqlConfigRunspacePool.Dispose()

  return $agsqlConfig  
  
}