#######################################################################################################################################
#
#
#
#    Script: Test-SQLBP function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         Tests for SQL Best Practices.
#    Usage: 
#           - Source the function and pass the required parameters.
#           - Also requires a custom made or the included .sql file.
#           - This script also uses the ImportExcel PowerShell module.
#
#    Examples:
#               . .\Test-SQLBP.ps1 -InstanceName <INSTANCE> -ComputerName <SERVER> | ForEach-Object ($_. | ft *)
#
#               
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

function Test-SQLBP
{

  # This is the -instance.Name parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
  Param(
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $instanceName,
      [parameter(Mandatory=$true,ValueFromPipeline=$True)] $ComputerName,
      [parameter(Mandatory=$false,ValueFromPipeline=$True)] $Credential,
      [parameter(Mandatory=$false,ValueFromPipeline=$True)] $IsClustered
  )

  # Create variable that we will populate with the resultant set of data from the SQL queries.
  
  write-host "Instance name is $instanceName" -ForegroundColor Green
  
  if ($Credential -ne $null)
  {
    Write-Host "Testing with SQL credentials." -ForegroundColor Red
    Write-host $Credential.UserName
    $maxMemory = Test-DbaMaxMemory -SQLInstance $instanceName -SQLCredential $Credential
    $tempDBConfig = Test-DBATempDbConfiguration -SQLInstance $instanceName -SQLCredential $Credential
    if ($IsClustered -eq $true)
    {
      Write-Host "Instance is clustered. Using Host Name $ComputerName" -ForegroundColor Yellow
    }
    else
    {
      Write-Host "Using Host Name $ComputerName" -ForegroundColor Green
      $dbDiskAllocation = Test-DBADiskAllocation -ComputerName $ComputerName -SQLCredential $Credential 
      $powerPlan = Test-DbaPowerPlan -ComputerName $ComputerName      
    }
    return $maxMemory,$tempDBConfig,$dbDiskAllocation,$powerPlan  
  }
  else
  {
    $maxMemory = Test-DbaMaxMemory -SQLInstance $instanceName
    $tempDBConfig = Test-DBATempDbConfiguration -SQLInstance $instanceName
    if ($IsClustered -eq $true)
    {
      Write-Host "Instance is clustered. Using Host Name $ComputerName" -ForegroundColor Yellow
    }
    else
    {
      Write-Host "Using Host Name $ComputerName" -ForegroundColor Green
      $dbDiskAllocation = Test-DBADiskAllocation -ComputerName $ComputerName
      $powerPlan = Test-DbaPowerPlan -ComputerName $ComputerName
    }
    
    return $maxMemory,$tempDBConfig,$dbDiskAllocation,$powerPlan
  }
  
  
}