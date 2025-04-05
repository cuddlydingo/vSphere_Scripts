# Script to iterate through ESXi servers and execute local bash commands on them as root
# 2022.07.09 - James Phillips

# Get Creds and Connect to vCenter
Write-host "Please enter vCenter credentials"
$vis_creds = Get-Credential
$vcenter = (Read-Host "To which vCenter(s) would you like to connect? 
NOTE: Multiple vCenters can be entered as a comma-separated list
E.G.: vcenter-01.example-domain.com, 10.10.10.10
Enter your vCenter(s) now").split(",").trim()

# Connect to vCenter(s)
Write-Host "Connecting to vCenter " $vcenter
Connect-VIServer -server $vcenter -Credential $vis_creds -Verbose

# Print to stdout or to a file?
$output_type = Read-Host "Would you like to print results to terminal, or to a file?
Valid responses are 'terminal' or 'file'"

# Define ESXi to modify
$esxi_source_type = Read-Host "Are you modifying the ESXis of an entire cluster, or a custom list?
Valid responses are 'cluster' or 'custom'"
if ($esxi_source_type -eq 'custom') {
    $esxi_list_location = Read-Host "Please enter the location of .txt file containing a list of the ESXi FQDNs which you'd like to modify.  For example, enter 'C:\Path_to_file\servers.txt'."
    $esxihosts = Get-Content $esxi_list_location
} elseif ($esxi_source_type -eq 'cluster') {
    $esxi_cluster_name = Read-Host "Please enter the vCenter Cluster in which you would like to work:"
    $esxihosts = (Get-Cluster -Name $esxi_cluster_name | Get-VMhost).Name | Sort-Object
} else {
    Write-Host "Your input does not compute.  Please try again."
}


# Create temporary file for ESXi password
Read-Host "Enter ESXi root password: " -AsSecureString | ConvertFrom-SecureString | Out-File ./pw_temp.txt

# Define function for remote execution
function execute_scripttext {
    foreach ($esxihost in $esxihosts) {
        # Start SSH
        Get-VMHost -Name $esxihost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } | Start-VMHostService | out-null
        
        # Create SSH Variables
        $pw_file = "./pw_temp.txt"
        $secpasswd = Get-Content -Path $pw_file | ConvertTo-SecureString
        $ssh_command_01 = 'echo "Your ssh command goes here in the powershell code"'
        #$ssh_command_02 = 'echo "Your ssh command goes here in the powershell code"'
        $credentials = new-object System.Management.Automation.PSCredential("root", $secpasswd)
    
        # Create SSH Sessions
        $ssh_session = New-SSHSession -ComputerName $esxihost -Credential $credentials -AcceptKey:$true
        $ssh_session_id = $ssh_session.SessionId
    
        # Execute SSH Command(s)
        Write-Host "Results for: " $esxihost
        Invoke-SSHCommand -SessionId $ssh_session_id -command $ssh_command_01
        #Invoke-SSHCommand -SessionId $ssh_session_id -command $ssh_command_02
        write-host `n
    
        # Disconnect SSH Session
        Remove-SSHSession -SessionId $ssh_session_id | out-null
        
        # Stop SSH
        Get-VMHost -Name $esxihost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } | Stop-VMHostService -confirm:$false | out-null
    }
}

switch ($output_type) {
    terminal {
        execute_scripttext
    }
    file {
        $file_output = Read-Host "Enter the local location where you would like to save output.
        For example, 'G:\documents\output.txt'"
        execute_scripttext >> $file_output
    }
}

# Remove temporary pw file
rm -Force ./pw_temp.txt

# Disconnect Sessions
Write-Host "Disconnecting vCenter"
Disconnect-VIServer -Server $vcenter -Confirm:$false
Write-Host "######################## fin ########################"