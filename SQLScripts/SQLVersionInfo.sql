SELECT
            SERVERPROPERTY('MachineName') AS [ServerName], 
			SERVERPROPERTY('ServerName') AS [ServerInstanceName], 
            SERVERPROPERTY('InstanceName') AS [Instance], 
            SERVERPROPERTY('Edition') AS [Edition],
            SERVERPROPERTY('ProductVersion') AS [ProductVersion], 
			Left(@@Version, Charindex(' - ', @@version) - 1) As VersionName