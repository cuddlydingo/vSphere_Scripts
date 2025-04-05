# 2020.07.06 by James Phillips
# Script configured to gather information for specific ESXi host versions.
# If you need to check other ESXi versions, please modify Line 12.

$credentials = Get-Credential
$vcenter = Read-Host "Please provide IP Address or FQDN of desired vCenter: ".split(",").trim()
$csvpath = Read-Host "Please enter destination path for resultant CSV data: "

Write-Host "Connecting to vCenter " $vcenter
Connect-VIServer -Server $vcenter -Credential $credentials -Verbose

$esxihosts = (Get-VMHost | Where-Object { $_.version -eq '6.7.0' }).Name | Sort-Object

$ErrorActionPreference = 'SilentlyContinue'

foreach ($esxihost in $esxihosts) {
    Write-Host "Working on ESXi $esxihost..."
    $esxcli = Get-EsxCli -vmhost $esxihost
    $qfle3 = $esxcli.system.module.list() | Where-Object { $_.Name -eq 'qfle3' }
    $ixgbe = $esxcli.system.module.list() | Where-Object { $_.Name -eq 'ixgbe' }
    $tg3 = $esxcli.system.module.list() | Where-Object { $_.Name -eq 'tg3' }
    $elxnet = $esxcli.software.vib.list() | Where-Object { $_.name -eq "elxnet" }
       
    if ($ixgbe) {
        $ixgbe = $esxcli.system.module.get("ixgbe")
    } 
    if ($tg3) {
        $tg3 = $esxcli.system.module.get("tg3")
    }
    if ($qfle3) {
        $qfle3 = $esxcli.system.module.get("qfle3")
    }
    if ($elxnet) {
        $elxnet = $esxcli.system.module.get("elxnet")
    }


    Get-View -ViewType HostSystem -Filter @{"Name" = $esxihost } | Select-Object Name,
    @{N = 'Product'; E = { $_.Config.Product.FullName } },
    @{N = 'Build'; E = { $_.Config.Product.Build } },
    @{N = 'Vendor'; E = { $_.Hardware.SystemInfo.Vendor } },
    @{N = 'Model'; E = { $_.Hardware.SystemInfo.Model } },
    @{N = "SerialNumber"; Expression = { ($_.Hardware.SystemInfo.OtherIdentifyingInfo | Where-Object { $_.IdentifierType.Key -eq "ServiceTag" }).IdentifierValue } },
    @{N = "BIOS Version"; E = { $_.Hardware.BiosInfo.BiosVersion } },
    @{N = "BIOS Major"; E = { $_.Hardware.BIOSInfo.majorRelease } }, # only available in ESXi v6.7 or later
    @{N = "BIOS Minor"; E = { $_.Hardware.BIOSInfo.minorRelease } }, # only available in ESXi v6.7 or later
    @{N = "BIOSdate"; E = { $_.Hardware.BiosInfo.releaseDate } },
    @{N = 'HBA-Module-Intel'; E = { $ixgbe.Module } },
    @{N = 'HBA-Version-Intel'; E = { $ixgbe.Version } },
    @{N = 'HBA-Module-Broadcom'; E = { $tg3.Module } },
    @{N = 'HBA-Version-Broadcom'; E = { $tg3.Version } },
    @{N = 'HBA-Module-QLogic'; E = { $qfle3.Module } },
    @{N = 'HBA-Version-QLogic'; E = { $qfle3.Version } },
    @{N = 'HBA-Module-elxnet'; E = { $elxnet.Module } },
    @{N = 'HBA-Version-elxnet'; E = { $elxnet.Version } },
    @{N = "FC-Driver"; E = { $elxnet.version.substring(0, 14) } } |
    Export-Csv -Path $csvpath -NoTypeInformation -Append
}

Write-Host "Disconnecting vCenter"
Disconnect-VIServer -Server $vcenter -Confirm:$false
Write-Host "######################## fin ########################"