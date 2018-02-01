#######################################################################################################################################
#
#
#
#    Script: Get-ClusterConfig function
#    Author: Andy DeAngelis
#    Descrfiption: 
#         While it's true that using the FailOver cluster PS module would be leaps and bounds easier, you may end up running this from a 
#         server that does not have that module installed. The purpose of this script is to help gather information about the various clusters 
#         and build an Excel report that outputs the configuration. This function can be used independently.
#    Usage: 
#           - The ClusterNames parameter is an array.
#           - The Path parameter is the path and filename for the output xlsx file.
#           - This script also uses the ImportExcel PowerShell module.
#    Examples:
#               . .\Get-ClusterConfig.ps1
#
#               Get-ClusterConfig -ClusterNames $clusterArray -Path <PATH_TO_EXCEL_OUTPUT>
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

# While it's true that using the FailOver cluster PS module would be leaps and bounds easier, you may end up running this from a server that does not have it.
# As such, we will be using WMI to grab initial cluster data.

function Get-ClusterConfig
{
    # This is the -ClusterNames parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$True)] $ClusterNames,
        [parameter(Mandatory=$true,ValueFromPipeline=$True)] $Path
    )

    # Instantiate an array to hold the core cluster configurations.
    
    $clCoreConfig = @()
    
    # Instantiate an array to hold the resource config.
    
    $clResourceConfig = @()

    foreach ($cluster in $ClusterNames)
    {
        # Let's get some cluster data from WMI. The first variable pulls the running cluster config.
        
        $clData = Get-WmiObject -Namespace root\mscluster -ComputerName $cluster.Name -Class mscluster_cluster
        
        # This next variable will hold the core cluster DNS name.
        $clCoreDNS = Get-WmiObject -Namespace root\mscluster -ComputerName $cluster.Name -Class mscluster_resource | 
                    where-object {($_.OwnerGroup -eq "Cluster Group") -and ($_.Type -eq "Network Name")} | 
                    Select Type, OwnerGroup, CoreResource -ExpandProperty PrivateProperties
                    
        # This next variable will hold the core cluster DNS name.
        $clCoreIP = Get-WmiObject -Namespace root\mscluster -ComputerName $cluster.Name -Class mscluster_resource | 
                    where-object {($_.OwnerGroup -eq "Cluster Group") -and ($_.Type -eq "IP Address")} | 
                    Select Type, OwnerGroup, CoreResource -ExpandProperty PrivateProperties
        
        # Create a new PSObject so we can add all the data for each cluster.  
        $clObject = New-Object System.Object
        
        $clObject | Add-Member -Type NoteProperty -Name Name -Value $clData.Name
        $clObject | Add-Member -Type NoteProperty -Name FQDN -Value $clData.FQDN
        $clObject | Add-Member -Type NoteProperty -Name "DNS Name" $clCoreDNS.DNSName
        $clObject | Add-Member -Type NoteProperty -Name "DNS Suffix" $clCoreDNS.DNSSuffix
        $clObject | Add-Member -Type NoteProperty -Name "IP Address" $clCoreIP.Address
        $clObject | Add-Member -Type NoteProperty -Name "Subnet Mask" $clCoreIP.SubnetMask
        $clObject | Add-Member -Type NoteProperty -Name "Enable DHCP" $clCoreIP.EnableDHCP
        $clObject | Add-Member -Type NoteProperty -Name "Network" $clCoreIP.Network
        $clObject | Add-Member -Type NoteProperty -Name ClusterLogLevel -Value $clData.ClusterLogLevel
        $clObject | Add-Member -Type NoteProperty -Name SharedVolumesRoot -Value $clData.SharedVolumesRoot
        $clObject | Add-Member -Type NoteProperty -Name QuorumType -Value $clData.QuorumType
        $clObject | Add-Member -Type NoteProperty -Name QuorumPath -Value $clData.QuorumPath
        $clObject | Add-Member -Type NoteProperty -Name SameSubnetDelay -Value $clData.SameSubnetDelay
        $clObject | Add-Member -Type NoteProperty -Name SameSubnetThreshold -Value $clData.SameSubnetThreshold
        $clObject | Add-Member -Type NoteProperty -Name CrossSubnetDelay -Value $clData.CrossSubnetDelay
        $clObject | Add-Member -Type NoteProperty -Name CrossSubnetThreshold -Value $clData.CrossSubnetThreshold
        
        # Add the object to the data array.
        $clCoreConfig += $clObject
        
        # Now, for the cluster, we're going to get the Resource Group names.
        
        # $clResourceGroup = Get-WmiObject -Namespace root\mscluster -ComputerName $cluster.name -class mscluster_resourcegroup | select Name
        
        # Now we need to return the resources associated with each resource group.
        
        $clResources = Get-WmiObject -Namespace root\mscluster -ComputerName $cluster.Name -Class mscluster_resource | Where-Object {$_.OwnerGroup -ne "Cluster Group"} |
                        Select-Object OwnerGroup,OwnerNode,CoreResource,Type,IsClusterSharedVolume              
                        
        # Set the worksheet name for the server's config.
        $clResourceWorksheet = $cluster.Name + " Resources"
        
        # Set the table name for the worksheet.
        $clResourceTable = "Table" + $cluster.Name
        
        # Export the resources to a new tab in the Excel spreadsheet.
        
        if ($clResources -ne $null)
        {
            $excel = $clResources | Export-Excel -Path $Path -AutoSize -WorksheetName $clResourceWorksheet -FreezeTopRow -TableName $clResourceTable -PassThru        
            $excel.Save() ; $excel.Dispose()
        }
        else
        {
            Write-Host "No cluster data found."
        }
        
    }

    # Set the worksheet name. We will have a single tab that will hold each cluster's config for easy reference..
  
    $clConfigWorksheet = "Cluster Configs"

    # Set the table names for the worksheet.
  
    $clConfigTableName = "ClusterConfigs"

    if ($clCoreConfig -ne $null)
    {
        $excel = $clCoreConfig | Export-Excel -Path $Path -AutoSize -WorksheetName $clConfigWorksheet -FreezeTopRow -TableName $clConfigTableName -PassThru        
        $excel.Save() ; $excel.Dispose()
    }
    else
    {
        Write-Host "No cluster data found."
    }
    
}