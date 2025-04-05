# Description: Script to check for unused VIB (VMware Import Bundle) from ESXi host which will block ESXi upgrade from v6.7 to v7.0U2a
# Version: v1.0, 2021.05.12
# Author: James Phillips

Write-Host "`n`n
#############################################################
This Script uses Posh-SSH on Powershell.  If you need to install Posh-SSH, execute the command below:
Install-Module -Name Posh-SSH
Currently works best on Powershell 5, not Powershell 6/7
#############################################################"

# Global Variables
$vis_credentials = Get-Credential
$vcenter = Read-Host "Please provide IP Address or FQDN of desired vCenter: "
$host_cluster = Read-Host "Please provide name of vCenter Cluster containing hosts to be modified: "

Write-Host "Connecting to vCenter " $vcenter
Connect-VIServer -Server $vcenter -Credential $vis_credentials | out-null

$esxihosts = (Get-Cluster -Name $host_cluster | Get-VMhost).Name | Sort-Object

# Create temporary file for ESXi password
Read-Host "Enter ESXi root password: " -AsSecureString | ConvertFrom-SecureString | Out-File ./pw_temp.txt

foreach ($esxihost in $esxihosts) {
    # Start SSH
    Get-VMHost -Name $esxihost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } | Start-VMHostService | out-null
    
    # Create SSH Variables
    $pw_file = "./pw_temp.txt"
    $secpasswd = Get-Content -Path $pw_file | ConvertTo-SecureString
    $test_scsidevs_cmd = 'esxcfg-scsidevs -a | grep -i "dell-configuration-vib\|dellemc-osname-idrac\|net-qlge\|qedf\|qedi\|qfle3f"'
    $test_nic_list_cmd = 'esxcli network nic list | grep -i "dell-configuration-vib\|dellemc-osname-idrac\|net-qlge\|qedf\|qedi\|qfle3f"'
    $credentials = new-object System.Management.Automation.PSCredential("root", $secpasswd)

    # Create SSH Sessions
    $ssh_session = New-SSHSession -ComputerName $esxihost -Credential $credentials
    $ssh_session_id = $ssh_session.SessionId

    # Check VIBs exist -- if there is no output, then the VIBs are unused on the system and can be removed
    Write-Host "Results for: " $esxihost
    (Invoke-SSHCommand -SessionId $ssh_session_id -command $test_scsidevs_cmd).Output
    (Invoke-SSHCommand -SessionId $ssh_session_id -command $test_nic_list_cmd).Output
    write-host `n

    # Disconnect SSH Session
    Remove-SSHSession -SessionId $ssh_session_id | out-null
    
    # Stop SSH
    Get-VMHost -Name $esxihost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } | Stop-VMHostService -confirm:$false | out-null
}

# Remove temporary pw file
rm -Force ./pw_temp.txt

Write-Host "Disconnecting vCenter"
Disconnect-VIServer -Server $vcenter -Confirm:$false
Write-Host "######################## fin ########################"