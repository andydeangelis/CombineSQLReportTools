#######################################################################################################################################
#
#
#
#    Script: Get-SQLConfig function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         Returns the running configuration of a SQL Instance.
#    Usage: 
#           - Source the function and pass the instance name as a  parameter.
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
      [parameter(Mandatory=$true,ValueFromPipeline=$True)]
      [string[]]$instanceName
  )

  # 
  Get-DbaSpConfigure -SqlInstance $instancename
  
  
}