# Define script functions
function import_vm_function {
    $vm_csv = Import-Csv -Path $vm_csv_path
    foreach ($vm in $vm_csv) {
        Write-Host "Working on" $vm.vm_name
        # Assign values from CSV to avoid interpolation errors during "New-VM" command
        $vm_name_value = $vm.vm_name
        $vm_ds_value = $vm.datastore_name
        $vm_cluster_value = $vm.esxi_cluster_name
        $vm_folder_value = $vm.vm_folder
        New-VM -VMFilePath "[$vm_ds_value] $vm_name_value/$vm_name_value.vmx" -VMHost (Get-Cluster $vm_cluster_value | Get-VMhost | Get-Random) -Location (Get-Folder $vm_folder_value) #-RunAsync
        Start-Sleep -Seconds 30
    }
}

# Get Creds and Connect to vCenter
Write-host "Please enter vCenter login credentials:"
$creds = Get-Credential
$vcenter = Read-Host "To which single vCenter would you like to connect?  E.G. 10.10.10.10"
Connect-VIServer -Server $vcenter -Credential $creds

# Get script variables from user input
$vm_csv_path = Read-Host "Please provide the location of a .csv file containing the VM Names for the VMs you would like to import.
The CSV should take the following parameters (examples shown):
vm_name,datastore_name,esxi_cluster_name,vm_folder
test-vm01,datastore-01,Cluster-1,Infrastructure
test-vm02,datastore-01,Cluster-2,Security
test-vm03,datastore-02,Cluster-1,Test`n"

# Confirm data before proceeding
Write-Host "`nYou are about to import VMs using the following data:"
Get-Content $vm_csv_path
$verify = Read-Host "`nWould you like to continue importing the VMs as shown?  Please enter 'yes' to continue"

switch ($verify) {
    yes {
        import_vm_function
    }
    no {
        Write-host "This script will now exit."
        exit
    }
    default {
        Write-host "This script will now exit."
        exit
    }
}

# Disconnect vCenter Session(s)
Write-Host "Disconnecting from vCenters..."
Disconnect-VIServer * -Confirm:$false