# Function to determine of a server is alive by testing network connection.

function Get-IsAlive 
{ 
  Param(
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string[]]$ComputerNames
  )

  $aliveScript = {

    Param($computer)

    # Let's hide the progress bars by setting the global variable $ProgressPreference for the session.

    $ProgressPreference = 'SilentlyContinue'
  
      if (((Test-NetConnection -ComputerName $computer -Port 445 -InformationLevel Quiet -WarningAction SilentlyContinue) -eq $true) -or 
            ((Test-NetConnection -ComputerName $computer -Port 139 -InformationLevel Quiet -WarningAction SilentlyContinue) -eq $true))
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
    $isAliveJob = [powershell]::Create().AddScript($aliveScript).AddArgument($computer)
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
    Start-Sleep -Milliseconds 200
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