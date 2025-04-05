# v1.0
# January 8, 2024
# This script retrieves existing ISCSi Software Adapter information for all ESXi Hosts in the defined vCenter

# Get vCenter Credentials and set other Global Variables
Write-Host "`nPlease enter vCenter credentials";
$vcenter_creds = Get-Credential
$vcenter_list = (Read-Host "To which vCenter(s) would you like to connect? 
    NOTE: Multiple vCenters can be entered as a comma-separated list
    E.G.: 10.10.10.10, 10.10.10.11
    Enter your vCenter(s) now").split(",").trim()

# Connect to vCenter for PowerCLI Data Collection
Write-Host "Connecting to vCenter(s)..."
Connect-VIServer -server $vcenter_list -Credential $vcenter_creds -Verbose

# Get location of ESXi's to be researched
$esxi_location = (Read-Host "`n`nFor which vCenter(s) would you like to collect ESXi Storage Adapter information? 
NOTE: Multiple vCenters can be entered as a comma-separated list
E.G.: 10.10.10.10, 10.10.10.11
Enter your vCenter(s) now").split(",").trim()

# Define list of ESXi's in desired vCenter(s)
$esxi_list = (Get-VMHost -Server $esxi_location | sort-object Name).Name

$output_type = Read-Host "Would you like results printed to terminal or saved to CSV file?  Valid responses are 'terminal' or 'csv' ..."

switch ($output_type) {
    terminal {
        $terminal_command = foreach ($esxi in $esxi_list) {
            (Get-View -Id (Get-VMHost -Name $esxi).ExtensionData.ConfigManager.StorageSystem).StorageDeviceInfo.HostBusAdapter.where{$_ -is [VMware.Vim.HostInternetScsiHba]} |
            Select-Object @{N='VMHost';E={$esxi}},@{N='vCenter';E={(Get-vmhost -Name $esxi | get-view).summary.managementserverip}},Device,iScsiName
        }
        $terminal_command | Format-Table -AutoSize
    }
    csv {
        $csv_path = Read-Host "Enter a filepath location to save the .csv file.  Example: './result_file.csv' ..."
        $csv_command = foreach ($esxi in $esxi_list) {
            (Get-View -Id (Get-VMHost -Name $esxi).ExtensionData.ConfigManager.StorageSystem).StorageDeviceInfo.HostBusAdapter.where{$_ -is [VMware.Vim.HostInternetScsiHba]} |
            Select-Object @{N='VMHost';E={$esxi}},@{N='vCenter';E={(Get-vmhost -Name $esxi | get-view).summary.managementserverip}},Device,iScsiName
        }
        $csv_command | Export-CSV -Path $csv_path -Append -NoTypeInformation
        Write-Host "Your file is saved at $csv_path"
    }
}

# Disconnect vCenter Session(s)
Write-Host "Disconnecting from vCenters..."
Disconnect-VIServer * -Confirm:$false

Write-Host "
##############################
###########  FIN  ############
##############################"