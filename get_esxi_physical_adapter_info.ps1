# Script to iterate through ESXi servers and extract physical network adapter switch information.
# 2022.07.26 - James Phillips 

# Get Creds and Connect to vCenter
Write-host "Please enter vCenter credentials"
$vis_creds = Get-Credential
$vcenter = (Read-Host "To which vCenter(s) would you like to connect? 
NOTE: Multiple vCenters can be entered as a comma-separated list
E.G.: vcenter-01.example-domain.com, 10.10.10.102
Enter your vCenter(s) now").split(",").trim()

# Connect to vCenter(s)
Write-Host "Connecting to vCenter " $vcenter
Connect-VIServer -server $vcenter -Credential $vis_creds -Verbose

# Print to stdout or to a file?
$output_type = Read-Host "Would you like to print results to terminal, or to a file?
Valid responses are 'terminal' or 'file' "

# Define ESXi(s) to modify
$esxi_source_type = Read-Host "Are you modifying the ESXis of an entire cluster, or a custom list?
Valid responses are 'cluster' or 'custom' "
if ($esxi_source_type -eq 'custom') {
    $esxi_list_location = Read-Host "Please enter the location of .txt file containing a list of the ESXi FQDNs which you'd like to modify.  For example, enter 'C:\Path_to_file\servers.txt' "
    $esxihosts = Get-Content $esxi_list_location
} elseif ($esxi_source_type -eq 'cluster') {
    $esxi_cluster_name = Read-Host "Please enter the vCenter Cluster in which you would like to work "
    $esxihosts = (Get-Cluster -Name $esxi_cluster_name | Get-VMhost).Name | Sort-Object
} else {
    Write-Host "Your input does not compute.  Please try again."
}

# Define function
function get_vmnic_info {
    foreach ($esxi in $esxihosts) {
        Write-Host "Working on $esxi ..."
        $esxihost_info = Get-VMhost -Name $esxi
        $network_system = Get-View $esxihost_info.ExtensionData.ConfigManager.NetworkSystem
    
        foreach ($Pnic in $esxihost_info.ExtensionData.Config.Network.Pnic) {
            $PnicInfo = $network_system.QueryNetworkHint($Pnic.Device)
            [PSCustomObject] @{
                'ESXi' = $esxi
                'Device' = $Pnic.Device
                'DevId' = $PnicInfo.ConnectedSwitchPort.DevId
                'PortId' = $PnicInfo.ConnectedSwitchPort.PortId
            }
        }
    }
}

# Execution
switch ($output_type) {
    terminal {
        get_vmnic_info
    }
    file {
        $file_type = Read-Host "Save as CSV or other file type? Valid responses are 'csv' or 'other' "
        if ($file_type -eq 'other') {
            $file_loc = Read-Host "Enter the local location where you would like to save output.
            For example, 'G:\documents\output.txt' "
            get_vmnic_info >> $file_loc
        } elseif ($file_type -eq 'csv') {
            $file_loc = Read-Host "Enter the local location where you would like to save output.
            For example, 'G:\documents\output.csv' "
            $csv_data = get_vmnic_info
            $csv_data | Export-Csv -Path $file_loc -NoTypeInformation -Append -Force
        } else {
            Write-Host "Your input does not compute.  Please try again."
        }
    }
}
