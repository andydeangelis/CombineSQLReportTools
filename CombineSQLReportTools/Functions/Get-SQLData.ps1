#######################################################################################################################################
#
#
#
#    Script: Get-SQLData function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         Returns all relevant SQL data by invoking the specfied SQLQueryFile paramter and the exports the returned data to a spreadsheet.
#    Usage: 
#           - Source the function and pass the required parameters.
#           - Also requires a custom made or the included .sql file.
#           - This script also uses the ImportExcel PowerShell module.
#
#    Examples:
#               . .\Get-SQLData.ps1
#
#               Get-SQLData -instanceName SERVER\Instance -Path <PATH_TO_EXCEL_OUTPUT> -SQLQueryFile <SQL_File_to_RUN>
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

function Get-SQLData
{

  # This is the -instance.Name parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
  Param(
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $InstanceName,
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $ReportExportFileName,
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $SQLQueryFile,
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$SQLCredential,
		[parameter(Mandatory = $false, ValueFromPipeline = $True)]
		$domainCredential
  )

  # Create variable that we will populate with the resultant set of data from the SQL queries.
	
	write-host "Instance name is $instanceName" -ForegroundColor Green
	
	# $sqlObj = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
	
	if ($SQLCredential -and (-not $domainCredential))
	{
		# If the SQLCredential parameter is specified but not the domainCredential parameter.
		
		try
		{
			$sqlObj = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
			$sqlObj.ConnectionContext.LoginSecure = $false
			$sqlObj.ConnectionContext.set_Login($SQLCredential.UserName)
			$sqlObj.ConnectionContext.set_SecurePassword($SQLCredential.Password)
			
			$testDBAConnectionSQL = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
			Write-Host "Successfully connected to $InstanceName using SQL credentials." -ForegroundColor Green
		}
		catch
		{
			Write-Host "No connection could be made to $InstanceName using SQL credentials. Attempting to use provided Domain credentals." -ForegroundColor Yellow
		}
	}
	elseif ($domainCredential -and (-not $SQLCredential))
	{
		# If the domainCredential parameter is specified but not the SQLCredential parameter.
		
		try
		{
			$sqlObj = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
			# We need to transform the passed in domain credentials, as the SMO objects only accept usernames as USER@DOMAIN format.
			$user = $domainCredential.UserName.Split("\")
			$username = "$($user[1])@$($user[0])"
			
			$sqlObj.ConnectionContext.LoginSecure = $true
			$sqlObj.ConnectionContext.ConnectAsUser = $true
			$sqlObj.ConnectionContext.ConnectAsUserName = $username
			$sqlObj.ConnectionContext.ConnectAsUserPassword = $domainCredential.GetNetworkCredential().Password
			
			$testDBAConnectionDomain = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
			Write-Host "Successfully connected to $InstanceName using provided Domain credentials." -ForegroundColor Green
		}
		catch
		{
			Write-Host "No connection could be made to $InstanceName using provided Domain credentials. Please verify your credentials." -ForegroundColor Red
		}
	}
	elseif ((-not $SQLCredential) -and (-not $domainCredential))
	{
		# If neither the SQLCredential parameter nor the domainCredential parameter are specified, attempt to use the running session credentials.
			
		try
		{
			$sqlObj = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
			# $testDBAConnectionSession = Test-DbaConnection -sqlinstance $instance
			$testDBAConnectionSession = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
			Write-Host "Successfully connected to $InstanceName using logged on session." -ForegroundColor Green
		}
		catch
		{
			Write-Host "No connection could be made to $InstanceName using local session credentials. Attempting to use SQL credentals." -ForegroundColor Yellow
		}
	}
	elseif ($SQLCredential -and $domainCredential)
	{
		# If both SQLCredential and domainCredential parameters are set, test both connection types.
		
		$sqlObj = new-object ('Microsoft.SqlServer.Management.Smo.Server') $InstanceName
		
		try
		{
			$sqlObj.ConnectionContext.LoginSecure = $false
			$sqlObj.ConnectionContext.set_Login($SQLCredential.UserName)
			$sqlObj.ConnectionContext.set_SecurePassword($SQLCredential.Password)
			
			$testDBAConnectionSQL = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
			Write-Host "Successfully connected to $InstanceName using SQL credentials." -ForegroundColor Green
		}
		catch
		{
			Write-Host "No connection could be made to $InstanceName using SQL credentials. Attempting to use provided Domain credentals." -ForegroundColor Yellow
		}
		
		try
		{
			# We need to transform the passed in domain credentials, as the SMO objects only accept usernames as USER@DOMAIN format.
			$user = $domainCredential.UserName.Split("\")
			$username = "$($user[1])@$($user[0])"
			
			$sqlObj.ConnectionContext.LoginSecure = $true
			$sqlObj.ConnectionContext.ConnectAsUser = $true
			$sqlObj.ConnectionContext.ConnectAsUserName = $username
			$sqlObj.ConnectionContext.ConnectAsUserPassword = $domainCredential.GetNetworkCredential().Password
			
			$testDBAConnectionDomain = $sqlObj.ConnectionContext.ExecuteWithResults("select @@version")
			Write-Host "Successfully connected to $InstanceName using provided Domain credentials." -ForegroundColor Green
		}
		catch
		{
			Write-Host "No connection could be made to $InstanceName using provided Domain credentials. Please verify your credentials." -ForegroundColor Red
		}
	}	
	else
	{
		Write-Host "No connection could be made using any of the supplied credentials." -ForegroundColor Red
	}
		
		
	if ($testDBAConnectionSession -or $testDBAConnectionSQL -or $testDBAConnectionDomain)
	{
		$script = Get-Content $SQLQueryFile -Raw
		$SQLDataresult = $sqlObj.ConnectionContext.ExecutewithResults($script) | select -ExpandProperty Tables
	}
	else
	{
		$errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
		$testConnectMsg = "<$errorDateTime> - No connection could be made to $InstanceName. Authentication or network issue?"
		Write-host $testConnectMsg -foregroundcolor "magenta"
		# $testConnectMsg | Out-File -FilePath $failedConnections -Append
	}
	
	Clear-Variable sqlObj
	
  # Set the worksheet name. We will have a single Excel file with one tab per Instance. Worksheet names will be labeled as SERVERNAME-INSTANCENAME.
  
  $SQLDataWorksheetName = $InstanceName -replace "\\","-"
  
  # Set the table names for the worksheet.
  
  $SQLDataTableName = "T" + "$SQLDataWorksheetName"
  
  # Possibly change to Send-SQLDatatoExcel function in the ImportExcel module.

  if ($SQLDataResult -ne $null)
  {
    write-host "$SQLDataTableName" -ForegroundColor Cyan
    $excel = $SQLDataResult | Export-Excel -Path $ReportExportFileName -AutoSize -WorksheetName $SQLDataWorksheetName -FreezeTopRow -TableStyle 'Medium6' -TableName $SQLDataTableName -PassThru
    $excel.Save() ; $excel.Dispose()
  }
  else
  {
    Write-Host "No SQL Data to export." -ForegroundColor Red
	}
	
	if (Get-Variable testDBAConnectionSession -ErrorAction SilentlyContinue) { Clear-Variable testDBAConnectionSession }
	if (Get-Variable testDBAConnectionSQL -ErrorAction SilentlyContinue) { Clear-Variable testDBAConnectionSQL }
	if (Get-Variable testDBAConnectionDomain -ErrorAction SilentlyContinue) { Clear-Variable testDBAConnectionDomain }
	
}