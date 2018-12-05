<#
  .SYNOPSIS
   
  .DESCRIPTION
   Script for nagios to check time against NTP servers, then automaticly correct the time and date offset is abouve or bellow
   threshold levels.
   You can add multi NTP servers with comma separated
   
  .NOTES
   Auther Yossi Bitton yosbit@gmail.com
   Date: November 2018 
   Version 1.1.3 
   
   .PARAMETER NTPServers
    NTP server IP or DNS name.
	for more than one NTP server, use: ntp_server_ip1,ntp_server_ip2
	
   .PARAMETER secondsDiffWarn - Alias -W
	If offset is bellow or above from secondsDiffWarn in seconds, the script try to fix the time, if fix is failed exit with WARNING.
	
	.PARAMETER secondsDiffWarn Alias -C
	If offset is bellow or above from secondsDiffCrit in seconds, the script try to fix the time, if fix is failed exit with CRITICAL.
	
  .EXAMPLE
	.\check_time.ps1  -NTPServers 192.168.1.1 -W 5 -C 15
	.\check_time.ps1  -NTPServers 192.168.1.1,192.168.10.100 -W 5 -C 15
	\check_time.ps1  -NTPServers 192.168.1.1,192.168.10.100 -W 5 -C 15 -Debug	
	.\check_time.ps1  ( Works with default params)
	
    NSClient with NSC.ini config file (old version)
	Edit NRPE config:
	Edit NSC.ini or nsclient.ini and add the following line under section:
	[Wrapped Scripts]
	check_mssql=check_mssql.ps1 $ARG1$
	[Script Wrappings]
	ps1 = cmd /c echo scripts\%SCRIPT%%ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command - 

	NSClient with nsclient.ini config file (new version)
	add the followings lines under:
	[/settings/external scripts/scripts]
	check_mssql = cmd /c echo scripts\check_mssql.ps1 $ARG1$ ; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass  -command -
	
#>
[CmdletBinding()]
Param(
	[parameter(Mandatory=$false)] 
	[String[]]$NTPServers=@("timeserver.iix.net.il" ,"0.pool.ntp.org"),
	[Alias("W")]
	[int]$secondsDiffWarn=5 ,
	[Alias("C")]
	[int]$secondsDiffCrit=30
	
)


begin {
	Function Connect-To-NTP ($ntp) {
	try {
		$NTPData    = New-Object byte[] 48  # Array of 48 bytes set to zero
		$NTPData[0] = 27                    
		# Open a connection to the NTP service
		$Socket = New-Object Net.Sockets.Socket ( 'InterNetwork', 'Dgram', 'Udp' )
		$Socket.SendTimeOut    = 2000  # ms
		$Socket.ReceiveTimeOut = 2000  # ms
		$Socket.Connect( $NTPServer, 123 )
		$send = $Socket.Send(    $NTPData )
		# try {
		$receive = $Socket.Receive( $NTPData )
		Write-Debug "NTP Receive: $receive"
		if ($receive -ne $Null) {
			# Extract relevant portion of first date in result (Number of seconds since "Start of Epoch")
			$Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )
			# Add them to the "Start of Epoch", convert to local time zone, and return
			$ntpDate = ( [datetime]'1/1/1900' ).AddSeconds( $Seconds ).ToLocalTime()
			$desc = "Connected to NTP Server: $NTPServer"
			$retCode = $OK
		}else{
			$desc = "Cannot Connect to NTP server: $NTPServer"
			$retcode = $UNKNOWN
		}
		$Socket.Shutdown( 'Both' )
		$Socket.Close()
	
	}catch{
		 $ExceptionType = $($_.Exception.GetType().FullName)
		 $ErrorMessage = $_.Exception.Message
		 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
		 if ($ExceptionType -eq "System.Management.Automation.MethodInvocationException") {
			 $desc = "Cannot connect to NTP server: $NTPServers"
		  }
		 
	}
	write-Debug "retCode = $retcode ,Status: $desc , ntpDate: $ntpDate"	
	return $retCode , $desc ,$ntpDate
	
}
	
Function Get-Time-Diff ($ntpDate)
	{
	try {
		$localDate = Get-Date
		Write-Debug "Local Data: $localDate"
		Write-Debug "NTP Date: $ntpDate"
		$timeDiff = New-TimeSpan -Start $localDate -End $ntpDate
		Write-Debug "timeDiff = $timeDiff"
		$secondsDiff = ($timeDiff.TotalSeconds)
		if ($secondsDiff -lt 0) {
			$secondsDiff = $secondsDiff * -1
		}
		Write-Debug "secondsDiff = $secondsDiff"
		if ($secondsDiff -gt $secondsDiffCrit) {
			$desc = "NTP CRITICAL, Offset: $secondsDiff seconds."
			$setDate = Set-date -Date $ntpDate
			$retCode = $CRITICAL
		}elseif($secondsDiff -gt $secondsDiffWarn) {
			$desc = "NTP WARNING, Offset: $secondsDiff seconds."
			$setDate = Set-date -Date $ntpDate
			$retCode = $WARNING
		}elseif ($secondsDiff -lt $secondsDiffWarn){
			$desc = "NTP OK, Offset: $secondsDiff seconds."
			$retCode = $OK
		}else{
			$desc = "Cannot determinate the ntp status"
			$retCode = $UNKNOWN
		}
			
		}catch{
			 $ExceptionType = $($_.Exception.GetType().FullName)
			 $ErrorMessage = $_.Exception.Message
			 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
		}
	return $retCode , $desc
	} 
	
# End Begin
}
process { 
		If ($PSBoundParameters['Debug']) { 	# if -Debug passed as arguments, Write-Debug without stop
			$DebugPreference = 'Continue'
		}
		$ErrorActionPreference = 'Stop'
		Set-Variable -Name "OK" -Value 0 -Option constant
		Set-Variable -Name "WARNING" -Value 1 -Option constant
		Set-Variable -Name "CRITICAL" -Value 2 -Option constant
		Set-Variable -Name "UNKNOWN" -Value 3 -Option constant
		$retCode = $UNKNOWN
		$desc = "Cannot determinate the ntp status"
		
	try {
		foreach ($NTPServer in $NTPServers) {
			$retCode, $desc ,$ntpDate = Connect-To-NTP $NTPServer
			Write-Debug "Connect status: $retcode , Desc: $desc"
			# Get the time diff between local server date and time, and NTP Server.
			if ($retCode -eq $OK) {
				$retCode , $desc = Get-Time-Diff $ntpDate
				# Sync again before return non OK.
				if ($retCode -eq $CRITICAL -or $retCode -eq $WARNING) {
					Write-Debug "Going to resync the date again"
					$retCode, $desc ,$ntpDate = Connect-To-NTP
					$retCode , $desc = Get-Time-Diff $ntpDate
				}
				break
			}
		}
	}catch{
		 $ExceptionType = $($_.Exception.GetType().FullName)
		 $ErrorMessage = $_.Exception.Message
		 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"

	}
# End process
}

end {
switch ($retCode)
	{
		$OK {$prefix="OK"}
		$WARNING {$prefix="WARNING"}
		$CRITICAL {$prefix="CRITICAL"}
		$UNKNOWN {$prefix="UNKNOWN"}
			
	}
	write-host $prefix":" $desc
        exit $retCode
} # Close end
