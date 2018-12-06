[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)
## Description:
Script for nagios to check time against NTP servers, then automaticly correct the time and date, if offset is abouve or bellow
threshold levels.
You can add multi NTP servers with comma separated

## Auther:
Yossi Bitton yosbit@gmail.com
Date: November 2018
Version 1.1.3

### PARAMETER NTPServers
    NTP server IP or DNS name.
	for more than one NTP server, use: ntp_server_ip1,ntp_server_ip2
	
### PARAMETER secondsDiffWarn - Alias -W
	If offset is bellow or above from secondsDiffWarn in seconds, the script try to fix the time, if fix is failed exit with WARNING.
	
### PARAMETER secondsDiffWarn Alias -C
	If offset is bellow or above from secondsDiffCrit in seconds, the script try to fix the time, if fix is failed exit with CRITICAL.
	
### EXAMPLE
	.\check_time.ps1  -NTPServers 192.168.1.1 -W 5 -C 15
	.\check_time.ps1  -NTPServers 192.168.1.1,192.168.10.100 -W 5 -C 15
	.\check_time.ps1  -NTPServers 192.168.1.1,192.168.10.100 -W 5 -C 15 -Debug	
	.\check_time.ps1  ( Works with default params)  

## Instalation
### NSClient with NSC.ini config file (old version)
     Edit NRPE config:
     Edit NSC.ini or nsclient.ini and add the following line under section:
     [Wrapped Scripts]
     check_time=check_time.ps1 $ARG1$
     [Script Wrappings]
     ps1 = cmd /c echo scripts\%SCRIPT%%ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command - 
	
### NSClient with nsclient.ini config file (new version)
     add the followings lines under:
     [/settings/external scripts/scripts]
     check_time = cmd /c echo scripts\check_time.ps1 $ARG1$ ; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass  -command -
## [Download - check_time.ps1](https://github.com/yosbit/nagios-plugins/releases/download/1.1.2/check_time.ps1)
[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)
