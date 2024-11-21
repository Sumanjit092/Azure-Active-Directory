<#
.SYNOPSIS:
    Automates the creation and export of self-signed certificates with customizable parameters.

.DESCRIPTION:
    This PowerShell script generates self-signed certificates based on user-defined parameters such as the subject name, validity period, export folder, key length, and optional certificate extensions.
    It includes robust input validation, detailed logging, and enhanced error handling to ensure a reliable and user-friendly certificate creation process. The script exports the certificates in 
    both .cer and .pfx formats, making it suitable for various use cases.

.AUTHOR:
    Sumanjit Pan

.VERSION:
    1.0 - Intitial Version

.DATE:
    21st November, 2024

.FIRST PUBLISH DATE:
    21st November, 2024
#>

'===================================================================================================='
Write-Host '                                  Self-Signed Certificate Creation Script                                                 ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red 
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and on an 'as is' basis without any warranties of any kind," -ForegroundColor Yellow 
Write-Host "express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow
Write-Host "fitness for a particular purpose, or non-infringement. The user assumes all risks related to the" -ForegroundColor Yellow 
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "The script generates self-signed certificates based on user-defined parameters such as the subject name," -ForegroundColor Yellow 
Write-Host "validity period, export folder, key length, and optional certificate extensions. It ensures input validation," -ForegroundColor Yellow 
Write-Host "detailed logging, and enhanced error handling to provide a reliable and user-friendly certificate creation process." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on self-signed certificates and their usage, please visit the following links:" -ForegroundColor Yellow 
Write-Host "https://learn.microsoft.com/en-us/windows/msix/package/create-certificate-package-signing#create-a-self-signed-certificate" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

function Create-SelfSignedCert {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SubjectName,     # CN for the certificate

        [Parameter(Mandatory=$true)]
        [int]$ValidityPeriod,     # Validity period in months

        [Parameter(Mandatory=$true)]
        [string]$ExportFolder,    # Folder path to export certificates

        [int]$KeyLength = 2048    # Default key length (can be changed)
    )

    # Validate inputs
    if (-not (Test-Path $ExportFolder)) {
        Write-Host "Error: The export folder does not exist." -ForegroundColor Red
        return
    }

    if ($KeyLength -ne 2048 -and $KeyLength -ne 4096) {
        Write-Host "Error: Invalid key length. Only 2048 or 4096 are supported." -ForegroundColor Red
        return
    }

    # Create the self-signed certificate
    Write-Host "Creating certificate: CN=$SubjectName with key length $KeyLength..." -ForegroundColor Cyan
    $Cert = New-SelfSignedCertificate -Subject "CN=$SubjectName" `
                                      -CertStoreLocation "Cert:\LocalMachine\My" `
                                      -KeyExportPolicy Exportable `
                                      -KeySpec Signature `
                                      -NotAfter (Get-Date).AddMonths($ValidityPeriod) `
                                      -KeyLength $KeyLength

    if ($null -eq $Cert) {
        Write-Host "Certificate creation failed." -ForegroundColor Red
        return
    }

    # Export public and private certificates
    $CertPath = Join-Path -Path $ExportFolder -ChildPath "$SubjectName.cer"
    Export-Certificate -Cert $Cert -FilePath $CertPath
    Write-Host "Public certificate exported to $CertPath" -ForegroundColor Green

    $Password = Read-Host -Prompt "Enter password to protect the private key" -AsSecureString
    $PfxPath = Join-Path -Path $ExportFolder -ChildPath "$SubjectName.pfx"
    Export-PfxCertificate -Cert $Cert -FilePath $PfxPath -Password $Password
    Write-Host "Private certificate exported to $PfxPath" -ForegroundColor Green

    # Ask user to keep or remove the certificate from the store
    $KeepCert = Read-Host "Do you want to keep the certificate in the store? (Yes/No)"
    if ($KeepCert -eq "No") {
        Remove-Item "Cert:\LocalMachine\My\$($Cert.Thumbprint)"
        Write-Host "Certificate removed from the store." -ForegroundColor Yellow
    } else {
        Write-Host "Certificate remains in the store." -ForegroundColor Green
    }

    Write-Host "Certificate creation and export completed successfully." -ForegroundColor Green
}

# Main Execution
$SubjectName = Read-Host "Enter the Common Name (CN) for the certificate"
$ValidityPeriod = [int](Read-Host "Enter validity period (in months)")  # Corrected input parsing
$ExportFolder = Read-Host "Enter export folder path"
$KeyLength = [int](Read-Host "Enter key length (2048 or 4096)")  # Corrected input parsing

Create-SelfSignedCert -SubjectName $SubjectName -ValidityPeriod $ValidityPeriod -ExportFolder $ExportFolder -KeyLength $KeyLength
