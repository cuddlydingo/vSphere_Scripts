# Script to Create and remove VMware VM Snapshots
# James Phillips, 2023-12-19
# v1.05 - Added logic to exclude Infra and vCLS VMs

# Set Error Action to Silently Continue
$PrevErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'silentlycontinue'

# Connect to vCenter using saved, encrypted credentials.  Please update this section accordingly for other vCenters.
$creds = Import-Clixml -Path /home/user/location_sspolicy_fix/location.cred
Connect-VIServer -Server 10.10.10.10 -Credential $creds

# Remove any old 'JPL' Snapshots, but preserve any other snapshots not created by this script
foreach ($vm in ((Get-VM | Where-Object {($_.Name -notlike "infra*" -and $_.Name -notlike "vCLS*")}).Name | Sort-Object)) {
    Get-VM -Name $vm | Get-Snapshot -Name "JPL_*" | Remove-Snapshot -Confirm:$false
    Start-Sleep -Seconds 2
}

# Consolidate Virtual Disks, where needed
$VM_Consolidation_List = Get-VM | Where-Object {$_.ExtensionData.Runtime.ConsolidationNeeded}
foreach ($vm in $VM_Consolidation_List) {
    (Get-VM $vm).ExtensionData.ConsolidateVMDisks()
    Start-Sleep -Seconds 2
}

# Create new VM Snapshots and name them all "JPL_<date>"
foreach ($vm in ((Get-VM | Where-Object {($_.Name -notlike "infra*" -and $_.Name -notlike "vCLS*")}).Name | Sort-Object)) {
    $date = date
    Get-VM $vm | New-Snapshot -Name "JPL_$date"
    Start-Sleep -Seconds 5
}

# Return Error Action Value to Previous Value
$ErrorActionPreference = $PrevErrorActionPreference

# Disconnect vCenter Session(s)
Write-Host "Disconnecting from vCenters..."
Disconnect-VIServer * -Confirm:$false