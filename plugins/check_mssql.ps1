<#
  .SYNOPSIS
  
  .DESCRIPTION
   Script for nagios to check SQL DataBases, Connection Time, Jobs, TempDB Size, Log Size.
   The script get all sql instances in the server, and return status for eache instance
   You can use check_mssql_config.ini to exclude DB or instance to check, read check_mssql_config.ini help.
  
  
  .NOTES
   Auther Yossi Bitton yosbit@gmail.com
   Patch: Nicki Messerschmidt <n.messerschmidt@gmail.com>
   Date: September 2021
   Version 1.1.3
   
  .PARAMETER DBStatus
   Get the database status, return critical if one DB not in normal state.

  .PARAMETER ConnectionTime
   Get the time to connect to DB, include performance data.
   
  .PARAMETER Jobs
   Get the status off all jobs, the script check only Enabled and scheduled jobs.
   Checks if a job missed its schedule
   
  .PARAMETER TempDBSize
   Get the size of temp DB.
   see values of warning and critical in check_mssql_config.ini config.
   
  .PARAMETER
   Get the size of Log file for eache DB.
   see values of warning and critical in check_mssql_config.ini config.
   
   
  .EXAMPLE
    ./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'DBStatus'
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'ConnectionTime'
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'Jobs'
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'TempDBSize'
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'LogSize'
  
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
	[parameter(Mandatory=$true)] 
	[ValidateSet("DBStatus", "ConnectionTime", "Jobs" ,"TempDBSize" , "LogSize")] 
	[Alias("T")]
	[String]$CheckType,
	[Boolean]$ForceConfigFile=$False,
	[int]$timeToConnectWarn=3 ,
	[int]$timeToConnectCrit=5 
	
)

