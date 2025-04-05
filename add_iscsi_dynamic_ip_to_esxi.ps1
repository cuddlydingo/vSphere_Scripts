# v1.0
# January 9, 2024
# This script adds Dynamic Discovery IP Addresses to all ESXi in a user-defined set of vCenter(s), for an existing iSCSI Storage Software Adapter

# Define functions
function proceed_question {
    $proceed = Read-Host "`nWould you like to proceed? Valid responses are 'yes' or 'no' ..."
    if ($proceed -eq "yes") {
        continue
    } else {
        Disconnect-VIServer * -Confirm:$false
        exit
    }
}

# Get vCenter Credentials and set other Global Variables
Write-Host "`nPlease enter vCenter credentials";
$vcenter_creds = Get-Credential
$vcenter_list = (Read-Host "To which vCenter(s) would you like to connect? 
    NOTE: Multiple vCenters can be entered as a comma-separated list
    E.G.: 10.0.0.1, 10.0.0.2
    Enter your vCenter(s) now").split(",").trim()

# Connect to vCenter for PowerCLI Data Collection
Write-Host "Connecting to vCenter(s)..."
Connect-VIServer -server $vcenter_list -Credential $vcenter_creds -Verbose

# Ask user for iSCSI Software Adapter Name and Dynamic Discovery IP/Port Values
$adapter_name = Read-Host "What is the iSCSI Software Adapter name?"
$iScsiTargetIp = Read-Host "What is the Dynamic Discovery IP Address for your Storage Device?"
$iScsiTargetPort = Read-Host "What is the Dynamic Discovery Port? `nPlease enter only the numeric port value, e.g. '1234' not 'Port 1234'"

# Get and Confirm ESXi's to work on
$esxi_choice = Read-Host "Would you like to apply the change to all ESXi in the connected vCenter(s), or a specific list of ESXi machines?
Valid responses are 'all' or 'list' ..."
switch ($esxi_choice){
    all {
        $script:esxi_list = (Get-VMHost).Name | Sort-Object
        Write-Host "You are about to add Dynamic Discovery IP $iScsiTargetIp on Port $iScsiTargetPort to the following ESXi machines:"
        $display_command = foreach ($esxi in $esxi_list) {
            (Get-View -Id (Get-VMHost -Name $esxi).ExtensionData.ConfigManager.StorageSystem).StorageDeviceInfo.HostBusAdapter.where{$_ -is [VMware.Vim.HostInternetScsiHba]} |
            Select-Object @{N='ESXi Server';E={$esxi}},@{N='vCenter';E={(Get-vmhost -Name $esxi | get-view).summary.managementserverip}},Device,iScsiName
        }
        $display_command | Format-Table -AutoSize
        proceed_question
    }
    list {
        $esxi_list_path = Read-Host "Enter the path/location of the .txt file containing a list of the ESXi names you would like to modify, e.g. /tmp/esxihost.txt "
        $script:esxi_list = Get-Content -Path $esxi_list_path
        Write-Host "You are about to add Dynamic Discovery IP $iScsiTargetIp on Port $iScsiTargetPort to the following ESXi machines:"
        $display_command = foreach ($esxi in $esxi_list) {
            (Get-View -Id (Get-VMHost -Name $esxi).ExtensionData.ConfigManager.StorageSystem).StorageDeviceInfo.HostBusAdapter.where{$_ -is [VMware.Vim.HostInternetScsiHba]} |
            Select-Object @{N='ESXi Server';E={$esxi}},@{N='vCenter';E={(Get-vmhost -Name $esxi | get-view).summary.managementserverip}},Device,iScsiName
        }
        $display_command | Format-Table -AutoSize
        proceed_question
    }
}

# Add Dynamic Discovery IP/Port to each ESXi ISCSi Adapter
foreach ($esxi in $esxi_list) {
    Write-Host "Working on ESXi $esxi ..."
    $esxcli = Get-VMHost -Name $esxi | Get-EsxCli -V2
    $iScsiHBA = Get-VMHost -Name $esxi | Get-VMHostHba -Type IScsi -Device $adapter_name
    $iScsiHBA | New-IScsiHbaTarget -Address $iScsiTargetIp -Port $iScsiTargetPort
    Get-VMHost -Name $esxi | Get-VMHostStorage -RescanAllHba -RescanVmfs
}

# Disconnect vCenter Session(s)
Write-Host "Disconnecting from vCenters..."
Disconnect-VIServer * -Confirm:$false