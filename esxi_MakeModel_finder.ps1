# Script to list basic ESXi host details by user-defined Make/Model, e.g. "PowerEdge R620"
# v1.0, 01/06/2022

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
$search_string = Read-Host("What Make/Model of ESXi are you looking for?  E.G. 'PowerEdge R620' or 'R620'")
$raw_esxi_csv = "$results_folder/$search_string" + "_raw_esxi_list.csv"

# For each vCenter, get data for each ESXi host that matches searchstring
foreach ($vcenter in $vcenter_list) {
    Write-Host "Working on vCenter $vcenter ..."
    Connect-VIServer -server $vcenter -Credential $vcenter_creds -Verbose
    Write-Host "Gathering ESXi data..."
    $esxi_host_list = (Get-VMHost | Sort-Object Name).Name
    foreach($esxi_host in $esxi_host_list) {
        if((Get-VMHost -Name $esxi_host).Model -like "*$search_string*") {
            Get-VMHost -Name $esxi_host | Select-Object Name,
            @{N = 'vCenter'; E = { $vcenter } },
            Parent,
            Build,
            Version,
            NumCpu,
            @{ n="Memory Total (GB)"; e={[math]::round( $_.MemoryTotalGB )}},
            ConnectionState |
            Export-Csv -Path $raw_esxi_csv -NoTypeInformation -Append
        }
    }
    Write-Host "Disconnecting vCenter $vcenter..."
    Disconnect-VIServer -Server $vcenter -Confirm:$false
}

# Removing duplicate ESXi host names from the CSV file
$input_raw_esxi_csv = Import-Csv $raw_esxi_csv | Sort-Object Name -Unique
$final_esxi_csv = "$results_folder/$search_string" + "_final_esxi_list.csv"
$input_raw_esxi_csv | Export-CSV -Path $final_esxi_csv -NoTypeInformation

Write-Host "

---------------------------------------------------------------------
Your resultant data is stored in the ./$results_folder directory.
---------------------------------------------------------------------
############################## fin ##################################"