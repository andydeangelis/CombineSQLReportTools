# Function to determine of a node is part of a cluster by querying WMI.
# While it's true that using the FailOver cluster PS module would be leaps and bounds easier, you may end up running this from a server that does not have it.
# As such, we will be using WMI to grab initial cluster data.

function Get-IsClustered 
{ 
  Param(
    [parameter(Mandatory=$true,ValueFromPipeline=$True)]
    [string[]]$ComputerName
  )
  
    if ((Get-WMIObject -Namespace root\mscluster -ComputerName $ComputerName -Class MSCluster_cluster -ErrorAction SilentlyContinue) -ne $null) 
    {      
        return $true 
    } 
    else 
    { 
        return $false
    }
} 