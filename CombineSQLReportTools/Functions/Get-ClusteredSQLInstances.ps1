function Get-ClusteredSQLInstances
{
    # This is the -Computername parameter passed from the PS_SQL_DB_Info.ps1 script, hence the 'ValueFromPipeline' definition.
    # The parameter can be a single name or list of names.

    Param(
		[parameter(Mandatory = $true, ValueFromPipeline = $True)]
		$ClusterNames,
		[parameter(Mandatory = $false, ValueFromPipeline = $true)]
		$domainCredential
    )

    . "$PSScriptRoot\Get-SQLInstances02.ps1"
	
	$parent = Split-Path -Path $PSScriptRoot -Parent
	
	# Four script blocks are defined here.
	# If SQL Server cluster object types are found, the $getClSQLScript or $getClSQLScriptDomain script block is called.
	# Which block is called is determined by if the $domainCred parameter is passed.
	# If no clustered SQL objects are found, assume this is an availability group and call either the $getAGSQLScript or $getAGSQLScriptDomain script blocks.
	# Which block is called is determined by if the $domainCred parameter is passed.

    $getClSQLScript = {

        Param ($cluster,$parent)

        # Get the private properties for the SQL Server cluster resource type.
        # Write-Host $cluster -ForegroundColor Yellow
        $sqlSvrResource = (Get-WmiObject -Namespace root\mscluster -Class MSCluster_Resource -ComputerName $cluster | Where-Object {$_.Type -eq 'SQL Server'} | select -Expand PrivateProperties)
      
        If ($sqlSvrResource -ne $null)
        {
            foreach ($instance in $sqlSvrResource)
            {
                $clInstanceNames += @($instance.VirtualServerName + "\" + $instance.InstanceName)
                # Write-Host "Cluster " $cluster.Name " has the following SQL instances." -ForegroundColor Green
                # $clInstanceName     
                # $clInstanceNameList += @("$clInstanceName")
            }
            $clInstanceNames
        }
    }

    $getAGSQLScript ={

        param ($cluster,$parent)

      # We know clustering is installed, but we have no 'SQL Server' type clustered resources.' We're going to check for instances of SQL now.
      # First thing, let's get the nodes of the cluster.
        
      $clNodes = get-wmiobject -Class MSCluster_node -Namespace root\mscluster -ComputerName $cluster | select Name
        
      foreach ($node in $clNodes)
      {
        # Now, let's check to see if SQL is on these nodes.
          
        $clInstanceNames += @(Get-SQLInstances02 -ComputerName $node.Name)        
      }
      $clInstanceNames
    }
	
	$getClSQLScriptDomain = {
		
		Param ($cluster,
			$parent,
			$domainCred)
		
		# Get the private properties for the SQL Server cluster resource type.
		# Write-Host $cluster -ForegroundColor Yellow
		$sqlSvrResource = (Get-WmiObject -Namespace root\mscluster -Class MSCluster_Resource -ComputerName $cluster -Credential $domainCred | Where-Object { $_.Type -eq 'SQL Server' } | select -Expand PrivateProperties)
		
		If ($sqlSvrResource -ne $null)
		{
			foreach ($instance in $sqlSvrResource)
			{
				$clInstanceNames += @($instance.VirtualServerName + "\" + $instance.InstanceName)
				# Write-Host "Cluster " $cluster.Name " has the following SQL instances." -ForegroundColor Green
				# $clInstanceName     
				# $clInstanceNameList += @("$clInstanceName")
			}
			$clInstanceNames
		}
	}
	
	$getAGSQLScriptDomain = {
		
		param ($cluster,
			$parent,
			$domainCred)
		
		# We know clustering is installed, but we have no 'SQL Server' type clustered resources.' We're going to check for instances of SQL now.
		# First thing, let's get the nodes of the cluster.
		
		$clNodes = get-wmiobject -Class MSCluster_node -Namespace root\mscluster -ComputerName $cluster -Credential $domainCred | select Name
		
		foreach ($node in $clNodes)
		{
			# Now, let's check to see if SQL is on these nodes.
			
			$clInstanceNames += @(Get-SQLInstances02 -ComputerName $node.Name -domainCredential $domainCred)
		}
		$clInstanceNames
	}
	
	$Throttle = 8
	$clSQLInitialSessionState =[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

	$definition = Get-Content Function:\Get-SQLInstances02 -ErrorAction Stop   
	$GetSQLInstancesSessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList 'Get-SQLInstances02', $definition
	$clSQLInitialSessionState.Commands.Add($GetSQLInstancesSessionStateFunction)

	$clSQLRunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$Throttle,$clSQLInitialSessionState,$Host)
	$clSQLRunspacePool.Open()
	$clSQLJobs = @()
	
	Write-Host "Getting clustered SQL configuration..." -NoNewline -ForegroundColor Green
	
	foreach ($cluster in $ClusterNames)
	{
		# First, test to see if clustered SQL Server object types are found.
		if ($domainCredential)
		{
			$testClusteredSQLInstance = (Get-WmiObject -Namespace root\mscluster -Class MSCluster_Resource -ComputerName $cluster -Credential $domainCredential | Where-Object { $_.Type -eq 'SQL Server' })
		}
		else
		{
			$testClusteredSQLInstance = (Get-WmiObject -Namespace root\mscluster -Class MSCluster_Resource -ComputerName $cluster | Where-Object { $_.Type -eq 'SQL Server' })
		}
		
		# If clustered SQL Server object types are found, run the getClSQLScript or getClSQLScriptDomain script block.
		
		if ($testClusteredSQLInstance -ne $null)
		{
			# Test of the $domainCred paramter is passed and call the appropriate script block.
			# If yes, pass the domain credential object to the script block to run WMI.
			# If no, call the script block and run as the executing user.
			
			if ($domainCredential)
			{
				$clSQLJob = [powershell]::Create().AddScript($getClSQLScriptDomain).AddArgument($cluster).AddArgument($parent).AddArgument($domainCredential)
				$clSQLJob.RunspacePool = $clSQLRunspacePool
				$clSQLJobs += New-Object PSObject -Property @{
					Pipe	  = $clSQLJob
					Result    = $clSQLJob.BeginInvoke()
				}
			}
			else
			{
				$clSQLJob = [powershell]::Create().AddScript($getClSQLScript).AddArgument($cluster).AddArgument($parent)
				$clSQLJob.RunspacePool = $clSQLRunspacePool
				$clSQLJobs += New-Object PSObject -Property @{
					Pipe	   = $clSQLJob
					Result	   = $clSQLJob.BeginInvoke()
				}
			}
		}
		elseif ($testClusteredSQLInstance -eq $null)
		{
			# Test of the $domainCred paramter is passed and call the appropriate script block.
			# If yes, pass the domain credential object to the script block to run WMI.
			# If no, call the script block and run as the executing user.		
			
			if ($domainCredential)
			{
				$clSQLJob = [powershell]::Create().AddScript($getAGSQLScriptDomain).AddArgument($cluster).AddArgument($parent).AddArgument($domainCredential)
				$clSQLJob.RunspacePool = $clSQLRunspacePool
				$clSQLJobs += New-Object PSObject -Property @{
					Pipe	   = $clSQLJob
					Result	   = $clSQLJob.BeginInvoke()
				}
			}
			else
			{
				$clSQLJob = [powershell]::Create().AddScript($getAGSQLScript).AddArgument($cluster).AddArgument($parent)
				$clSQLJob.RunspacePool = $clSQLRunspacePool
				$clSQLJobs += New-Object PSObject -Property @{
					Pipe	   = $clSQLJob
					Result	   = $clSQLJob.BeginInvoke()
				}
			}
		}
		
	}

	$clSQLResults = @()  
  
	Do
	{
		Write-Host "." -NoNewline -ForegroundColor Green
		Start-Sleep -Milliseconds 200
	} while ($clSQLJobs.Result.IsCompleted -contains $false)

	ForEach ($clSQLJob in $clSQLJobs) 
	{       
		$clSQLResults += $clSQLJob.Pipe.EndInvoke($clSQLJob.Result)
	}

	Write-Host "All jobs completed!" -ForegroundColor Green

	$clSQLRunspacePool.Close()
	$clSQLRunspacePool.Dispose()

	return $clSQLResults
    
}