# =============================================================================================================
# Script:    rvtools_collector.ps1
# Version:   1.1
# Date:      2020/12/18
# By:        James Phillips
# =============================================================================================================
<#
.DESCRIPTION
This script starts the the RVTools export all to xlsx function for multiple vCenter servers.

.INPUTS
This script requires a .CSV file which contains a list of the vCenters to be accessed, and also the User/Password(s) with which RVTools will connect to extract data.

.NOTES
To create an Encrypted Password for the CSV file (please do NOT use passwords in plaintext), you can use RVTools' native Encrypted Password creation tool.  After downloading and installing RVTools, in the RVTools program directory you can find a small application with which you can encrypt passwords for RVTools. You can use the encrypted password to start the application and/or the command line version of RVTools.

.EXAMPLE
An example CSV file contents would look similar to the example data presented below:
VCServer,User,EncryptedPassword
10.10.10.10,domain_name\example_user,_RVToolsPWDvalue
10.10.10.10,example_domain\example_user,_RVToolsPWDvalue
vcenter-01.example_domain.com,example_domain\example_user,_RVToolsPWDvalue
vcenter-01.example_domain.com,example_domain\example_user,_RVToolsPWDvalue
#>

# ----------------------------------------------------------
# Set RVtools EXE path and parameters (additional parameters in the For-Each Loop)
# ----------------------------------------------------------
$RVTools = "C:\Program Files (x86)\Robware\RVTools\RVTools.exe"
$CSVFile = Import-Csv -Path “C:\Path_To\server_list.csv”
$XlsxDirectory = "C:\Directory_for_storing\reports\"

ForEach ($CSVItem in $CSVFile) {
    # -----------------------------------------------------
    # Set parameters 
    # -----------------------------------------------------
    $Datetime = get-date -format `yyyyMMdd-HHmm.ss
    $VCServer = $CSVItem.VCServer
    $User = $CSVItem.User
    $EncryptedPassword = $CSVItem.EncryptedPassword

    $XlsxFile1 = $Datetime + "-" + $VCServer + "_RVTools-Export.xlsx" # Start cli of RVTools

    Write-Host "$VCServer at $Datetime : Export Started"  # -ForegroundColor DarkYellow
    
    # Adds all the arguments into a variable to be added to RVTools.exe command
    $Arguments = "-u $User -p $EncryptedPassword -s $VCServer -c ExportAll2xlsx -d $XlsxDirectory -f $XlsxFile1 -DBColumnNames"

    # Runs the RVTools process with all arguments from above
    $Process = Start-Process -FilePath "$RVTools" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru

    # Checks for Error and writes to Host Screen if problem
    if ($Process.ExitCode -eq -1) {
        
        Write-Host "$VCServer at $Datetime : Connection FAILED!" -ForegroundColor Red
        # exit 1

    }
    else {
        
        Write-Host "$VCServer at $Datetime : Export Successful" -ForegroundColor DarkYellow

    }

}