function Get-ClusteredSQLInstances
{
    # This is the -Computername parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$True)] $ClusterNames
    )
    
    foreach ($cluster in $ClusterNames)
    {
      # Get the private properties for the SQL Server cluster resource type.
      # Write-Host $cluster -ForegroundColor Yellow
      $sqlSvrResource = (Get-WmiObject -Namespace root\mscluster -Class MSCluster_Resource -ComputerName $cluster | Where-Object {$_.Type -eq 'SQL Server'} | select -Expand PrivateProperties)
      
      If ($sqlSvrResource -ne $null)
      {
        foreach ($instance in $sqlSvrResource)
        {
          $clInstanceName = $instance.VirtualServerName + "\" + $instance.InstanceName
          # Write-Host "Cluster " $cluster.Name " has the following SQL instances." -ForegroundColor Green
          # $clInstanceName     
          $clInstanceNameList += @("$clInstanceName")
        }
        return $clInstanceNameList
      }
      else
      {
        Write-Host "$cluster is clustered but has no clustered SQL services. Is this an Availability Group?" -ForegroundColor DarkYellow
        return $false
      }
      
      
    }
    
}