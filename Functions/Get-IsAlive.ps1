# Function to determine of a server is alive by testing network connection.

function Get-IsAlive 
{ 
  Param(
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string[]]$ComputerNames
  )

  $aliveScript = {

    Param($computer,$port)

    # Let's hide the progress bars by setting the global variable $ProgressPreference for the session.

    $ProgressPreference = 'SilentlyContinue'

     function Test-TCPport 
     {
        Param([parameter(Mandatory=$true,ValueFromPipeline=$True)][string[]]$ComputerName,
              [parameter(Mandatory=$true,ValueFromPipeline=$True)]$TCPport
        )

        $requestCallback = $state = $null
        $client = New-Object System.Net.Sockets.TcpClient
        $beginConnect = $client.BeginConnect($ComputerName,$TCPport,$requestCallback,$state)
        Start-Sleep -Milliseconds 500
        if ($client.Connected) 
        {
            $open = $true
        } 
        else
        {
            $open = $false            
        }

        $client.Close()
        
        [pscustomobject]@{hostname=$ComputerName;port=$TCPport;open=$open}
     }

     $status = Test-TCPport -ComputerName $computer -TCPport $port

     if ($status.open -eq $true)
      {        
        $computer
      }
      
  }

  $Throttle = 20
  $isAliveInitialSessionState =[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $isAliveRunspacePool = [RunspaceFactory]::CreateRunspacePool(1,$Throttle,$isAliveInitialSessionState,$Host)
  $isAliveRunspacePool.Open()
  $isAliveJobs = @()

  foreach ($computer in $ComputerNames)
  {
    $port = 445
    $isAliveJob = [powershell]::Create().AddScript($aliveScript).AddArgument($computer).AddArgument($port)
    $isAliveJob.RunspacePool = $isAliveRunspacePool
    $isAliveJobs += New-Object PSObject -Property @{
      Pipe = $isAliveJob
      Result = $isAliveJob.BeginInvoke()
    } 
  }

  Write-Host "Checking if servers are alive..." -NoNewline -ForegroundColor Green

  Do
  {
    Write-Host "." -NoNewline -ForegroundColor Green
    Start-Sleep -Milliseconds 500
  } while ($isAliveJobs.Result.IsCompleted -contains $false)

  $aliveServers = @()

  ForEach ($isAliveJob in $isAliveJobs) 
  {     
    $aliveServers += $isAliveJob.Pipe.EndInvoke($isAliveJob.Result)
  }

  Write-Host "All jobs completed!" -ForegroundColor Green

  $isAliveRunspacePool.Close()
  $isAliveRunspacePool.Dispose()

 

  return $aliveServers
} 