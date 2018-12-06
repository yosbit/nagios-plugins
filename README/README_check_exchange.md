[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)
## Description:
Plugin for nagios to check Exchange Server 2007,2010,2013,2016.
can check if all Exchange Databases are mounted, and Exchange Queue.

## Auther:
Yossi Bitton yosbit@gmail.com
Date: November 2018
Version 1.1.0

### PARAMETER CheckType
		"DBStatus" - Check all exchange databases if mounted or not, return Critical if one database is not mounted.
		"Queue"    - Check all queue in exchange server if empty or not. if queue items greater than Warn or Crit.
### PARAMETER ExchangeVer (Optional)
		"2007" , "2010", "2013" ,"2016" - not needed, the plugin automaticly get the exchange version, and load the relevant PS-Module.
### PARAMETER Warn
		integer - Used for test Queue, set the number of items in queue.
### PARAMETER Crit
		integer - Used for test Queue, set the number of items in queue.
### PARAMETER Debug
		Debug Mode.
		
### EXAMPLE
	Check all exchange db status:
	.\check_exchange.ps1 -CheckType DBStatus 
	.\check_exchange.ps1 DBStatus
	
	Check exchange queue 
	.\check_exchange.ps1 -CheckType Queue -Warn 10 -Crit 50
	this command also works, using args position:
	.\check_exchange.ps1  Queue 10 50 
	
	## Instalation
### NSClient with NSC.ini config file (old version)
     Edit NRPE config:
     Edit NSC.ini or nsclient.ini and add the following line under section:
     [Wrapped Scripts]
     check_exchange=check_exchange.ps1 $ARG1$
     [Script Wrappings]
     ps1 = cmd /c echo scripts\%SCRIPT%%ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command - 
	
### NSClient with nsclient.ini config file (new version)
     add the followings lines under:
     [/settings/external scripts/scripts]
     check_exchange = cmd /c echo scripts\check_exchange.ps1 $ARG1$ ; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass  -command -
## [Download - check_exchange.ps1](https://github.com/yosbit/nagios-plugins/releases/download/1.1.2/check_exchange.ps1)
[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)
