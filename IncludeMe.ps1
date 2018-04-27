#######################################################################################################################################
#
#
#
#    Script: SQL Server Reporting Script Include file
#    Author: Andy DeAngelis
#    Descrfiption: 
#         When adding new functions or modules for the main PS_SQL_DB_Info script to use, source/import them here.
#
#
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

# Import the dbatools module, which can be downloaded from dbatools.io.

Import-Module -Name "$PSScriptRoot\Modules\dbatools\dbatools.psm1" -Scope Local -PassThru

# Import the ImportExcel module, which can be downloaded from https://github.com/dfinke/ImportExcel.

Import-Module -Name "$PSScriptRoot\Modules\ImportExcel\ImportExcel.psm1" -Scope Local -PassThru

# Source the Get-SQLInstances02 function. The included Get-SQLInstance cmdlet is lacking, and it requires the SQL Cloud adapter to run.
# The SQL Cloud Adapter is primarily for Azure instances, and does not exist in the feature pack for SQL 2016.
 
. "$PSScriptRoot\Functions\Get-SQLInstances02.ps1"
. "$PSScriptRoot\Functions\Get-ClusteredSQLInstances.ps1"

# Source the SQL Specific functions.

. "$PSScriptRoot\Functions\Get-SQLData.ps1"
. "$PSScriptRoot\Functions\Get-SQLConfig.ps1"
. "$PSScriptRoot\Functions\Test-SQLBP.ps1"
. "$PSScriptRoot\Functions\Get-SQLVersion.ps1"
. "$PSScriptRoot\Functions\Get-SQLAGConfig.ps1"

# Source the Get-ServerConfig function

. "$PSScriptRoot\Functions\Get-ServerConfig.ps1"
. "$PSScriptRoot\Functions\Get-IsAlive.ps1"

# Include the MS Clustering functions.

. "$PSScriptRoot\Functions\Get-IsClustered.ps1"
. "$PSScriptRoot\Functions\Get-ClusterNodes.ps1"
. "$PSScriptRoot\Functions\Get-ClusterConfig.ps1"