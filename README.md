# Nagios Plugins

# Getting Started
    # Nagios plugins for monitoring Windows system.
 
# Monitor:
  # Windows system
			Disks
			Files
			NTP
			Windows Services			
  # Exchange
			Automatic detect exchange version and monitor:
				Exchange Databases
				Queue
						
  # MS SQL Servers
			Database 
			Jobs
			Connection Time
			Temp DB size
			Log file size
			
  # Internet Information Services (IIS)
			Application Pool
			Web Sites

# Prerequisites 
	NSClient version 3.09 or later.
	
# Instalation
	# for nsclient old version - EDIT NSC.ini
		Edit NRPE config:
		Edit NSC.ini or nsclient.ini and add the following line under section:
			[Wrapped Scripts]
			check_name=check_name.ps1 $ARG1$

			[Script Wrappings]
			ps1 = cmd /c echo scripts\%SCRIPT%%ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command - 
	
	# For latest nslient edit nsclient.ini
		add the followings lines under:
		[/settings/external scripts/scripts]
		check_name = cmd /c echo scripts\check_name.ps1 $ARG1$ ; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass 			-command -



