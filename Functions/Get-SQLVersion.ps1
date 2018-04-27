#######################################################################################################################################
#
#
#
#    Script: Get-SQLVersion function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         Returns the running configuration of a SQL Instance.
#    Usage: 
#           - Source the function and pass the instance name as a parameter.
#           - This script also uses dbatools PowerShell module.
#
#    Examples:
#               . .\Get-SQLVersion.ps1
#
#               Get-SQLVersion -instanceName SERVER\Instance -SQLCredential (Get-Credential)
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

function Get-SQLVersion
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
            # If the connection to the SQL instance is successful, call the Get-SQLData function.       
            # Get-SqlData -instanceName $instance -Path $clSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
          
            $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
                
            $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
            
            # Add the SQL configuration to the global variable.
            #$sqlConfig = Get-DbaSpConfigure -SqlInstance $instance
            # $sqlVersionConfig += $config
            
            
        }
        elseif (!($testDBAConnectionDomain) -and $testDBAConnectionSQL)
        {
            # If the connection to the SQL instance is successful, call the Get-SQLData function.       
            # Get-SqlData -instanceName $instance -Path $clSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery -Credential $sqlCred
          
            $edition = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
            $edition.ConnectionContext.LoginSecure=$false
            $edition.ConnectionContext.set_Login($sqlCred.UserName)
            $edition.ConnectionContext.set_SecurePassword($sqlCred.Password)
                
            $config = $edition | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
              
            # Add the SQL configuration to the global variable.
            # $sqlConfig = Get-DbaSpConfigure -SqlInstance $instance -SQLCredential $sqlCred
            # $sqlVersionConfig += $config
            
           
        }        
        else
        {
            $errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
            $testConnectMsg = "<$errorDateTime> - No connection could be made to " + $instance + ". Authentication or network issue?"
            Write-host $testConnectMsg -foregroundcolor "magenta"
            # $testConnectMsg | Out-File -FilePath $failedConnections -Append
        }

        $config
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

  Write-Host "Getting SQL Version output..." -NoNewline -ForegroundColor Green

  Do
  {
    Write-Host "." -NoNewline -ForegroundColor Green
    Start-Sleep -Milliseconds 200
  } while ($sqlConfigJobs.Result.IsCompleted -contains $false)

  $sqlConfig = @()

  ForEach ($sqlConfigJob in $sqlConfigJobs) 
  {     
    $sqlConfig += $sqlConfigJob.Pipe.EndInvoke($sqlConfigJob.Result)
  }

  Write-Host "All jobs completed!" -ForegroundColor Green

  $sqlConfigRunspacePool.Close()
  $sqlConfigRunspacePool.Dispose()

  return $sqlConfig  
  
}