begin {
# Read ini file function 
Function Get-IniContent {
	[CmdletBinding()]  
	Param(  
		[ValidateNotNullOrEmpty()]  
		[ValidateScript({(Test-PATH $_) -and ((Get-Item $_).Extension -eq ".ini")})]  
		[Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
		[string]$FilePATH  
	)  
		$ini = @{}  
		switch -regex -file $FilePATH  
		{  
			"^\[(.+)\]$" # Section  
			{  
				$section = $matches[1]  
				$ini[$section] = @{}  
				$CommentCount = 0  
			}  
			"^(;.*)$" # Comment  
			{  
				if (!($section))  {  
					$section = "No-Section"  
					$ini[$section] = @{}  
				}  
				$value = $matches[1]  
				$CommentCount = $CommentCount + 1  
				$name = "Comment" + $CommentCount  
				$ini[$section][$name] = $value  
			}   
			"(.+?)\s*=\s*(.*)" # Key  
			{  
				if (!($section))  {  
					$section = "No-Section"  
					$ini[$section] = @{}  
				}  
				$name,$value = $matches[1..2]  
				$ini[$section][$name] = $value  
			}  
		}  
		Return $ini  
} 
	
Function Get-SqlInstances {
	$retCode = $UNKNOWN
	try {
		$all_sql_instances = Get-WmiObject -Class Win32_Service | Where {($_.Name -like 'MSSQL$*'  -Or $_.Name -like 'MSSQLSERVER') -and ($_.StartMode -eq 'Auto')}
		if($all_sql_instances -ne $null) {
			Write-Debug "Got the following Instances: $($all_sql_instances.Name)"
			$runningInstances = $all_sql_instances | where {$_.State -eq "Running"} 
			$notRunningInstances = $all_sql_instances | where {$_.State -ne "Running"} 
			if($runningInstances -ne $null) {
				Write-Debug "Running Instances: $($runningInstances.Name)"
				[System.Collections.ArrayList]$runInstanceName = @();
				foreach ($instance in $runningInstances) {
					if ($instance.Name -eq 'MSSQLSERVER')  {
							$runInstanceName += $instance.Name;
							
					}else{
						$str = $($instance.Name)
						$str = $str.split('$')[1];
						$runInstanceName +=$str;
					}
				}
			}
			if ($notRunningInstances -ne $Null) {
				Write-Debug "Not Running Instances: $($notRunningInstances.Name)"
				[System.Collections.ArrayList]$NotRunInstanceName = @();
				foreach ($notRuninstance in $notRunningInstances) {
					if ($notRuninstance.Name -eq 'MSSQLSERVER')  {
							$NotRunInstanceName += $notRuninstance.Name;
							
					}else{
						$str = $($notRuninstance.Name)
						$str = $str.split('$')[1];
						$NotRunInstanceName +=$str;
					}
				}
			}
			
			$excludeInstances = Read-SqlConfigFile $SQL_INSTANCES_SECTION $SQL_CONFIG_EXCLUDE_NAME
			
			if ($excludeInstances -ne $null) {
				$excludeInstances = $excludeInstances.split(',')
				Write-Debug "Exclude instances=$excludeInstances"
				foreach($exl in $excludeInstances) {
					if ($runInstanceName -Ne $null) {
						Write-Debug "Going to check if  $exl in $runInstanceName"
						$runInstanceName.remove($exl)
					}
					if ($NotRunInstanceName -Ne $null) {
						Write-Debug "Going to check if  $exl in $NotRunInstanceName"
						$NotRunInstanceName.remove($exl)
					}
				}
			}
			
			Write-Debug "Not running instance count: $($NotRunInstanceName.Count)"
			Write-Debug "Running instance count: $($runInstanceName.Count)"
			$desc = ""
			if ($NotRunInstanceName.Count -gt 0) {
				$retCode = $CRITICAL
				$desc = "Instance: $NotRunInstanceName Service not running."
				Write-Debug "NotRunInstanceName - $desc"
			}elseif ($runInstanceName.Count -gt 0) {
				$retCode = $SUCCESS
				$desc = $runInstanceName
				Write-Debug "runInstanceName - $desc"
			}else {
				$desc = "No instance to check available."
				$retCode = $OK
				Write-Debug  "desc=$desc"
			}
		}else{
			$desc = "SQL service are not found on the server"
		}
	}catch{
		 $ExceptionType = $($_.Exception.GetType().FullName)
		 $ErrorMessage = $_.Exception.Message
		 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
		 $retCode = $UNKNOWN
	}
	Write-Debug "Function Get-SqlInstances return: retCode: $retCode, output: $desc"
return $retCode,$desc
}

Function Read-SqlConfigFile ($configSection, $configName) {
	try {
		if (Test-PATH -Path "$SQL_CONFIG_FILE_FULL_PATH") {
			$configFileContent = Get-IniContent "$SQL_CONFIG_FILE_FULL_PATH"
			if ($configFileContent.ContainsKey($configSection)) {
				$configValue = $configFileContent[$configSection][$configName]
				$desc = $configValue
				Write-Debug "configValue=$desc"
			}else {
				$desc = "$SQL_CONFIG_FILE_NAME does not contain section $configSection"
			}
		}else{
			$desc = "SQL config file $SQL_CONFIG_FILE_NAME, does not exists"
		}
	}catch{
		 $ExceptionType = $($_.Exception.GetType().FullName)
		 $ErrorMessage = $_.Exception.Message
		 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
	}
Write-Debug "Read-SqlConfigFile return $desc"
return $desc 
}

Function Get-TempDB-Threshold ($fileCount,  $dbSize ,$thresholdSplited) {
	Write-Debug "In Get-TempDB-Threshold - got file count: $fileCount"
	$retCode = $UNKNOWN
	foreach ($tsLevel in $thresholdSplited) {
		$levelValues = $tsLevel -split(",")
		Write-Debug "levelValues : $levelValues"
		$subLevel = $levelValues -split(' ')
		$checkFileCount =[Int]$subLevel[0]
		Write-Debug "checkFileCount level = $checkFileCount"
		if($fileCount -le $checkFileCount) {
			$warningLevel = [int]$subLevel[1]
			Write-Debug "Warning DB Size in MB:  = $warningLevel"  
			$criticalLevel =  [int]$subLevel[2]
			Write-Debug "Critical DB Size in MB:  = $criticalLevel" 
			if ($dbSize -le $criticalLevel){
				if($dbSize -le $warningLevel) {
					$retCode = $OK
				}else{
					$retCode = $WARNING
				}		
			}else{
				$retCode = $CRITICAL
			}
			$desc = "Count=$fileCount Size=$dbSize Mb, " 
			break
		}else{
			Write-Debug "Not matches - fileCount: $fileCount is greater than  $level"
		}
	}
Write-Debug "Get-TempDB-Threshold return: $retCode desc: $desc"
return $retCode, $desc
}

Function Get-TempDB-Size ($InstancesList) {
	Write-Debug "In Get-TempDB-Size, InstancesList: $InstancesList"
	$retCode = $UNKNOWN
	$failedToConnectCount = 0
	$isCritical = $False
	$isWarning = $False
    $perfData = "| "
	
	try  {
		$temp_db_threshold_values = Get-Treshold-From-Ini $SQL_CONFIG_TEMPDB_SIZE_NAME $SQL_TEMPDB_THRESHOLD_SECTION
		if ($temp_db_threshold_values -eq $null) {
			$temp_db_threshold_values = $temp_db_default_threshold_value
		}
	}catch{
		$ExceptionType = $($_.Exception.GetType().FullName)
		$ErrorMessage = $_.Exception.Message
		$desc = "Instance: $instance Exception: $ErrorMessage $fullQualified. "
		$temp_db_threshold_values = $temp_db_default_threshold_value
		Write-Debug $desc
	}
	foreach ($instance in $InstancesList) {
		$connectCode, $connectDesc ,$sqlObj = Connect-To-SQL $instance $false
		if ($connectCode -eq $SUCCESS) {
			try {
				$tempdb = $sqlObj.Databases["tempdb"]
				$temp_db_size = [int]$tempdb.Size
				Write-Debug "TempDB DB Size $temp_db_size MB"
				$tempDBPath =  $tempdb.PrimaryFilePath
				$Filter = "*.mdf"
				$mdfFileCount = Get-ChildItem -Path $tempDBPath -Filter $Filter
				$mdfFileCount = [Array]$mdfFileCount
				$temp_db_mdf_file_count = $mdfFileCount.Count
				Write-Debug "TempDB mdf files count: $temp_db_mdf_file_count"
				$instanceRetCode, $instance_desc = Get-TempDB-Threshold $temp_db_mdf_file_count 	$temp_db_size $temp_db_threshold_values
				$desc = "$instance $instance_desc"
                $perfData += "'"+$instance+"_"+$tempdb+"_Size'=$temp_db_size[MB] "
                $perfData += "'"+$instance+"_"+$tempdb+"_FileCount'=$temp_db_mdf_file_count "
				if ($instanceRetCode -eq $CRITICAL) {
					$critical_desc +=$desc
				}elseif ($instanceRetCode -eq $WARNING) {
					$warning_desc += $desc
				}
			}catch{
				$ExceptionType = $($_.Exception.GetType().FullName)
				$ErrorMessage = $_.Exception.Message
				$desc = "$instance Exception: $ErrorMessage $fullQualified. "
				$failedToConnectCount+=1
			}
		}else {
			$desc = $connectDesc
			$failedToConnectCount+=1
			$unknown_desc +=$desc
		}
		
		if ($instanceRetCode -eq $CRITICAL -and $isCritical -eq $False) {
			$isCritical = $True
		}
		if ($instanceRetCode -eq $WARNING -and $isWarning -eq $False) {
			$isWarning = $True
		}
		$instance_status += $desc
		Write-Debug "All instances status=$instance_status"
	}
	
	$ALL_INSTANCES_SUMMARY += $instance_status 
		
	if($isCritical -eq  $True) {
		$retCode = $CRITICAL
	}elseif($isWarning -eq $True) {
		$retCode = $WARNING
	}else{
		if($failedToConnectCount -eq 0 ) {
			$retCode = $OK
			$instance_status = "All tempdb size in all sql instances are in size range. Total Instances=$($InstancesList.Count)."
		}
	}
	
	if ($retCode -ne $OK) {
		$instance_status = "$critical_desc $warning_desc $unknown_desc"
	}
	$desc = "$instance_status`n$ALL_INSTANCES_SUMMARY" 
Write-Debug "Get-TempDB-Size return: retCode: $retCode, desc: $desc"
return $retCode,$desc,$perfData
	
}

Function Get-LogFile-Threshold ($dbSize,  $logSize, $thresholdSplited) {
	Write-Debug "In Get-LogFile-Threshold - Got: dbSize: $db_size ,logSize $logSize ,thresholdSplite $thresholdSplited"
	$retCode = $UNKNOWN
	foreach ($tsLevel in $thresholdSplited) {
		$levelValues = $tsLevel -split(",")
		Write-Debug "levelValues=$levelValues"
		$subLevel = $levelValues -split(' ')
		$level =[Int]$subLevel[0]
		Write-Debug "level=$level"
		if($dbSize -le $level) {
			$warningLevel = [int]$subLevel[1]
			Write-Debug "Warning level=$warningLevel"  
			$criticalLevel =  [int]$subLevel[2]
			Write-Debug "Critical level=$criticalLevel" 
			$criticalLevelPercent = ($dbSize * $criticalLevel)  / 100
			$warninglLevelPercent = ($dbSize * $warningLevel)  / 100
			Write-Debug "criticalLevelPercent=$criticalLevelPercent warninglLevelPercent=$warninglLevelPercent"
			if ($logSize -le $criticalLevelPercent){
				if($logSize -le $warninglLevelPercent) {
					$retCode = $OK
				}else{
					$retCode = $WARNING
				}		
			}else{
				$retCode = $CRITICAL
			}
			$desc = "$dbSize Mb Log=$logSize Mb. " 
			Write-Debug "retCode=$retCode"
			break
		}else{
			Write-Debug "DB Size not matches to threshold level - $db_size is greater than $level"
		}
	}
Write-Debug "Get-LogFile-Threshold return: $retCode desc: $desc"
return $retCode, $desc
}

Function Get-Treshold-From-Ini ($sql_config_name,$sql_config_section ) {
try {
		$log_file_threshold_values = Read-SqlConfigFile $sql_config_name $sql_config_section
		Write-Debug "Log file threshold from ini file $log_file_threshold_values"
		if ($log_file_threshold_values -ne $null) {
			$threshold_values=$log_file_threshold_values
		}
		Write-Debug "Log file threshold values:  $threshold_values"
		$threshold_splited = $threshold_values.split(';')
	}catch{
		 $ExceptionType = $($_.Exception.GetType().FullName)
		 $ErrorMessage = $_.Exception.Message
		 Write-Debug "Exception: $ErrorMessage $fullQualified. "
	}
return $threshold_splited 
}

Function Get-LogFile-Size ($InstancesList) {
	Write-Debug "In Get-LogFile-Size, InstancesList: $InstancesList"
	$retCode = $UNKNOWN
	$failedToConnectCount = 0
	$isCritical = $False
	$isWarning = $False
	$all_instance_db=0
    $perfData="| "
	$log_size_threshold_values = Get-Treshold-From-Ini $SQL_CONFIG_LOG_FILES_SIZE_NAME $SQL_LOG_FILE_SIZE_THRESHOLD_SECTION
	if ($log_size_threshold_values -eq $null) {
		$log_size_threshold_values = $log_file_size_threshold_default_value
	}
	foreach ($instance in $InstancesList) {
		$failedLogFilesCount = 0
		$desc = ""
		$connectCode, $connectDesc ,$sqlObj = Connect-To-SQL $instance $false
		if ($connectCode -eq $SUCCESS) {
			try {
				$totalDb = $sqlObj.Databases.Count
				$all_instance_db +=$totalDb 
				Write-Debug "Total database count=$totalDb"
				foreach($db in $sqlObj.Databases) {
					$dbName = $db.Name
					$dbSize = [int]$db.Size
					$dbLogSize = [int](($db.LogFiles[0]).Size)
					$dbLogSize = [int]($dbLogSize / 1024)
					Write-Debug "dbName=$dbName dbSize=$dbSize MB. dbLogSize=$dbLogSize MB."
					$dbLogFileName = $db.LogFiles
					$desc += "$dbName=$dbSize, Log=$dbLogSize. "
                    $perfData += "'"+$dbName+"_Size'=$dbSize[MB] '"+$dbName+"_Log_Size'=$dbLogSize[MB] "
					$instanceRetCode, $instanceDesc = Get-LogFile-Threshold $dbSize $dbLogSize $log_size_threshold_values
					if ($instanceRetCode -ne $OK) {
						Write-Debug "instanceRetCode = $instanceRetCode"
						$failedLogFilesCount +=1
						$failedLogFiles += "$dbName=$dbSize, Log=$dbLogSize. "
						Write-Debug "failedLogFiles = $failedLogFiles"
						if ($instanceRetCode -eq $CRITICAL -and $isCritical -eq $False) {
							Write-Debug "isCritical going to set to True"
							$isCritical = $True
						}
						if ($instanceRetCode -eq $WARNING -and $isWarning -eq $False) {
							Write-Debug "isWarning going to set to True"
							$isWarning = $True
						}
					}
				}
				$desc = "$instance $desc"
				if ($failedLogFiles -gt 0) {
					$failedLogFiles = "$instance $failedLogFiles"
				}
				
			}catch{
				 $ExceptionType = $($_.Exception.GetType().FullName)
				 $ErrorMessage = $_.Exception.Message
				 $desc = "Instance: $instance Exception: $ErrorMessage $fullQualified. "
				 $failedToConnectCount+=1
			}
		}else {
			$desc = $connectDesc
			$failedToConnectCount+=1
			$unknown_desc +=$desc
		}
		
		$instance_status += $desc
		Write-Debug "All Instances Status=$instance_status"
		
	}
	$ALL_INSTANCES_SUMMARY_IN_MB += $instance_status
	if($isCritical -eq  $True) {
		$retCode = $CRITICAL
	}elseif($isWarning -eq $True) {
		$retCode = $WARNING
	}else{
		if($failedToConnectCount -eq 0 ) {
			$retCode = $OK
			$instance_status = "Log size for all databases in all instances are OK. Total Instances=$($InstancesList.Count) Total Databases=$all_instance_db" 
		}
	}
	if ($retCode -ne $OK) {
		$instance_status = "$failedLogFiles $unknown_desc"
	}
	$desc = "$instance_status`n$ALL_INSTANCES_SUMMARY_IN_MB" 
Write-Debug "Get-LogFile-Size return: retCode: $retCode, desc: $desc"
return $retCode,$desc,$perfData
}

Function Get-DataBases-Status ($InstancesList) {
	Write-Debug "In Get-DataBases-Status, InstancesList: $InstancesList"
	$retCode = $UNKNOWN
	$failedToConnectCount = 0
	$all_instance_db=0
	foreach ($instance in $InstancesList) {
		$failedDBCount = 0
		$desc = ""
		$failedDB = ""
		$connectCode, $connectDesc ,$sqlObj = Connect-To-SQL $instance $false
		if ($connectCode -eq $SUCCESS) {
			try {
				$totalDb = $sqlObj.Databases.Count
				$all_instance_db += $totalDb
				Write-Debug "Total database count: $totalDb"
				foreach($db in $sqlObj.Databases) {
					$dbName = $db.Name
					$dbStatus = $db.Status
					$desc += "$dbName=$dbStatus, "
					if($dbStatus -notlike "*Normal*") {
						$failedDBCount +=1
						$failedDB += "$dbName=$dbStatus, "
					}
				}
				
				if ($failedDBCount -eq 0) {
					$desc = "$instance $desc [$totalDb]. "
				}else{
					$desc = "$instance failed db $failedDB [$failedDBCount/$totalDb]. "
					$critical_desc +=$desc
					$retCode = $CRITICAL
				}
			}catch{
				 $ExceptionType = $($_.Exception.GetType().FullName)
				 $ErrorMessage = $_.Exception.Message
				 $desc = "Instance: $instance Exception: $ErrorMessage $fullQualified. "
				 $failedToConnectCount+=1
			}
		}else {
			$desc = $connectDesc
			$failedToConnectCount+=1
			$unknown_desc +=$desc
		}
		Write-Debug $desc
		$instance_status += $desc
		Write-Debug "All Instances Status=$instance_status"
		
	}
	$ALL_INSTANCES_SUMMARY += $instance_status
	if($retCode -ne  $CRITICAL) {
		Write-Debug "failedToConnectCount=$failedToConnectCount"
		if($failedToConnectCount -eq 0 ) {
			$retCode = $OK
			$instance_status = "All databases in all sql instances are in normal state. Total Instances=$($InstancesList.Count) Total Databases=$all_instance_db"
		}
	}else{
		$instance_status = "$critical_desc $unknown_desc"
	}
	$desc = "$instance_status`n$ALL_INSTANCES_SUMMARY" 
    $perfData = "| 'Database_Count'=$all_instance_db"
Write-Debug "Get-DataBases-Status return: retCode: $retCode, desc: $desc"
return $retCode,$desc, $perfData
}

Function Connect-To-SQL ($instance,$getTime2Connect){
	Write-Debug "In Connect-To-SQL, Instance:$instance"
	Write-Debug "Trying to connect to SQL Instance:$instance"
	$retCode = $FAILED
	$desc = "Trying to connect to SQL Instance:$instance"
	if ($instance -ne "MSSQLSERVER") {	
		$instance = ".\$instance"
	}else{
		$instance = $env:COMPUTERNAME
	}
	try {
		if ($getTime2Connect -eq $True) {
			Write-Debug "Got getTime2Connect"
			$time2Connect = (Measure-Command { $sqlObj = New-Object "Microsoft.SqlServer.Management.Smo.Server" "$instance"}).totalseconds
		}else{
			$sqlObj = New-Object "Microsoft.SqlServer.Management.Smo.Server" "$instance"
		}
		
		if ($sqlObj.Version -ne $Null){
			$desc = "Connected to SQL instance=$instance ,Version=$($sqlObj.Version)"
			Write-Debug $desc
			$retCode = $SUCCESS
		}else{
			$desc = "Instance: $instance failed to connect. "
		}
	}catch{
		 $ExceptionType = $($_.Exception.GetType().FullName)
		 $ErrorMessage = $_.Exception.Message
		 $desc = "Instance:$instance Exception: $ErrorMessage $fullQualified. "
	}
Write-Debug "Connect-To-SQL return: retCode:$retCode, desc:$desc sqlObj:$sqlObj"
if ($getTime2Connect -eq $True) {
	return $retCode,$desc,$sqlObj,$time2Connect
}
return $retCode,$desc,$sqlObj
}

function Get-SQL-Jobs-Status ($InstancesList) {
	Write-Debug "In Get-SQL-Jobs-Status, InstancesList: $InstancesList"
	$retCode = $UNKNOWN
	$failedToConnectCount = 0
	$desc = "sql jobs status can not be determined"
	$critical_desc = ""
	$total_instance_jobs = 0
	$unknown_desc = ""
	foreach ($instance in $InstancesList) {
		$connectCode, $connectDesc , $sqlObj = Connect-To-SQL $instance $false
		# Write-Debug "connectCode=$connectCode , connectDesc=$connectDesc , sqlObj=$sqlObj"
		if ($connectCode -eq $SUCCESS) {
			try {
				$failedJobsCount = 0
                $missedJobsCount = 0
				Write-Debug "Going to get jobs list $($sqlObj.Version)"
				$jobs=$sqlObj.JobServer.Jobs
				Write-Debug  "All Jobs = $Jobs"
				$enabled_jobs = $jobs | where {$_.IsEnabled -eq $True -and $_.HasSchedule -eq $True}
				if ($enabled_jobs -ne $null) {
					Write-Debug  "Enabled jobs=$enabled_jobs"
					$enabled_jobs_count = $enabled_jobs.Count
                    $perfData = "'Jobs'=$enabled_jobs_count "
					$total_instance_jobs += $enabled_jobs_count
					$enabled_jobs_name = $enabled_jobs | foreach {$_.Name.Split(".")[0]}
					Write-Debug "Enabled_jobs_name=$enabled_jobs_name"
					$failed_jobs = $enabled_jobs | where {$_.IsEnabled -eq $True -and $_.HasSchedule -eq $True -and $_.LastRunOutcome -eq "Failed"}
                    $missed_jobs = $enabled_jobs | Where-Object {$_.IsEnabled -eq $True -and $_.HasSchedule -eq $True -and $_.NextRunDate -lt (Get-Date) -and $_.NextRunDate -gt (Get-Date "2001-01-01")}
					if ($failed_jobs -ne $null) {
						$failed_jobs_name = $failed_jobs | foreach {$_.Name.Split(".")[0]}
						$failedJobsCount +=1
						Write-Debug "failed_jobs_name=$failed_jobs_name"
					} elseif ($missed_jobs -ne $null) {
                        $missed_jobs_name = $missed_jobs | foreach {$_.Name.Split(".")[0]}
                        $missedJobsCount +=1
                        Write-Debug "missed_jobs_name=$missed_jobs_name"
                    } else {
						Write-Debug "All Enable jobs are completed success"
					}
                    $perfData = "| 'Jobs_Enabled'=$enabled_jobs_count 'Jobs_Failed'=$failedJobsCount 'Jobs_Missed'=$missedJobsCount"
                    if ($failedJobsCount -eq 0 -and $missedJobsCount -eq 0) {
						$desc = "$instance all jobs success, jobs count=$enabled_jobs_count. "
					} elseif ($failedJobsCount -ne 0 -and $missedJobsCount -eq 0){
                        $desc = "$instance failed jobs=$failed_jobs_name. "
						$critical_desc +=$desc
						$retCode = $CRITICAL
                    } elseif ($failedJobsCount -eq 0 -and $missedJobsCount -ne 0){
                        $desc = "$instance missed jobs=$missed_jobs_name. "
						$critical_desc +=$desc
						$retCode = $CRITICAL
                    } else {
						$desc = "$instance Jobs in unknown state "
						$critical_desc +=$desc
						$retCode = $CRITICAL
					}
				}else{
					$desc = "$instance no enable jobs found. "
					$not_found_desc +=$desc
				}
						
			}catch{
				 $ExceptionType = $($_.Exception.GetType().FullName)
				 $ErrorMessage = $_.Exception.Message
				 $desc = "$instance Exception: $ErrorMessage $fullQualified. "
				 Write-Debug "Got an Exception $desc"
				 $unknown_desc += $desc
				 $failedToConnectCount+=1
			}
		}else {
			$desc = $connectDesc
			$failedToConnectCount+=1
			$unknown_desc += $desc
			
		}
		Write-Debug $desc
		$instance_status += $desc
		Write-Debug "All Instances Status=$instance_status"
	}
	
	$ALL_INSTANCES_SUMMARY += $instance_status
	if($retCode -ne  $CRITICAL) {
		Write-Debug "failedToConnectCount=$failedToConnectCount"
		if($failedToConnectCount -eq 0 ) {
			$retCode = $OK
			if ($total_instance_jobs -eq 0) {
				$instance_status = "Enable jobs not found in all instance. Total Instances=$($InstancesList.Count)"
			}else{
				$instance_status = "All jobs in all sql instances completed successfully. Total Instances=$($InstancesList.Count) Total Jobs=$total_instance_jobs"
			}
		}else{
			$instance_status = $unknown_desc
		}
	}else{
		$instance_status = "$critical_desc $unknown_desc"
	}
	$desc = "$instance_status`n$ALL_INSTANCES_SUMMARY" 
	Write-Debug  "Get-SQL-Jobs-Status return=$retCode ,output=$desc"
	return $retCode , $desc, $perfData
}

Function Get-SQL-Connection-Time ($InstancesList) {
	Write-Debug "Get-SQL-Connection-Time, InstancesList: $InstancesList"
	$retCode = $UNKNOWN
	$failedToConnectCount = 0
	$instance_status = ""
	foreach ($instance in $InstancesList) {
		$connectCode, $connectDesc ,$sqlObj ,$time2Connect  = Connect-To-SQL $instance $true
		if ($connectCode -eq $SUCCESS) {
			$perfData = "'$instance time to connect'=" + $time2Connect + "[s];$timeToConnectWarn;$timeToConnectCrit;$time2Connect;`n"
			if ($time2Connect -lt $timeToConnectWarn -and $skipCheckOk -ne $True ) {
				$retCode = $OK
			}elseif ($time2Connect -gt $timeToConnectCrit){
				$skipCheckOk = $True
			}elseif ($time2Connect -lt $timeToConnectCrit -and $time2Connect -gt $timeToConnectWarn ){
				$retCode = $WARNING
				$skipCheckOk = $True
			}
			$desc = "$instance=$time2Connect. "
		}else {
			$desc = $connectDesc
			$failedToConnectCount+=1
		}
		$instance_status += $desc
		Write-Debug "All Instances Status=$instance_status"
	}
	
	$ALL_INSTANCES_SUMMARY += $instance_status
	if($retCode -ne  $CRITICAL -and $retCode -ne $WARNING) {
		Write-Debug "failedToConnectCount=$failedToConnectCount"
		if($failedToConnectCount -eq 0 ) {
			$retCode = $OK
			$instance_status = "Time to connect for all instances are OK. Total Instances=$($InstancesList.Count)." 
		}
	}
	$desc = "$instance_status`n$ALL_INSTANCES_SUMMARY" 
	$instancePerfData += $perfData 
	$instancePerfData = "|$instancePerfData"
	Write-Debug "Get-SQL-Connection-Time return: retCode: $retCode, desc: $desc"
return $retCode,$desc,$instancePerfData
}

#Create SLQ Config ini if not exists
Function Create-SQL-Config-File () {
	if ((!(Test-PATH -Path "$SQL_CONFIG_FILE_FULL_PATH")) -or ($ForceConfigFile -eq $True)) {
$configFileText ="
#Excluded Instances with comma separated for example: AAC,WIZSOFT,BKUPEXEC,MICROSOFT##SSEE
[Instances]
Exclude=BKUPEXEC,MICROSOFT##SSEE

#Excluded DataBases with comma separated, Instances:Name for example PRI:db03,HASH,db01
[DataBases]
#Exclude=PRI:db03,HASH,db01

# tempdb size threshold, if count of tempdb files lower than 3, then warning level of database size=5000MB and critical=8000MB
# else  warning level of database size=16000MB and critical:20000MB
[TempDB Size]
TempDB Threshold Level=3,5000,8000;30,16000,20000

# Log files size threshold, if DB size is greater than 2 GB then log file warning level is 150% of DB size. and critical level is 
# 300% of DB size.
[Log File Size]
Log File Size Threshold=2000,150,300;500000,50,100
"
		
		Write-Debug "SQL config file does not exists, or ForceConfigFile=True, Going to recreate SQL config file"
		$configFileText | Out-file -FilePath $SQL_CONFIG_FILE_FULL_PATH
	}else{
		Write-Debug "SQL config file exists."
	}
}	
	
} # Close Begin

process {
	If ($PSBoundParameters['Debug']) { 	# if -Debug passed as arguments, Write-Debug without stop
		$DebugPreference = 'Continue'
		$debugMode=$true
	}
	#Return codes
	Set-Variable -Name "SUCCESS" -Value 100 -Option constant
	Set-Variable -Name "FAILED" -Value 50 -Option constant
	
	Set-Variable -Name "OK" -Value 0 -Option constant
	Set-Variable -Name "WARNING" -Value 1 -Option constant
	Set-Variable -Name "CRITICAL" -Value 2 -Option constant
	Set-Variable -Name "UNKNOWN" -Value 3 -Option constant
	
	$SERVER = $env:COMPUTERNAME
	$SQL_CONFIG_FILE_NAME = "check_mssql_config.ini"
	$SQL_CONFIG_FILE_FOLDER_NAME=".\"
	$SQL_CONFIG_FILE_FULL_PATH="$SQL_CONFIG_FILE_FOLDER_NAME\$SQL_CONFIG_FILE_NAME"
	$SQL_CONFIG_EXCLUDE_NAME="Exclude"
	$SQL_CONFIG_TEMPDB_SIZE_NAME="TempDB Size"
	$SQL_CONFIG_LOG_FILES_SIZE_NAME="Log File Size"
	$SQL_INSTANCES_SECTION="Instances"
	$SQL_DATABASE_SECTION="DataBases"
	$SQL_TEMPDB_THRESHOLD_SECTION="TempDB Threshold Level"
	$SQL_LOG_FILE_SIZE_THRESHOLD_SECTION="Log File Size Threshold"
	$ALL_INSTANCES_SUMMARY = "SQL Instance summary:`n"
	$ALL_INSTANCES_SUMMARY_IN_MB = "SQL Instance summary in MB:`n"
	$ErrorActionPreference = 'Stop'
	$retCode = $UNKNOWN
	$temp_db_default_threshold_value="3,5000,8000;30,16000,20000"
	$log_file_size_threshold_default_value="2000,150,300;500000,50,100"
	
	
	try {
		Create-SQL-Config-File  # create sql config if not exists
		$SMO = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") #load sql server module
		 Write-Debug "SMO module load successfuly" 
		 $retCode,$desc = Get-SqlInstances 					# Get all Sql Instances
		 if($retCode -eq $SUCCESS) {
			$instancesToCheck = $desc
			Switch($CheckType) {
				"DBStatus" {
					$retCode ,$desc = Get-DataBases-Status $instancesToCheck
				}
				"ConnectionTime" {
					$retCode ,$desc = Get-Sql-Connection-Time $instancesToCheck
				}
				"TempDBSize" {
					$retCode ,$desc = Get-TempDB-Size $instancesToCheck
				}
				"LogSize" {
					$retCode ,$desc = Get-LogFile-Size $instancesToCheck
				}
				"Jobs" {
					$retCode ,$desc = Get-SQL-Jobs-Status $instancesToCheck
				}
			}
		 }
		
	}catch{
		 $ExceptionType = $($_.Exception.GetType().FullName)
		 $ErrorMessage = $_.Exception.Message
		 $desc = "Exception: $ExceptionType $ErrorMessage $fullQualified"
	}
	
Write-Debug "retCode=$retCode, output=$desc"	
} # Close process

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
