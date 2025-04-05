# Script to list basic ESXi host details by user-defined Make/Model, e.g. "PowerEdge R620"
# v1.1, 01/12/2022

# Create clean directory for results
$results_folder = (Get-Date).tostring("dd-MM-yyyy-hh-mm-ss") 
$null = New-Item -ItemType Directory -Path "./" -Name $results_folder

# Get vCenter Credentials and set other Global Variables
Write-Host "`nPlease enter vCenter credentials";
$vcenter_creds = Get-Credential
$vcenter_list = (Read-Host "To which vCenter(s) would you like to connect? 
    NOTE: Multiple vCenters can be entered as a comma-separated list
    E.G.: 10.10.10.10, 10.10.10.11
    Enter your vCenter(s) now").split(",").trim()
$search_string = Read-Host("What Make/Model of ESXi are you looking for?  E.G. 'PowerEdge R620' or 'R620'")
$raw_esxi_csv = "$results_folder/raw_esxi_list.csv"
$filtered_esxi_csv = "$results_folder/$search_string" + "_filtered_esxi_list.csv"
$final_esxi_csv = "$results_folder/$search_string" + "_final_esxi.csv"
$final_vm_csv = "$results_folder/$search_string" + "_final_vm_list.csv"

# Connect to vCenter for PowerCLI Data Collection
Write-Host "Connecting to vCenter(s)..."
Connect-VIServer -server $vcenter_list -Credential $vcenter_creds -Verbose

# Get ESXi host objects for all connected vCenters
Write-Host "`nCollecting list of ESXi Hosts in all of these vCenters:
$vcenter_list ...
This may take a few minutes.  Grab some coffee.  Or whiskey.  Whatever floats your ducky."
Get-VMHost | Sort-Object Name | 
Export-CSV -Path $raw_esxi_csv -NoTypeInformation -Append
Write-Host "ESXi Host List collected."

# Remove duplicate ESXi hostnames from the CSV file
$input_raw_esxi_csv = Import-Csv $raw_esxi_csv | Sort-Object Name -Unique
$input_raw_esxi_csv | Export-CSV -Path $filtered_esxi_csv -NoTypeInformation -Append

# Get data for ESXi Hosts
Write-Host "`nCollecting data for ESXi Hosts..."
$esxi_host_list = Import-Csv $filtered_esxi_csv
foreach ($esxi_host in ($esxi_host_list).Name) {
    Write-Host "Working on ESXi $esxi_host..."
    if ((Get-VMHost -Name $esxi_host).Model -like "*$search_string*") {
        Get-VMHost -Name $esxi_host | Select-Object Name,
        @{Name = "vCenter"; Expression = { $_.extensiondata.client.ServiceUrl.Split('/')[2] } },
        @{Name = "Datacenter"; Expression = { (Get-datacenter -VMHost $_).name } },
        @{Name = "Cluster"; Expression = { $_.Parent.Name } },
        Build,
        Version,
        NumCpu,
        @{Name = "Memory Total (GB)"; Expression = { [math]::round( $_.MemoryTotalGB ) } },
        @{Name = "Model"; Expression = { (Get-EsxCli -VMHost $_.Name).hardware.platform.get().ProductName } },
        @{Name = "CPU Processor"; Expression = { $_.ProcessorType } },
        @{Name = "Physical CPU Count"; Expression = { (Get-VMHost -Name $esxi_host | Get-View).hardware.cpuinfo.numcpucores } },
        @{Name = "Logical CPU Count"; Expression = { (Get-VMHost -Name $esxi_host | Get-View).hardware.cpuinfo.numcputhreads } },
        @{Name = "Serial"; Expression = { (Get-EsxCli -VMHost $_.Name).hardware.platform.get().SerialNumber } },
        ConnectionState |
        Export-Csv -Path $final_esxi_csv -NoTypeInformation -Append
    }
}

# Get a List of VMs for each ESXi host
Write-Host "`nCollecting data for VMs..."
$esxi_list_full = Import-Csv -Path $final_esxi_csv
foreach ($esxi_host in ($esxi_list_full).Name) {
    $vm_list = (Get-VMhost -Name $esxi_host | Get-VM).Name | Sort-Object
    foreach ($vm in $vm_list) {
        Write-Host "Working on VM $vm..."
        Get-VM -Name $vm | Select-Object Name, 
        @{Name = "FQDN"; Expression = { $_.ExtensionData.Guest.IPStack[0].DnsConfig.HostName, $_.ExtensionData.Guest.IPStack[0].DnsConfig.DomainName -join '.' } }, 
        @{Name = "IP Address"; Expression = { @($_.guest.IPAddress[0]) } },
        @{Name = "Guest OS"; Expression = { $_.Guest.OSFullName } }, 
        @{Name = "CPU Count"; Expression = { $_.NumCpu } },
        @{Name = "Guest Memory (GB)"; Expression = { $_.MemoryGB } },  
        @{Name = "Datastore"; E = { [string]::Join(',', (Get-Datastore -Id $_.DatastoreIdList | Select-Object -ExpandProperty Name)) } },
        @{Name = "Disk Provisioned (GB)"; Expression = { [math]::round($_.ProvisionedSpaceGB) } },
        @{Name = "vCenter Folder"; Expression = { $_.Folder.Name } }, 
        @{Name = "vCenter Cluster"; Expression = { $_.VMHost.Parent } },
        @{Name = "VLANs"; Expression = { (Get-NetworkAdapter -VM $vm).NetworkName -join ', ' } },
        @{Name = "ESXi Host"; Expression = { $_.VMHost } },
        @{Name = "VM Power State"; Expression = { $_.PowerState } } | 
        Export-CSV -Path $final_vm_csv -NoTypeInformation -Append
    }
}

# Disconnect vCenter Session(s)
Write-Host "Disconnecting from vCenters..."
Disconnect-VIServer * -Confirm:$false

# Create .zip of resultant data for convenience
Compress-Archive -Path ./$results_folder/*final*.csv -DestinationPath "$results_folder.zip"

# Cleaning Powershell history
clear-history
Write-Output ' ' > (Get-PSReadLineOption).HistorySavePath

# Finish
Write-Host "`n
---------------------------------------------------------------------
Your resultant data is stored in the ./$results_folder directory.
A summary .zip file of final data is located at ./$results_folder.zip
---------------------------------------------------------------------
############################## fin ##################################"