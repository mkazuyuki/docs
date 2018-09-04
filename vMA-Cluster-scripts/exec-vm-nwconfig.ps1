# This powershell scpript aims to change IP configuration of a Windows VM on ESXi from outside.

# Assumption: 
# case.1 vMA Cluster issues clprexec command to a Windows VM where ECX SSS and vSphere PowerCLI are installed.
# case.2 Windows ECX Cluster where vSphere CLI and vSphere PowerCLI are installed
# case.3 Linux ECX Cluster   where vSphere CLI and vSphere PowerCLI are installed

# Validation info:
# Powershell execution env : Windows Server 2016 Standard
# Target VM                : Windows Server 2012 R2 Standard

# Parameters
####
$ESXIP		= "172.31.255.3"	# ESXi IP address
$ESXID		= "root"		# ESXi login ID
$ESXPW		= "NEC123nec!"		# ESXi login Password

$Guest		= "ws2012r2"		# VM's name in the ESXi inventory
$GuestUser	= "administrator"	# VM's admin account for changing NW configuration
$GuestPass	= "NEC123nec!"		# VM's admin password

$DV		= "Ethernet0"		# The name in the "Network Connections" whose setting to be changed
$IP		= "192.168.137.100"	# The VM's IP address to be set
$NM		= "255.255.255.0"	# The VM's net mask   to be set
$GW		= "192.168.137.1"	# The VM's gateway address to be set
####

$Script	= "c:\windows\system32\netsh.exe interface ip set address `"$DV`" static $IP $NM $GW"
# Write-Output $Script

Connect-VIServer -Server $ESXIP -User $ESXID -Password $ESXPW
$VM = Get-VM ( $Guest )
Invoke-VMScript -VM $VM -GuestUser $GuestUser -GuestPassword $GuestPass -ScriptText $Script 
Disconnect-VIServer -Server $ESXIP -Confirm:$False
