# Description: Script to list basic ESXi host details by user-defined .txt list of ESXi Names
# Version: v1.0, 03/10/2022

# Create directory for results
$results_folder = (Get-Date).tostring("dd-MM-yyyy-hh-mm-ss") 
$null = New-Item -ItemType Directory -Path "./" -Name $results_folder

# Get vCenter Credentials and set other Global Variables
Write-Host "Please enter vCenter credentials";
$vcenter_creds = Get-Credential
$vcenter_list = (Read-Host "To which vCenter(s) would you like to connect? 
    NOTE: Multiple vCenters can be entered as a comma-separated list
    E.G.: 10.10.10.10, 10.10.10.11
    Enter your vCenter(s) now").split(",").trim()
$result_string = Read-Host("Enter a unique descriptor for your resultant file")
$raw_esxi_csv = "$results_folder/$result_string" + "_raw_esxi_list.csv"

#Connect to vCenter of choice:
Write-Host "Now Connecting to vCenters $vcenter_list..."
Connect-VIServer -server $vcenter_list -Credential $vcenter_creds -Verbose

# Choose if you would like to run for all ESXis on connected vCenters, or ESXi in a pre-defined .txt list
$host_selector = Read-Host "Would you like to collect data for all ESXi, or ESXi listed in a .txt file?
Valid responses are 'all' or 'file'"

switch ($host_selector) {
    all {
        $esxi_host_list = (Get-VMhost).Name | Sort-Object
    }
    file {
        $host_list_file = Read-Host("Enter the .txt file path for the list of ESXi hosts you are working on")
        $esxi_host_list = Get-Content -Path $host_list_file
    }
}

foreach ($esxi_host in $esxi_host_list) {
    $socket_count = (Get-View(Get-VMHost -Name $esxi_host)).Hardware.CpuInfo.NumCpuPackages
    $cpu_total_core_count = (Get-View(Get-VMHost -Name $esxi_host)).Hardware.CpuInfo.NumCpuCores
    $cores_per_socket = $cpu_total_core_count / $socket_count
    $license_key_value = (Get-VMhost -Name $esxi_host | Select-Object -Property LicenseKey).LicenseKey
    $mem_total = [math]::Round((Get-VMHost -Name $esxi_host).MemoryTotalGB)
    $parent_vcenter = (Get-VMHost -Name $esxi_host).Uid.Split('@')[1].Split(':')[0]
    $parent_cluster = (Get-VMHost -Name $esxi_host | Get-Cluster).Name
    Write-Host "Gathering ESXi data for $esxi_host..."
    Get-VMHost -Name $esxi_host | Select-Object Name,
    @{N = 'vCenter'; E = { $parent_vcenter } },
    @{N = 'Parent Cluster'; E = { $parent_cluster } },
    @{N = 'Number of Sockets'; E = { $socket_count } },
    @{N = 'Cores Per Socket'; E = { $cores_per_socket } },
    @{N = 'Logical Processors'; E = { ($socket_count) * ($cpu_total_core_count) } },
    @{N = 'Memory Total (GB)'; E = { $mem_total } },
    @{N = 'License Key'; E = { $license_key_value } },
    ConnectionState |
    Export-Csv -Path $raw_esxi_csv -NoTypeInformation -Append
}

# Disconnect from vCenter
Write-Host "Disconnecting vCenter $vcenter..."
Disconnect-VIServer -Server $vcenter_list -Confirm:$false

# Removing duplicate ESXi host names from the CSV file
Write-Host "Removing Duplicate Entries, if any...."
$input_raw_esxi_csv = Import-Csv $raw_esxi_csv | Sort-Object Name -Unique
$final_esxi_csv = "$results_folder/$result_string" + "_final_esxi_list.csv"
$input_raw_esxi_csv | Export-CSV -Path $final_esxi_csv -NoTypeInformation

Write-Host "

---------------------------------------------------------------------
Your resultant data is stored at $final_esxi_csv
---------------------------------------------------------------------
############################## fin ##################################"