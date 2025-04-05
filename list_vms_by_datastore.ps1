# Get Creds and Connect to vCenter
Write-host "Please enter credentials:"
$creds = Get-Credential
$vcenter = Read-Host "To which vCenter would you like to connect?"
$destination_path = Read-Host "Enter a .txt file path to save output: "
Connect-VIServer -server $vcenter -Credential $creds

# Define switch for All VMs or Custom Search of VMs
$s = Read-Host "Choose one of the following: 
        Type 'all' to run for all VMs;
        Type 'custom' to run for a custom search of VM Name;
        What is your choice?"
switch ($s) {
    all {
        $dsclusters = Get-DatastoreCluster | Sort-Object
        Write-Output `n

        ForEach-Object {
            foreach ($dscluster in $dsclusters) {
                $datastores = Get-DatastoreCluster -Name $dscluster.name | Get-Datastore | Sort-Object Name
                Write-Output "Datastore Cluster: $dscluster"
                Write-Output "###############################################"
                foreach ($datastore in $datastores) {
                    Write-Output "VMs on Datastore: $datastore"
                    Get-Datastore -Name $datastore.name | Get-VM | Select-Object Name, PowerState | Sort-Object Name | Format-Table -AutoSize
                }
                Write-Output `n
            }
        } | Out-File -FilePath $destination_path -Append
    }
    custom {
        $search_string = read-host "Enter a search string for VM Name"
        $dsclusters = Get-DatastoreCluster | Sort-Object
        Write-Output `n

        ForEach-Object {
            foreach ($dscluster in $dsclusters) {
                $datastores = Get-DatastoreCluster -Name $dscluster.name | Get-Datastore | Sort-Object Name
                Write-Output "Datastore Cluster: $dscluster"
                Write-Output "###############################################"
                foreach ($datastore in $datastores) {
                    Write-Output "VMs on Datastore: $datastore"
                    Get-Datastore -Name $datastore.name | Get-VM | Where-Object { $_.Name -like "*$search_string*" } | 
                    Select-Object Name, 
                    @{Name = "CPU Count"; Expression = { $_.NumCpu } },
                    @{Name = "Disk Provisioned (GB)"; Expression = { [math]::round($_.ProvisionedSpaceGB) } },
                    @{Name = "FQDN"; Expression = { $_.ExtensionData.Guest.IPStack[0].DnsConfig.HostName, $_.ExtensionData.Guest.IPStack[0].DnsConfig.DomainName -join '.' } }, 
                    @{Name = "Guest Memory (GB)"; Expression = { $_.MemoryGB } },  
                    @{Name = "Guest OS"; Expression = { $_.Guest.OSFullName } }, 
                    @{Name = "IP Address"; Expression = { @($_.guest.IPAddress[0]) } },
                    @{Name = "vCenter Cluster"; Expression = { $_.VMHost.Parent } },
                    @{Name = "vCenter Folder"; Expression = { $_.Folder.Name } }, 
                    PowerState | 
                    Sort-Object Name | Format-Table -AutoSize
                }
                Write-Output `n
            }
        } | Out-File -FilePath $destination_path -Append
    }
}