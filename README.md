# CombineSQLReportTools

#######################################################################################################################################
#
#
#
#    Script: SQL Server Reporting Script
#    Author: Andy DeAngelis
#    Descrfiption: 
#         The purpose of this toolset is to help gather information about SQL Server instances deployed in an environment. It calls various 
#         custom functions to gather server information, clustering information and SQL information. Once gathered, the script then creates
#         reports in Excel format that can be shared with customers, end users, other IT staff, etc.
#    Usage: 
#           - Servers should be listed in the myservers.txt file located in the same directory as the script, one server name per line.
#           - The script should be initiated using the RUN_ME.bat batch file or by using the .\Launcher.ps1 file. This ensures that the
#             ExecutionPolicy scope is properly set, and the proper credentials are passed.
#           - The credential passed in the Get-Credential call needs to be a local administrator on the target servers to gather WMI data.
#           - The credential passed in the Get-Credential call needs to be a SysAdmin in each SQL instance to gather SQL data.
#           - This script also uses dbatools and ImportExcel PowerShell modules
#    Examples:
#               RUNME.BAT
#
#````Note: Powershellv3 or higher is needed.
#
#	Included modules:
#				
#				- dbatools from http://dbatools.io
#				- ImportExcel from https://github.com/dfinke/ImportExcel
#
#	Custom Functions
#			
#			- Located in the .\Functions\ directory, each function can be used independently of the main script, so feel free to use in your code.
#
#	Function List
#
#		Get-ClusterConfig
#					
#			While it's true that using the FailOver cluster PS module would be leaps and bounds easier, you may end up running this from a 
#	        server or workstation that does not have that module installed. The purpose of this script is to help gather information about the various clusters 
#	        and build an Excel report that outputs the configuration. This function can be used independently. Requires ImportExcel module top be loaded.
#
#		Get-ClusteredSQLInstances
#
#			Iterates through an array of cluster names and returns the SQL instances deployed to the cluster. Note, this is for failover clusters only.
#
#		Get-ClusterNodes
#
#			Iterates through an array of cluster names and returns each of the nodes configured as members of the cluster.
#
#		Get-ClusterResource
#
#			Returns the cluster resources and their associations. Uses a cluster name as the parameter.
#
#		Get-IsClustered
#
#			Function to determine of a node is part of a cluster by querying WMI.
#
#		Get-ServerConfig
#
#			Iterates through a list of servers to return configuration data out to a spreadsheet report. Requires ImportExcedlModule and dbatools. Data returned is:
#
#				- Server host names and FQDN
#				- Manufacturer
#				- Disk information, including capacity, free space and block size
#				- Service pack major and minor versions
#				- Cluster membership (if clustered)
#
#		Get-SQLConfig
#
#			Returns the running configuration of a SQL instance. Requires dbatools module.
#
#		Get-SQLData
#		
#			Returns all relevant SQL data by invoking the specified SQLQueryFile paramter and the exports the returned data to a spreadsheet. Requires ImportExcel module.
#
#		Get-SQLInstances02
#
#		  This is a replacement for the Get-SQLInstances function within the SQLPS module. The included Get-SQLInstances function is
#         primarily for Azure SQL instances and requires the SQL Cloud Adapter, which doesn't really work. The idea is to pass a host
#         name and return the names of all SQL instances on the host name. It's not elegant, but it works.
#######################################################################################################################################
