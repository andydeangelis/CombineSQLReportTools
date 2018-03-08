﻿function Remove-DbaXESession {
    <#
        .SYNOPSIS
            Removes Extended Events sessions.

        .DESCRIPTION
            This script removes Extended Events sessions on a SQL Server instance.

        .PARAMETER SqlInstance
            Target SQL Server. You must have sysadmin access and server version must be SQL Server version 2008 or higher.

        .PARAMETER SqlCredential
            Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

            $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

            Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

            To connect as a different Windows user, run PowerShell as that user.

        .PARAMETER Session
            Specifies a list of Extended Events sessions to remove.

        .PARAMETER AllSessions
            If this switch is enabled, all Extended Events sessions will be removed except the packaged sessions AlwaysOn_health, system_health, telemetry_xevents.

        .PARAMETER InputObject
            Accepts a collection of XEsession objects as output by Get-DbaXESession.

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
            
        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: ExtendedEvent, XE, Xevent
            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

        .LINK
            https://dbatools.io/Remove-DbaXESession

        .EXAMPLE
            Remove-DbaXESession -SqlInstance sql2012 -AllSessions

            Removes all Extended Event Session on the sqlserver2014 instance.

        .EXAMPLE
            Remove-DbaXESession -SqlInstance sql2012 -Session xesession1,xesession2

            Removes the xesession1 and xesession2 Extended Event sessions.
        
        .EXAMPLE
            Get-DbaXESession -SqlInstance sql2017 | Remove-DbaXESession -Confirm:$false

            Removes all sessions from sql2017, bypassing prompts.

        .EXAMPLE
            Get-DbaXESession -SqlInstance sql2012 -Session xesession1 | Remove-DbaXESession

            Removes the sessions returned from the Get-DbaXESession function.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Session', SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [parameter(Position = 1, Mandatory, ParameterSetName = 'Session')]
        [parameter(Position = 1, Mandatory, ParameterSetName = 'All')]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [parameter(ParameterSetName = 'Session')]
        [parameter(ParameterSetName = 'All')]
        [PSCredential]$SqlCredential,
        [parameter(Mandatory, ParameterSetName = 'Session')]
        [Alias("Sessions")]
        [object[]]$Session,
        [parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$AllSessions,
        [parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Object')]
        [Microsoft.SqlServer.Management.XEvent.Session[]]$InputObject,
        [switch]$EnableException
    )

    begin {
        # Remove each XESession
        function Remove-XESessions {
            [CmdletBinding()]
            param ([Microsoft.SqlServer.Management.XEvent.Session[]]$xeSessions)
            
            foreach ($xe in $xeSessions) {
                $instance = $xe.Parent.Name
                $session = $xe.Name
                
                if ($Pscmdlet.ShouldProcess("$instance", "Removing XEvent Session $session")) {
                    try {
                        $xe.Drop()
                        [pscustomobject]@{
                            ComputerName = $xe.Parent.NetName
                            InstanceName = $xe.Parent.ServiceName
                            SqlInstance  = $xe.Parent.DomainInstanceName
                            Session      = $session
                            Status       = "Removed"
                        }
                    }
                    catch {
                        Stop-Function -Message "Could not remove XEvent Session on $instance" -Target $session -ErrorRecord $_ -Continue
                    }
                }
            }
        }
    }
    
    process {
        if ($InputObject) {
            # avoid the collection issue
            $sessions = Get-DbaXESession -SqlInstance $InputObject.Parent -Session $InputObject.Name
            foreach ($item in $sessions) {
                Remove-XESessions $item
            }
        }
        else {
            foreach ($instance in $SqlInstance) {
                $xeSessions = Get-DbaXESession -SqlInstance $instance -SqlCredential $SqlCredential

                # Filter xeSessions based on parameters
                if ($Session) {
                    $xeSessions = $xeSessions | Where-Object { $_.Name -in $Session }
                }
                elseif ($AllSessions) {
                    $systemSessions = @('AlwaysOn_health', 'system_health', 'telemetry_xevents')
                    $xeSessions = $xeSessions | Where-Object { $_.Name -notin $systemSessions }
                }

                Remove-XESessions $xeSessions
            }
        }
    }
}