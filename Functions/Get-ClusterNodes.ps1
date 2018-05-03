# While it's true that using the FailOver cluster PS module would be leaps and bounds easier, you may end up running this from a server that does not have it.
# As such, we will be using WMI to grab initial cluster data.

function Get-ClusterNodes
{
    # This is the -ClusterNames parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$True)] $ClusterNames,
        [parameter(Mandatory=$true,ValueFromPipeline=$True)] $Path
    )

    # Need to add error handling here (try/catch).

    foreach ($cluster in $ClusterNames)
    {
        $clServerConfigResult = @()
        # $clServerDiskCOnfig = @()
        # $clServerOS = @()

        # Get the nodes in the cluster via WMI.
        $clNodes = Get-WmiObject -Namespace root\mscluster -ComputerName $cluster.Name -Class mscluster_node | Select-Object Name
        
        # For each returned node from the WMI query.

        foreach ($node in $clNodes)
        {
            if ((Test-NetConnection -ComputerName $computer -Port 3389 -InformationLevel Quiet -WarningAction SilentlyContinue) -eq $true)
            {
                $clServerConfigResult += Get-DbaComputerSystem -ComputerName $node.Name
                #$clServerDiskConfig += Get-DbaDiskSpace -ComputerName $server
                #$clServerOS += Get-DbaOperatingSystem -ComputerName $server | select ComputerName,Manufacturer,Organization,Architecture,Version,Build,InstallDate,LastBootTime,LocalDateTime,
                #                                                             PowerShellVersion,TimeZone,TotalVisibleMemory,FreePhysicalMemory,TotalVirtualMemory,FreeVirtualMemory,Language
            }
            else
            {
                Write-Host $node.Name + " is offline."
            }
        }

        # Set the Worksheet name. We will use one worksheet per cluster.

        $clServerConfigWorksheet = $cluster.Name

        # Set the table name for the Worksheet.

        $clServerConfigTableName = $cluster.Name

        $clServerConfigResult | Export-Excel -Path $Path -AutoSize -WorksheetName $clServerConfigWorksheet -FreezeTopRow -TableName $clServerConfigTableName
    }
       
}

