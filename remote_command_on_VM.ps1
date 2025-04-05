# Script designed to iterate through a list of VMs and execute a basic command via PowerCLI (i.e. without establishing PSSessions)

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

# Define Server List
$server_list_location = Read-Host "Please enter location of .txt file containing a list of the servers for which you'd like to execute on.
For Example, enter 'C:\Path_to_file\servers.txt'.
Please note, you will only need the VMware Names of the machines, NOT the FQDNs.
Please enter your file location now"
$server_list = Get-Content $server_list_location

# Define function for remote execution
function execute_scripttext {
    $user_command = Read-Host "Enter the command which you would like to execute on each VM.
    For example: Get-Content G:\test\directory\server.ini | select-string 'game_title'
    Enter your command now"
    Write-Host "Please enter the user credentials you would like to use to connect to the VM(s):"
    $user_credentials = Get-Credential
    foreach ($server in $server_list) {
        (Invoke-VMScript -VM $server -ScriptText $user_command -GuestCredential $user_credentials).ScriptOutput
        Write-Output "----------------------------------------------------------------"
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

# Disconnect Sessions
Disconnect-VIServer * -Force -Confirm:$false