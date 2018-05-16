#######################################################################################################################################
#
#
#
#    Script: Get-SQLConfig function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         Returns the running configuration of a SQL Instance.
#    Usage: 
#           - Source the function and pass the instance name as a parameter.
#           - This script also uses dbatools PowerShell module.
#
#    Examples:
#               . .\Get-SQLConfig.ps1
#
#               Get-SQLConfig -instanceName SERVER\Instance
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

function Get-SQLConfig
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
            Write-Host "No connection could be made using Domain credentials." -ForegroundColor Red
        }
              
        if (!$testDBAConnectionDomain)
        {     
            try
            {
                $testDBAConnectionSQL = Test-DbaConnection -sqlinstance $instance -SQLCredential $sqlCred
            }
            catch
            {
                Write-Host "No connection could be made using SQL credentials." -ForegroundColor Red
            }
        }
          
        if (($testDBAConnectionDomain -and $testDBAConnectionSQL) -or ($testDBAConnectionDomain -and !($testDBAConnectionSQL)))
        {
            $sqlConfig = Get-DbaSpConfigure -SqlInstance $instance
        }
        elseif (!($testDBAConnectionDomain) -and $testDBAConnectionSQL)
        {
            $sqlConfig = Get-DbaSpConfigure -SqlInstance $instance -SQLCredential $sqlCred
        }        
        else
        {
            $errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
            $testConnectMsg = "<$errorDateTime> - No connection could be made to " + $instance + ". Authentication or network issue?"
            Write-host $testConnectMsg -foregroundcolor "magenta"
            # $testConnectMsg | Out-File -FilePath $failedConnections -Append
        }

        $sqlConfig
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

  Write-Host "Getting SQL sp_configure output..." -NoNewline -ForegroundColor Green

  Do
  {
    Write-Host "." -NoNewline -ForegroundColor Green
    Start-Sleep -Milliseconds 200
  } while ($sqlConfigJobs.Result.IsCompleted -contains $false)

  $sqlSPConfig = @()

  ForEach ($sqlConfigJob in $sqlConfigJobs) 
  {     
    $sqlSPConfig += $sqlConfigJob.Pipe.EndInvoke($sqlConfigJob.Result)
  }

  Write-Host "All jobs completed!" -ForegroundColor Green

  $sqlConfigRunspacePool.Close()
  $sqlConfigRunspacePool.Dispose()

  return $sqlSPConfig  
  
}