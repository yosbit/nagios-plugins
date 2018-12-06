<#
  .SYNOPSIS
   
  .DESCRIPTION
   Plugin for nagios to check Exchange Server 2007,2010,2013,2016.
   can check if all Exchange Databases are mounted, and Exchange Queue.
   
   .NOTES
   Auther Yossi Bitton yosbit@gmail.com
   Date: November 2018 
   Version 1.1.0   
   
   .PARAMETER CheckType
		"DBStatus" - Check all exchange databases if mounted or not, return Critical if one database is not mounted.
		"Queue"    - Check all queue in exchange server if empty or not. if queue items greater than Warn or Crit.
   .PARAMETER ExchangeVer (Optional)
		"2007" , "2010", "2013" ,"2016" - not needed, the plugin automaticly get the exchange version, and load the relevant PS-Module.
   .PARAMETER Warn
		integer - Used for test Queue, set the number of items in queue.
   .PARAMETER Crit
		integer - Used for test Queue, set the number of items in queue.
   .PARAMETER Debug
		Debug Mode.
		
   .EXAMPLE
	Check all exchange db status:
	.\check_exchange.ps1 -CheckType DBStatus 
	.\check_exchange.ps1 DBStatus
	
	Check exchange queue 
	.\check_exchange.ps1 -CheckType Queue -Warn 10 -Crit 50
	this command also works, using args position:
	.\check_exchange.ps1  Queue 10 50 
	
	NSClient with NSC.ini config file (old version)
	Edit NRPE config:
	Edit NSC.ini or nsclient.ini and add the following line under section:
	[Wrapped Scripts]
	check_exchange=check_exchange.ps1 $ARG1$
	[Script Wrappings]
	ps1 = cmd /c echo scripts\%SCRIPT%%ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command - 

	NSClient with nsclient.ini config file (new version)
	add the followings lines under:
	[/settings/external scripts/scripts]
	check_exchange = cmd /c echo scripts\check_exchange.ps1 $ARG1$ ; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass  -command -
	 
	 
