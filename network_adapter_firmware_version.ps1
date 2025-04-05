# Script to iterate through ESXi servers and execute local bash commands on them as root
# 2022.07.09 - James Phillips

# Powershell Module Warning
Write-Host "`n`n"
Write-Host "This script requires the Powershell Posh-SSH Module to be installed.  Currently the v3.0.0-beta2 Posh-SSH is verified as working.`n"

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
Write-Host "`n"

# Print to stdout or to a file?

$output_type = Read-Host "Would you like to print results to terminal, .txt file, or .csv file?
Valid responses are 'terminal', 'txt', or 'csv'`n"

# Define ESXi to modify
$esxi_source_type = Read-Host "Are you modifying the ESXis of an entire cluster, or a custom list?
Valid responses are 'cluster' or 'custom'`n"
if ($esxi_source_type -eq 'custom') {
    $esxi_list_location = Read-Host "Please enter the location of .txt file containing a list of the ESXi FQDNs which you'd like to modify.  For example, enter 'C:\Path_to_file\servers.txt'`n"
    $esxihosts = Get-Content $esxi_list_location
} elseif ($esxi_source_type -eq 'cluster') {
    $esxi_cluster_name = Read-Host "Please enter the vCenter Cluster in which you would like to work`n"
    $esxihosts = (Get-Cluster -Name $esxi_cluster_name | Get-VMhost).Name | Sort-Object
} else {
    Write-Host "Your input does not compute.  Please try again."
}


# Create temporary file for ESXi password
Read-Host "Enter ESXi root password`n" -AsSecureString | ConvertFrom-SecureString | Out-File ./pw_temp.txt

# Define function for remote execution
function execute_scripttext {
    # Create Table
    $adapter_table = $null
    $adapter_table = New-Object system.Data.DataTable

    # Create Columns to Table
    $col1_esxi = New-Object system.Data.DataColumn ESXi,([string])
    $col2_vmnic0 = New-Object system.Data.DataColumn vmnic0,([string])
    $col3_vmnic1 = New-Object system.Data.DataColumn vmnic1,([string])
    $col4_vmnic4 = New-Object system.Data.DataColumn vmnic4,([string])

    # Add Columns to Table
    $adapter_table.Columns.Add($col1_esxi)
    $adapter_table.Columns.Add($col2_vmnic0)
    $adapter_table.Columns.Add($col3_vmnic1)
    $adapter_table.Columns.Add($col4_vmnic4)
    
    foreach ($esxihost in $esxihosts) {
        # Start SSH on ESXi 
        Get-VMHost -Name $esxihost | Get-VMHostService | Where-Object { $_.Key -eq "TSM-SSH" } | Start-VMHostService | out-null
        
        # Create SSH Variables
        $pw_file = "./pw_temp.txt"
        $secpasswd = Get-Content -Path $pw_file | ConvertTo-SecureString
        $ssh_command_vmnic0 = 'vmkchdev -l | grep -i vmnic0'
        $ssh_command_vmnic1 = 'vmkchdev -l | grep -i vmnic1'
        $ssh_command_vmnic4 = 'vmkchdev -l | grep -i vmnic4'
        $credentials = new-object System.Management.Automation.PSCredential("root", $secpasswd)
    
        # Create SSH Sessions
        $ssh_session = New-SSHSession -ComputerName $esxihost -Credential $credentials -AcceptKey:$true
        $ssh_session_id = $ssh_session.SessionId

        # Execute SSH Command(s) and store output as variables
        Write-Host "Working on $esxihost ..."
        $vmnic0_data = (Invoke-SSHCommand -SessionId $ssh_session_id -command $ssh_command_vmnic0).Output.split(" ")[1..2] -join " "
        $vmnic1_data = (Invoke-SSHCommand -SessionId $ssh_session_id -command $ssh_command_vmnic1).Output.split(" ")[1..2] -join " "
        $vmnic4_data = (Invoke-SSHCommand -SessionId $ssh_session_id -command $ssh_command_vmnic4).Output.split(" ")[1..2] -join " "

        # Create new row for table
        $row = $adapter_table.NewRow()
        $row.ESXi = $esxihost
        $row.vmnic0 = $vmnic0_data
        $row.vmnic1 = $vmnic1_data
        $row.vmnic4 = $vmnic4_data

        # Add new row to table
        $adapter_table.Rows.Add($row)

        # Disconnect SSH Session
        Remove-SSHSession -SessionId $ssh_session_id | out-null
        
        # Stop SSH
        Get-VMHost -Name $esxihost | Get-VMHostService | Where-Object { $_.Key -eq "TSM-SSH" } | Stop-VMHostService -confirm:$false | out-null
    }
    $adapter_table
}

# Execute script based on switch input
switch ($output_type) {
    terminal {
        execute_scripttext | Format-Table -Auto
    }
    txt {
        $file_output = Read-Host "Enter the local location where you would like to save output.
        For example, 'G:\documents\output.txt'`n"
        execute_scripttext | Format-Table -Auto >> $file_output
    }
    csv {
        $file_output = Read-Host "Enter the local path to save the .csv file.
        For example, './example_file.csv'`n"
        execute_scripttext | Export-CSV -Path $file_output -NoTypeInformation -Force -Append
    }
}

# Remove temporary pw file
Remove-Item -Force ./pw_temp.txt

# Disconnect Sessions
Write-Host "Disconnecting vCenter"
Disconnect-VIServer -Server $vcenter -Confirm:$false
Write-Host "######################## fin ########################"