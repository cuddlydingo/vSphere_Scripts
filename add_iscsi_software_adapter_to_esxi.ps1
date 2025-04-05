# v1.0
# April 20, 2023
# This script adds an ISCSi Software Adapter to an ESXi Host and configures it for use with Dell Powerstore.  

# Get location of .txt file containing ESXi's to be modified
$esxi_list = Read-Host "Enter the path/location of the .txt file containing a list of the ESXi names you would like to modify, e.g. /tmp/esxihost.txt "

# Create ISCSi Adapter
foreach ($esxi in Get-Content $esxi_list) {
    Get-VMHostStorage -VMHost $esxi | Set-VMHostStorage -SoftwareIScsiEnabled $True
}

# Ask user for adapter name (they should all be the same)
$adapter_name = Read-Host "What is the iscsi adapter Device name?"

# Print out ESXi Names and corresponding IQN IDs
foreach ($esxi in Get-Content $esxi_list) {
    $esxi_name = (Get-VMHost -Name $esxi).Name
    $iscsi_iqn = (Get-VMHost -name $esxi | Get-VMHostHba -Type IScsi | where {$_.Name -like $adapter_name}).ExtensionData.IScsiName
    Write-Host "$esxi_name $iscsi_iqn"
}

# Define Dynamic Discovery IP/Port
$iScsiTargetIp = Read-Host "What is the Dynamic Discovery IP Address for your Storage Device?"
$iScsiTargetPort = Read-Host "What is the Dynamic Discovery Port? `nPlease enter only the numeric port value, e.g. '1234' not 'Port 1234'"

# Add Dynamic Discovery IP/Port to each ESXi ISCSi Adapter
foreach ($esxi in Get-Content $esxi_list) {
    $esxcli = Get-VMHost -Name $esxi | Get-EsxCli -V2
    $iScsiHBA = Get-VMHost -Name $esxi | Get-VMHostHba -Type IScsi -Device $adapter_name
    $iScsiHBA | New-IScsiHbaTarget -Address $iScsiTargetIp -Port $iScsiTargetPort
    Get-VMHost -Name $esxi | Get-VMHostStorage -RescanAllHba -RescanVmfs
}