#>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)] 
	[ValidateSet("DBStatus", "Queue")] 
	[String]$CheckType ,
	[parameter(Mandatory=$false,Position=2)] 
	[ValidateSet("2007" , "2010", "2013" ,"2016")] 
	[String]$ExchangeVer ,
	[parameter(Mandatory=$false,Position=3)]
	[int]$Warn ,
	[parameter(Mandatory=$false,Position=4)]
	[int]$Crit
	

)
begin {

Function Get-ExchangeServerVersion
{
	$retCode = $false
    $exPath = $env:exchangeinstallpath + "\bin\ExSetup.exe"
    If(Test-Path $exPath) {
        $productProperty = Get-ItemProperty -Path $exPath
        $desc = ($productProperty.VersionInfo.ProductVersion).split(".")[0]
		$retCode = $true
    }
    Else {
        $desc =  "Exchange Server not found."
    } 
return $retCode,$desc	
}

#Load-Exchange-Module
function Load-Exchange-Module() {
	Write-Debug "Load-Exchange-Module..."
	$retCode = $FAILED
	$desc = $null
	if ($ExchangeVer -eq "") {
		Write-Debug "Going to check Get-ExchangeServerVersion"
		$retCode,$desc = Get-ExchangeServerVersion
		Write-Debug "Get-ExchangeServerVersion: $retCode, $desc"
		if($retCode -eq $SUCCESS) {
			switch($desc) {
				"8" {$ExchangeVer="2007"}
				"08" {$ExchangeVer="2007"}
				"14" {$ExchangeVer="2010"}
				"15" {$ExchangeVer="2013"}
				"15.1" {$ExchangeVer="2016"}
			}
		}	
	}		
		Write-Debug "ExchangeVer=$ExchangeVer"
		try {
			$desc = $null
			$retCode = $FAILED
			switch($ExchangeVer)
			{
				"2007" {
						$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.Admin -PassThru
				}
				"2010"{
						$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -PassThru
				}
				"2013"{
						$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -PassThru
				}
				"2016"{
						$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -PassThru
				}
			}
			
			if($desc -ne $null) {
				$retCode = $SUCCESS
				Write-Debug "Load Status=$desc"
			}
		}catch{
			 $ExceptionType = $($_.Exception.GetType().FullName)
			 $ErrorMessage = $_.Exception.Message
			 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
			 $retCode = $FAILED
			 Write-Debug $desc
		}
		
		
	if ($retCode -eq $SUCCESS) {
		$desc = "Exchange module loaded successful"
		Write-Debug  $desc
		$retCode = $SUCCESS
	}else{
		$desc = "failed to load Exchange module"
		Write-Debug $desc
		$retCode = $FAILED
	}
return $retCode , $desc 
}

Function Get_Queue_Status () {
	$retCode = $UNKNOWN
	$desc = ""
	$perfData = ""
	$toatalQueue = 0
	try {
		$queueCount = Get-Queue -Server $server | where{$_.MessageCount -gt 0}| select Identity , MessageCount
		Write-Debug "Queue found on server $server = $queueCount"
		if ($queueCount -ne $null) {
			foreach ($q in $queueCount) {
				$qCount = $q.MessageCount
				$toatalQueue += $qCount
				if($qCount -gt $Crit) {
					$retCode = $CRITICAL
				}elseif ($qCount -gt $Warn)
				{
					if ($retCode -ne $CRITICAL) {
						$retCode = $WARNING
					}
				}elseif ($retCode -ne $CRITICAL -and $retCode -ne $WARNING)
				{
						$retCode = $OK
				}
			Write-Debug "Current retCode is: $retCode"
			$desc += "$($q.Identity) Queue Count: $($q.MessageCount) "	
			}
			
		}else{
			$desc = "Exchange queue is empty."
			$retCode = $OK
		}
	}catch{
			 $ExceptionType = $($_.Exception.GetType().FullName)
			 $ErrorMessage = $_.Exception.Message
			 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
			 $retCode = $UNKNOWN
			 Write-Debug $desc
	}
	$perfData = "|'Message Queue'=$toatalQueue;$Warn;$Crit;$toatalQueue"
	return $retCode , "$desc$perfData"
}


Function Get_DataBase_Status () {
	$retCode = $UNKNOWN
	try {
		$dblist = [Array] (Get-MailboxDatabase -Status | Where {$_.MountAtStartup -eq $true} | Select Name,Mounted)
		if ($dblist -ne $null) {
			$mountedDb = [Array] ($dblist | Where {$_.Mounted -eq $true} | Select Name)
			$notMountedDb =[Array] ($dblist | Where {$_.Mounted -eq $false} | Select Name)
			$totalDB = $dblist.Count 
			if ($notMountedDb.Count -eq 0) {
				$totalMountedDb = $mountedDb.Count
				$retCode = $OK
				$desc = "All Exchange DB are mounted, Databases: $($mountedDb.Name) Total: $totalDB"
			}else {
				$retCode = $CRITICAL
				$desc = "The Database: $($notMountedDb.Name) not mounted. [$($notMountedDb.Count)\$($totalDB.Count)]"
			}
		}else {
			$desc = "No database found on server"
		}
	}catch{
			 $ExceptionType = $($_.Exception.GetType().FullName)
			 $ErrorMessage = $_.Exception.Message
			 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
			 $retCode = $UNKNOWN
			 Write-Debug $desc
		}
	return $retCode , $desc
}
	
#Close Begin Section
}


	
process {
	If ($PSBoundParameters['Debug']) { 	# if -Debug passed as arguments, Write-Debug without stop
		$DebugPreference = 'Continue'
	}
	
	Set-Variable -Name "SUCCESS" -Value 100 -Option constant
	Set-Variable -Name "FAILED" -Value 50 -Option constant
	
	Set-Variable -Name "OK" -Value 0 -Option constant
	Set-Variable -Name "WARNING" -Value 1 -Option constant
	Set-Variable -Name "CRITICAL" -Value 2 -Option constant
	Set-Variable -Name "UNKNOWN" -Value 3 -Option constant
	$retCode = $UNKNOWN
	$SERVER = $env:COMPUTERNAME
	$ErrorActionPreference = 'Stop'
	
	Write-Debug "Warn=$Warn,Crit=$Crit"
	if ($Warn -eq $null -or $Warn -eq 0 ) {
		$Warn=30
		Write-Debug "Warn=$Warn"
	}
	if ($Crit -eq $null -or $Crit -eq 0)  {
		$Crit=100
		Write-Debug "Crit=$Crit"
	}
	
	
	# Load Exchange module
	$loadExchangeModule , $desc = Load-Exchange-Module						
	if ($loadExchangeModule -eq $SUCCESS) {
		Switch($CheckType) {
			"DBStatus" 
			{
				$check_status, $check_desc = Get_DataBase_Status 
				Write-Debug "Get_DataBase_Status: $check_status msg: $check_desc" 
			}
			"Queue"
			{
				$check_status, $check_desc = Get_Queue_Status 
				Write-Debug "Get_Queue_Status: $check_status msg: $check_desc" 
			}
		}
		$desc = $check_desc
		$retCode = $check_status
	}	
Write-Debug "retCode is: $retCode"
} # Close Process Section

end {
switch ($retCode)
	{
		$OK {$prefix="OK"}
		$WARNING {$prefix="WARNING"}
		$CRITICAL {$prefix="CRITICAL"}
		$UNKNOWN {$prefix="UNKNOWN"}
			
	}
	write-host $prefix":" $desc $perfData
        exit $retCode
} # Close end
