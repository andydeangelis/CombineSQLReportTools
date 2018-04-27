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
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $Path,
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $SQLQueryFile,
      [parameter(Mandatory=$false,ValueFromPipeline=$True)] $Credential
  )

  # Create variable that we will populate with the resultant set of data from the SQL queries.
  
  write-host "Instance name is $instanceName" -ForegroundColor Green

    try
    {
        $testDBAConnectionDomain = Test-DbaConnection -sqlinstance $InstanceName 
    }
    catch
    {
        "No connection could be made using Domain credentials."
    }
              
    if (!$testDBAConnectionDomain)
    {     
        try
        {
            $testDBAConnectionSQL = Test-DbaConnection -sqlinstance $InstanceName -SQLCredential $sqlCred
        }
        catch
        {
            "No connection could be made using SQL credentials."
        }
    }
  
  if (($testDBAConnectionDomain -and $testDBAConnectionSQL) -or ($testDBAConnectionDomain -and !($testDBAConnectionSQL)))
  {
    $SQLDataresult = invoke-sqlcmd2 -InputFile $SQLQueryFile -serverinstance $InstanceName -database master 
  }
  elseif (!($testDBAConnectionDomain) -and $testDBAConnectionSQL)
  {
    $SQLDataresult = invoke-sqlcmd2 -InputFile $SQLQueryFile -serverinstance $InstanceName -database master -credential $Credential
  }
  else
  {
    $errorDateTime = get-date -f MM-dd-yyyy_hh.mm.ss
    $testConnectMsg = "<$errorDateTime> - No connection could be made to " + $instance + ". Authentication or network issue?"
    Write-host $testConnectMsg -foregroundcolor "magenta"
    # $testConnectMsg | Out-File -FilePath $failedConnections -Append
  }
  
  #The following DbaTools function is erroring out. Will use the aboce T-SQL script for now until I figure out the issue.
  # $SQLDataresult = Get-DbaDatabase -SqlInstance $instanceName
  
  
  # Set the worksheet name. We will have a single Excel file with one tab per Instance. Worksheet names will be labeled as SERVERNAME-INSTANCENAME.
  
  $SQLDataWorksheetName = $InstanceName -replace "\\","-"
  
  # Set the table names for the worksheet.
  
  $SQLDataTableName = "T" + "$SQLDataWorksheetName"
  
  # Possibly change to Send-SQLDatatoExcel function in the ImportExcel module.

  if ($SQLDataResult -ne $null)
  {
    write-host "$SQLDataTableName" -ForegroundColor Cyan
    $excel = $SQLDataResult | Export-Excel -Path $Path -AutoSize -WorksheetName $SQLDataWorksheetName -FreezeTopRow -TableStyle 'Medium6' -TableName $SQLDataTableName -PassThru
    $excel.Save() ; $excel.Dispose()
  }
  else
  {
    Write-Host "No SQL Data to export." -ForegroundColor Red
  }
  
}