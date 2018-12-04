[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)

# Nagios Plugins for Monitoring Windows system using NSClient.

  ## Windows system
  - Disks
  - Files
  - NTP
  - Windows Services			
  
  ## Exchange
  - Exchange Databases
  - Queue				
  
  ## MS SQL Servers
  - Database 
  - Jobs
  - Connection Time
  - Temp DB size
  - Log file size
			
  ## Internet Information Services (IIS)
  - Application Pool
  - Web Sites

# Prerequisites 
  - NSClient version 3.09 or later.
  - Power Shell
	
# Instalation
   ## NSClient with NSC.ini config file (old version)
    Edit NRPE config:
    Edit NSC.ini or nsclient.ini and add the following line under section:
    [Wrapped Scripts]
    check_name=check_name.ps1 $ARG1$
    [Script Wrappings]
    ps1 = cmd /c echo scripts\%SCRIPT%%ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command - 
	
   ## NSClient with nsclient.ini config file (new version)
    add the followings lines under:
    [/settings/external scripts/scripts]
    check_name = cmd /c echo scripts\check_name.ps1 $ARG1$ ; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass  -command -
     
[![Donate](https://www.paypalobjects.com/en_US/IL/i/btn/btn_donateCC_LG.gif)](https://paypal.me/yosbit)


