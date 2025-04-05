# Set to multiple VC Mode
if(((Get-PowerCLIConfiguration).DefaultVIServerMode) -ne "Multiple") {
    Set-PowerCLIConfiguration -DefaultVIServerMode Multiple | Out-Null
}

# Make sure you connect to your VCs here
# Get vCenter Credentials and set other Global Variables
Write-Host "`nPlease enter vCenter credentials";
$vcenter_creds = Get-Credential
$vcenter_list = (Read-Host "To which vCenter(s) would you like to connect? 
    NOTE: Multiple vCenters can be entered as a comma-separated list
    E.G.: 10.10.10.10, 10.10.10.11
    Enter your vCenter(s) now").split(",").trim()
# Connect to vCenter for PowerCLI Data Collection
Write-Host "Connecting to vCenter(s)..."
Connect-VIServer -server $vcenter_list -Credential $vcenter_creds -Verbose

# Get the license info from each VC in turn
$vSphereLicInfo = @()
$ServiceInstance = Get-View ServiceInstance
Foreach ($LicenseMan in Get-View ($ServiceInstance | Select -First 1).Content.LicenseManager) {
    Foreach ($License in ($LicenseMan | Select -ExpandProperty Licenses)) {
        $Details = "" |Select VC, Name, Key, Total, Used, ExpirationDate , Information
        $Details.VC = ([Uri]$LicenseMan.Client.ServiceUrl).Host
        $Details.Name= $License.Name
        $Details.Key= $License.LicenseKey
        $Details.Total= $License.Total
        $Details.Used= $License.Used
        $Details.Information= $License.Labels | Select -expand Value
        $Details.ExpirationDate = $License.Properties | Where { $_.key -eq "expirationDate" } | Select -ExpandProperty Value
        $vSphereLicInfo += $Details
    }
}
$vSphereLicInfo | Format-Table -AutoSize