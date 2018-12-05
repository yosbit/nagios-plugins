[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)
## Description:
Script for nagios to check SQL DataBases, Connection Time, Jobs, TempDB Size, Log Size.
The script get all sql instances in the server, and return status for eache instance
You can use check_mssql_config.ini to exclude DB or instance to check, read check_mssql_config.ini help.

## Auther:
  Yossi Bitton yosbit@gmail.com
  Date: November 2018 
  Version 1.1.2

### PARAMETER DBStatus
Get the database status, return critical if one DB not in normal state.

### PARAMETER ConnectionTime
Get the time to connect to DB, include performance data.

### PARAMETER Jobs
Get the status off all jobs, the script check only Enabled and scheduled jobs.

### PARAMETER TempDBSize
Get the size of temp DB.
see values of warning and critical in check_mssql_config.ini config.
needs dbowner permissions for user Service Account.

### PARAMETER LogSize
Get the size of Log file for eache DB.
see values of warning and critical in check_mssql_config.ini config.
needs dbowner permissions for user Service Account.

### EXAMPLE
   ./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'DBStatus'
   ./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'ConnectionTime'
   ./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'Jobs'
   ./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'TempDBSize'
   ./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'LogSize'
  
   ## Instalation
   ### NSClient with NSC.ini config file (old version)
    Edit NRPE config:
    Edit NSC.ini or nsclient.ini and add the following line under section:
    [Wrapped Scripts]
    check_mssql=check_mssql.ps1 $ARG1$
    [Script Wrappings]
    ps1 = cmd /c echo scripts\%SCRIPT%%ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command - 
	
   ### NSClient with nsclient.ini config file (new version)
    add the followings lines under:
    [/settings/external scripts/scripts]
    check_mssql = cmd /c echo scripts\check_mssql.ps1 $ARG1$ ; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass  -command -
## [Download - check_mssql.ps1](https://github.com/yosbit/nagios-plugins/blob/master/check_mssql.ps1)
[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)
