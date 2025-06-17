<#
 
.SYNOPSIS:
    Export BitLocker Keys backup from AzureAD with PowerShell

.Description:
    Export-BitLockerKey.ps1 is a PowerShell script to Retrieve BitLocker Keys backup from AzureAD for all Azure Ad Devices. 
    It finds all devices with BitLocker Key and export a BitLocker Key Report along with the Device Name in Csv Format.

.AUTHOR:
    Sumanjit Pan

.VERSION:
    1.0
     
.Date: 
    22nd December, 2021
#>
[cmdletbinding()]
param(

        [Parameter( Mandatory=$false)]
        [switch]$SavedCreds
    )

$UserName = "user@domain.com"
$UserPass="PWD"
$UserPass=$UserPass|ConvertTo-SecureString -AsPlainText -Force
$UserCreds = New-Object System.Management.Automation.PsCredential($userName,$UserPass)

Function CheckAzurePowerShell{
''
Write-Host "Checking Azure Module..." -ForegroundColor Yellow
                            
    if (Get-InstalledModule Az) 
    {
    Write-Host "Azure PowerShell Module has installed." -ForegroundColor Green
    Import-Module Az
    Write-Host "Azure PowerShell Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else 
    {
    Write-Host "Azure PowerShell Module is not installed." -ForegroundColor Red
    ''
    Write-Host "Installing Azure PowerShell Module....." -ForegroundColor Yellow
    Install-Module Az -Force
                                
    if (Get-InstalledModule Az) {                                
    Write-Host "Azure PowerShell Module has installed." -ForegroundColor Green
    Import-Module Az
    Write-Host "Azure PowerShell Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    ''
    ''
    Write-Host "Operation aborted. Azure PowerShell Module was not installed." -ForegroundColor Red
    Exit}
    }

Write-Host "Connecting to Azure PowerShell..." -ForegroundColor Magenta

        if ($SavedCreds){
            Connect-AzAccount -Credential $UserCreds -ErrorAction SilentlyContinue
        }else{
            Connect-AzAccount -ErrorAction SilentlyContinue
        }

    ''
    }

Function CheckAzureAd{
''
Write-Host "Checking AzureAd Module..." -ForegroundColor Yellow
                            
    if (Get-Module -ListAvailable | where {$_.Name -like "*AzureAD*"}) 
    {
    Write-Host "AzureAD Module has installed." -ForegroundColor Green
    Import-Module AzureAD
    Write-Host "AzureAD Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else 
    {
    Write-Host "AzureAD Module is not installed." -ForegroundColor Red
    ''
    Write-Host "Installing AzureAD Module....." -ForegroundColor Yellow
    Install-Module AzureAD -Force
                                
    if (Get-Module -ListAvailable | where {$_.Name -like "*AzureAD*"}) {                                
    Write-Host "AzureAD Module has installed." -ForegroundColor Green
    Import-Module AzureAD
    Write-Host "AzureAD Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    ''
    ''
    Write-Host "Operation aborted. AzureAD Module was not installed." -ForegroundColor Red
    Exit}
    }

Write-Host "Connecting to AzureAD PowerShell..." -ForegroundColor Magenta

        if ($SavedCreds){
            $AzureAd = Connect-AzureAD -Credential $UserCreds -ErrorAction SilentlyContinue
        }else{
            $AzureAd = Connect-AzureAD -ErrorAction SilentlyContinue
        }
Write-Host "User $($AzureAd.Account) has connected to $($AzureAd.TenantDomain) AzureCloud tenant successfully." -ForegroundColor Green
''
   }

Cls

'===================================================================================================='
Write-Host '                              Azure Ad Device BitLocker Key Export                                   ' -ForegroundColor Green 
'===================================================================================================='
''                    
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red 
Write-Host "===================================================================================================="
Write-Host "This source code is freeware and is provided on an 'as is' basis without warranties of any kind," -ForegroundColor Yellow 
Write-Host "whether express or implied, including without limitation warranties that the code is free of defect," -ForegroundColor Yellow 
Write-Host "fit for a particular purpose or non-infringing. The entire risk as to the quality and performance of" -ForegroundColor Yellow 
Write-Host "the code is with the end user." -ForegroundColor yellow 
''
Write-Host "BitLocker is an inbuilt encryption feature that has been included with all versions of Windows since " -ForegroundColor Yellow 
Write-Host "Vista. It is designed to protect your files and data from unauthorized access by encrypting your " -ForegroundColor Yellow 
Write-Host "entire hard drive." -ForegroundColor Yellow
''
Write-Host "The encrypted drive can only be accessed with a password or a smart card that you set up when you " -ForegroundColor Yellow 
Write-Host "turned on Bitlocker Drive Encryption on that drive. If anyone tries to access your encrypted drive " -ForegroundColor Yellow
Write-Host "without proper authentication, access is denied." -ForegroundColor Yellow

"===================================================================================================="
''
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
$DataPath = "C:\Temp\BitLockerReport.csv"

CheckAzurePowerShell

CheckAzureAd

    $context = Get-AzContext
    $tenantId = $context.Tenant.Id
    $Token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($Context.Account, $Context.Environment, $TenantId, $Null, "Never", $Null, "74658136-14ec-4630-ad9b-26e160ff0fc6")
    $Headers = @{
    'Authorization' = 'Bearer ' + $Token.AccessToken
    'X-Requested-With'= 'XMLHttpRequest'
    'x-ms-client-request-id'= [guid]::NewGuid()
    'x-ms-correlation-id' = [guid]::NewGuid()
    }

Write-Host "Please wait, while BitLocker Key Export is in progress. It might take few hours depending on total number of Devices." -ForegroundColor Yellow
#Quering all AzureAD Device with Windows OS as Bitlocker applies only on Windows" -ForegroundColor White

$AzureAdDevices = (Get-AzureADDevice -All $true | ? {$_.DeviceOSType -eq "Windows"})

$DeviceRecords = @()

#For each Device quering the Azure Endpoint for Information

$DeviceRecords = foreach ($AzureAdDevice in $AzureAdDevices) {
        $url = "https://main.iam.ad.ext.azure.com/api/Device/$($AzureAdDevice.objectId)"
        $DeviceRecord = Invoke-RestMethod -Uri $url -Headers $Headers -Method Get
        $DeviceRecord
    }

#Filtering out the Devices that have Bitlocker Key

$Devices_BitlockerKey = $DeviceRecords.Where({$_.BitlockerKey.count -ge 1})

#Looping through each Device's each BitlockerKey property

$Report_Bitlocker = foreach ($Device in $Devices_BitlockerKey){
    foreach ($BLKey in $Device.BitlockerKey){
        [pscustomobject]@{
            DisplayName = $Device.DisplayName
            DriveType = $BLKey.drivetype
            KeyID = $BLKey.keyIdentifier
            RecoveryKey = $BLKey.recoveryKey
	        OwnerUserPrincipalName = $Device.registeredOwners.userPrincipalName
            OwnerDisplayName = $Device.registeredOwners.displayName
            CompanyName = $Device.registeredOwners.companyName
            }
    }
}
$Report_Bitlocker | Select -Property DisplayName, DriveType, KeyID, RecoveryKey, OwnerUserPrincipalName, OwnerDisplayName, CompanyName | Export-Csv $DataPath
''
Write-Host "BitLockerKey export is complete and ready to view" -ForegroundColor Yellow
Write-Host "BitLockerKey File is available in $DataPath" -ForegroundColor Green
''
Write-Host "Script completed successfully." -ForegroundColor Cyan
''
Exit
