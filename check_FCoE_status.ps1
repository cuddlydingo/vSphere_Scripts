# Get Creds and Connect to vCenter
Write-host "Please enter vCenter credentials"
$creds = Get-Credential
$vcenter = (Read-Host "To which vCenter(s) would you like to connect? 
NOTE: Multiple vCenters can be entered as a comma-separated list
E.G.: vcenter-01.example-domain.com, 10.10.10.10
Enter your vCenter(s) now").split(",").trim()
Connect-VIServer -server $vcenter -Credential $creds -Verbose

# Print to stdout or to a file?
$output_type = Read-Host "Would you like to print results to terminal, or to a file?
Valid responses are 'terminal' or 'file'"

# Run for all vCenter Clusters, or specified Clusters?
$cluster_names = Read-Host "Would you like to run script for all Clusters,
or a custom list of clusters?
Valid responses are 'all' or 'custom'"
switch ($cluster_names) {
    all {
        $cluster_list = (Get-Cluster).Name | Sort-Object
    }
    custom {
        $cluster_list = (Read-Host "Enter vCenter Cluster Names now, as a comma-separated list
    e.g.) DC_Cluster01, Staging, DC_Cluster02").split(",").trim()
    }
}

# Define Function to get qflef3 status for selected vCenter Cluster(s)
function get_qfle3f_status {
    foreach ($cluster in $cluster_list) {
        $esxis = Get-VMHost -Location $cluster | Where-Object { $_.ConnectionState -eq "Connected" } | Sort-Object Name
        Write-Output "ESXi Hosts of Cluster $cluster"
        $esxi_table = foreach ($esx in $esxis) {
            $esxcli = Get-EsxCli -VMHost $esx -V2
            $esxcli.system.module.list.Invoke() | Where-Object { $_.Name -match "qfle3f" } | Select-Object @{N = 'VMHost'; E = { $esxcli.VMHost.Name } }, Name, IsLoaded, IsEnabled
        }
        Write-Output $esxi_table | Format-Table
        Write-Host `n
    }
    $disconnected_esxis = Get-VMHost | Where-Object { $_.ConnectionState -ne "Connected" } | Sort-Object Name
    Write-Output "The following ESXis are in a Disconnected state:
    $disconnected_esxis"
}

# Execute function based on user-defined output choice
switch ($output_type) {
    terminal {
        get_qfle3f_status
    }
    file {
        $destination_path = Read-Host "Enter a .txt file destination for the output"
        get_qfle3f_status > $destination_path
    }
}

# Disconnect Sessions
Disconnect-VIServer * -Force -Confirm:$false