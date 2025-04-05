# Script to list basic ESXi host details and IPv4 Addresses of VMKernel adapters
# v1.0, 03/22/2023

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
$search_string_esximodel = Read-Host("What Make/Model of ESXi are you looking for?  E.G. 'PowerEdge R620' or 'R620'")
$job_name = Read-Host("Create a memorable name for your resultant data file")
$raw_esxi_csv = "$results_folder/$job_name" + "_raw_result_list.csv"

# For each vCenter, get data for each ESXi host that matches searchstring
foreach ($vcenter in $vcenter_list) {
    Write-Host "`nWorking on vCenter $vcenter ..."
    Connect-VIServer -server $vcenter -Credential $vcenter_creds -Verbose
    Write-Host "`nGathering ESXi data..."
    $esxi_host_list = (Get-VMHost | Where-Object {$_.Model -like "*$search_string_esximodel*"}).Name | Sort-Object
    $esxi_output = foreach($esxi_host in $esxi_host_list) {
        Write-Host -NoNewLine "."
        $vmk_data = Get-VMHostNetworkAdapter -VMHost $esxi_host
        Get-VMHost -Name $esxi_host | Select-Object Name,
            @{N='vCenter';E={$vcenter}},
            Parent,
            Model,
            Build,
            Version,
            NumCpu,
            @{N="Memory Total (GB)";E={[math]::round( $_.MemoryTotalGB )}},
            ConnectionState, 
            @{N="vmk0 Name";E={($vmk_data | Where-Object {$_.Name -like 'vmk0'}).Name}},
            @{N="vmk0 IP";E={($vmk_data | Where-Object {$_.Name -like 'vmk0'}).IP}},
            @{N="vmk0 SubnetMask";E={($vmk_data | Where-Object {$_.Name -like 'vmk0'}).SubnetMask}},
            @{N="vmk0 MAC";E={($vmk_data | Where-Object {$_.Name -like 'vmk0'}).Mac}},
            @{N="vmk1 Name";E={($vmk_data | Where-Object {$_.Name -like 'vmk1'}).Name}},
            @{N="vmk1 IP";E={($vmk_data | Where-Object {$_.Name -like 'vmk1'}).IP}},
            @{N="vmk1 SubnetMask";E={($vmk_data | Where-Object {$_.Name -like 'vmk1'}).SubnetMask}},
            @{N="vmk1 MAC";E={($vmk_data | Where-Object {$_.Name -like 'vmk1'}).Mac}},
            @{N="vmk2 Name";E={($vmk_data | Where-Object {$_.Name -like 'vmk2'}).Name}},
            @{N="vmk2 IP";E={($vmk_data | Where-Object {$_.Name -like 'vmk2'}).IP}},
            @{N="vmk2 SubnetMask";E={($vmk_data | Where-Object {$_.Name -like 'vmk2'}).SubnetMask}},
            @{N="vmk2 MAC";E={($vmk_data | Where-Object {$_.Name -like 'vmk2'}).Mac}},
            @{N="vmk3 Name";E={($vmk_data | Where-Object {$_.Name -like 'vmk3'}).Name}},
            @{N="vmk3 IP";E={($vmk_data | Where-Object {$_.Name -like 'vmk3'}).IP}},
            @{N="vmk3 SubnetMask";E={($vmk_data | Where-Object {$_.Name -like 'vmk3'}).SubnetMask}},
            @{N="vmk3 MAC";E={($vmk_data | Where-Object {$_.Name -like 'vmk3'}).Mac}}
    }
    $esxi_output | Export-Csv -Path $raw_esxi_csv -NoTypeInformation -Append
    Write-Host "`nDisconnecting vCenter $vcenter..."
    Disconnect-VIServer -Server $vcenter -Confirm:$false
}

# Removing duplicate ESXi host names from the CSV file
$input_raw_esxi_csv = Import-Csv $raw_esxi_csv | Sort-Object Name -Unique
$final_esxi_csv = "$results_folder/$job_name" + "_final_list.csv"
$input_raw_esxi_csv | Export-CSV -Path $final_esxi_csv -NoTypeInformation

Write-Host "

---------------------------------------------------------------------
Your resultant data is stored in the ./$results_folder directory.
---------------------------------------------------------------------
############################## fin ##################################"
