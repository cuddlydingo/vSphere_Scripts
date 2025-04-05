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

# Define function
function get_licenseinfo {
    foreach ($licenseManager in (Get-View LicenseManager)) {
        $vCenterName = ([System.uri]$licenseManager.Client.ServiceUrl).Host
        foreach ($license in $licenseManager.Licenses) {
            $licenseProp = $license.Properties
            $licenseExpiryInfo = $licenseProp | Where-Object { $_.Key -eq 'expirationDate' } | Select-Object -ExpandProperty Value
            if ($license.Name -eq 'Product Evaluation') {
                $expirationDate = 'Evaluation'
            } 
            elseif ($null -eq $licenseExpiryInfo) {
                $expirationDate = 'Never'
            } 
            else {
                $expirationDate = $licenseExpiryInfo
            } 
        
            if ($license.Total -eq 0) {
                $totalLicenses = 'Unlimited'
            } 
            else {
                $totalLicenses = $license.Total
            }
        
            $licenseObj = New-Object psobject
            $licenseObj | Add-Member -Name Name -MemberType NoteProperty -Value $license.Name
            $licenseObj | Add-Member -Name LicenseKey -MemberType NoteProperty -Value $license.LicenseKey
            $licenseObj | Add-Member -Name ExpirationDate -MemberType NoteProperty -Value $expirationDate
            $licenseObj | Add-Member -Name ProductName -MemberType NoteProperty -Value ($licenseProp | Where-Object { $_.Key -eq 'ProductName' } | Select-Object -ExpandProperty Value)
            $licenseObj | Add-Member -Name ProductVersion -MemberType NoteProperty -Value ($licenseProp | Where-Object { $_.Key -eq 'ProductVersion' } | Select-Object -ExpandProperty Value)
            $licenseObj | Add-Member -Name EditionKey -MemberType NoteProperty -Value $license.EditionKey
            $licenseObj | Add-Member -Name Total -MemberType NoteProperty -Value $totalLicenses
            $licenseObj | Add-Member -Name Used -MemberType NoteProperty -Value $license.Used
            $licenseObj | Add-Member -Name CostUnit -MemberType NoteProperty -Value $license.CostUnit
            $licenseObj | Add-Member -Name Labels -MemberType NoteProperty -Value $license.Labels
            $licenseObj | Add-Member -Name vCenter -MemberType NoteProperty -Value $vCenterName
            $licenseObj
        } 
    }
}

# Execute function based on user-defined output choice
switch ($output_type) {
    terminal {
        get_licenseinfo
    }
    file {
        $destination_path = Read-Host "Enter a .csv file destination for the output"
        get_licenseinfo | Export-Csv -Path $destination_path
    }
}

# Disconnect Sessions
Disconnect-VIServer * -Force -Confirm:$false