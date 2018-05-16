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
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$SQLCredential,
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$domainCredential
  )
	
	$parent = Split-Path -Path $PSScriptRoot -Parent
	
	Write-Host "Getting SQL Version output..." -NoNewline -ForegroundColor Green

  $SQLConfigScript = {
		
		Param ($instance,
			$parent,
			$sqlCred)
		
		Import-module "$parent\Modules\dbatools\dbatools.psm1"
		
		# First, let's create a SQL Management Object to test connectivity.
		
		$sqlObj = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
		
		# First, test connectivity to the specified SQL instance using the logged on user credentials
		
		try
		{
			# $testDBAConnectionSession = Test-DbaConnection -sqlinstance $instance
			$testDBAConnectionSession = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
			Write-Host "Successfully connected to $instance using logged on session." -ForegroundColor Green
			
		}
		catch
		{
			Write-Host "No connection could be made to $instance using local session credentials. Attempting to use SQL credentals." -ForegroundColor Yellow
		}
		
		# If the logged on user credentials fail, test using SQL creds.
		
		if (-not $testDBAConnectionSession)
		{
			try
			{
				$sqlObj.ConnectionContext.LoginSecure = $false
				$sqlObj.ConnectionContext.set_Login($sqlCred.UserName)
				$sqlObj.ConnectionContext.set_SecurePassword($sqlCred.Password)
				$testDBAConnectionSQL = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
				Write-Host "Successfully connected to $instance using SQL credentials." -ForegroundColor Green
			}
			catch
			{
				Write-Host "No connection could be made to $instance using SQL or session credentials." -ForegroundColor Red
			}
		}
		
		if (($testDBAConnectionSession -and $testDBAConnectionSQL) -or ($testDBAConnectionSession -and !($testDBAConnectionSQL)))
        {
            # If the connection to the SQL instance is successful, call the Get-SQLData function.       
            # Get-SqlData -instanceName $instance -Path $clSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery
          
            $config = $sqlObj | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
            
            # Add the SQL configuration to the global variable.
            #$sqlConfig = Get-DbaSpConfigure -SqlInstance $instance
            # $sqlVersionConfig += $config
            
            
        }
        elseif (!($testDBAConnectionSession) -and $testDBAConnectionSQL)
        {
            # If the connection to the SQL instance is successful, call the Get-SQLData function.       
            # Get-SqlData -instanceName $instance -Path $clSQLDataxlsxReportPath -SQLQueryFile $SQLStatsQuery -Credential $sqlCred
          
            $sqlObj.ConnectionContext.LoginSecure=$false
            $sqlObj.ConnectionContext.set_Login($sqlCred.UserName)
            $sqlObj.ConnectionContext.set_SecurePassword($sqlCred.Password)
                
            $config = $sqlObj | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog,  MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
              
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
		
		Clear-Variable sqlObj
		
		$config
	} # End script block
	
	$SQLConfigScriptDomain = {
		
		Param ($instance,
			$parent,
			$sqlCred,
			$domainCred)
		
		Import-module "$parent\Modules\dbatools\dbatools.psm1"
		
		# First, let's create a SQL Management Object to test connectivity.
		
		$sqlObj = new-object ('Microsoft.SqlServer.Management.Smo.Server') $instance
		
		# First, test connectivity to the specified SQL instance using the logged on user credentials
		
		try
		{
			# $testDBAConnectionSession = Test-DbaConnection -sqlinstance $instance
			$testDBAConnectionSession = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
			Write-Host "Successfully connected to $instance using logged on session." -ForegroundColor Green
			
		}
		catch
		{
			Write-Host "No connection could be made to $instance using local session credentials. Attempting to use SQL credentals." -ForegroundColor Yellow
		}
		
		if (-not $testDBAConnectionSession)
		{
			# If the logged on user credentials fail, test using SQL creds.
			
			try
			{
				$sqlObj.ConnectionContext.LoginSecure = $false
				$sqlObj.ConnectionContext.set_Login($sqlCred.UserName)
				$sqlObj.ConnectionContext.set_SecurePassword($sqlCred.Password)
				$testDBAConnectionSQL = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
				Write-Host "Successfully connected to $instance using SQL credentials." -ForegroundColor Green
			}
			catch
			{
				Write-Host "No connection could be made to $instance using SQL credentials. Attempting to use provided Domain credentals." -ForegroundColor Yellow
			}
		}
		
		if ((-not $testDBAConnectionSession) -and (-not $testDBAConnectionSQL))
		{
			# Also, we're going to test domain credentials, if they were specified.
			
			try
			{
				# We need to transform the passed in domain credentials, as the SMO objects only accept usernames as USER@DOMAIN format.
				$user = $domainCred.UserName.Split("\")
				$username = "$($user[1])@$($user[0])"
				
				$sqlObj.ConnectionContext.LoginSecure = $true
				$sqlObj.ConnectionContext.ConnectAsUser = $true
				$sqlObj.ConnectionContext.ConnectAsUserName = $username
				$sqlObj.ConnectionContext.ConnectAsUserPassword = $domainCred.GetNetworkCredential().Password
				
				$testDBAConnectionDomain = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
				Write-Host "Successfully connected to $instance using provided Domain credentials." -ForegroundColor Green
			}
			catch
			{
				Write-Host "No connection could be made to $instance using provided Domain credentials. Please verify your credentials." -ForegroundColor Red
			}
		}
		
		if ($testDBAConnectionSession)
		{
			$config = $sqlObj | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog, MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
		}
		elseif ($testDBAConnectionSQL -and (-not $testDBAConnectionDomain))
		{
			$config = $sqlObj | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog, MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
		}
		elseif ((-not $testDBAConnectionSQL) -and $testDBAConnectionDomain)
		{
			$config = $sqlObj | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog, MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
		}
		elseif ($testDBAConnectionSQL -and $testDBAConnectionDomain)
		{
			$config = $sqlObj | select Name, Edition, BuildNumber, Product, ProductLevel, Version, IsClustered, Processors, PhysicalMemory, DefaultFile, DefaultLog, MasterDBPath, MasterDBLogPath, BackupDirectory, ServiceAccount, InstanceName
		}
		else
		{
			$errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
			$testConnectMsg = "<$errorDateTime> - No connection could be made to " + $instance + ". Authentication or network issue?"
			Write-host $testConnectMsg -foregroundcolor "magenta"
			# $testConnectMsg | Out-File -FilePath $failedConnections -Append
		}
		
		Clear-Variable sqlObj
		
		$config
	} # End script block

  
  $Throttle = 8
  $sqlConfigInitialSessionState =[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $sqlConfigRunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$Throttle,$sqlConfigInitialSessionState,$Host)
  $sqlConfigRunspacePool.Open()
  $sqlConfigJobs = @()

  foreach ($instance in $instanceNames)
	{
		if (-not $domainCredential)
		{
			$sqlConfigJob = [powershell]::Create().AddScript($SQLConfigScript).AddArgument($instance).AddArgument($parent).AddArgument($SQLCredential)
			$sqlConfigJob.RunspacePool = $sqlConfigRunspacePool
			$sqlConfigJobs += New-Object PSObject -Property @{
				Pipe    = $sqlConfigJob
				Result  = $sqlConfigJob.BeginInvoke()
			}
		}
		else
		{
			$sqlConfigJob = [powershell]::Create().AddScript($SQLConfigScriptDomain).AddArgument($instance).AddArgument($parent).AddArgument($SQLCredential).AddArgument($domainCredential)
			$sqlConfigJob.RunspacePool = $sqlConfigRunspacePool
			$sqlConfigJobs += New-Object PSObject -Property @{
				Pipe	 = $sqlConfigJob
				Result   = $sqlConfigJob.BeginInvoke()
			}
		}
	}

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