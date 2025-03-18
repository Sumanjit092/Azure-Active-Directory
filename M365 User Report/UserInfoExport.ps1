<#
.SYNOPSIS
    Microsoft 365 User Information and License Report Script.
    Retrieves comprehensive user information from Microsoft 365 using Microsoft Graph API and exports the data to a CSV file.

.DESCRIPTION
    This PowerShell script collects detailed information about users in a Microsoft 365 environment, including:
        - Basic user information (name, email, job title, department, etc.)
        - Sign-in activity and password change details
        - Assigned licenses and their product names
        - Manager information
        - Employee ID and type
        - Account status and password policies

    The script downloads and caches the Microsoft license CSV file to map license GUIDs to human-readable names.
    It also handles errors gracefully and outputs meaningful messages when failures occur.

    The final output is saved as a CSV file in the user's Documents folder.

.AUTHOR
    Sumanjit Pan

.VERSION
    1.0 - Initial Version

.DATE
    18th March, 2025

.FIRST PUBLISH DATE
    18th March, 2025
#>

Function CheckInternet {
    try {
        $statuscode = (Invoke-WebRequest -Uri https://adminwebservice.microsoftonline.com/ProvisioningService.svc -UseBasicParsing).StatusCode
        if ($statuscode -ne 200) {
            Write-Host "Operation aborted. Unable to connect to Microsoft Graph, please check your internet connection." -ForegroundColor Red
            exit
        }
    } catch {
        Write-Host "Operation aborted. Unable to connect to Microsoft Graph, please check your internet connection." -ForegroundColor Red
        exit
    }
}

Function CheckMSGraph {
    Write-Host "Checking Microsoft Graph Module..." -ForegroundColor Yellow
    if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph"}) {
        Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
        Import-Module -Name 'Microsoft.Graph.Users', 'Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Identity.SignIns'
        Write-Host "Microsoft Graph Module is imported." -ForegroundColor Cyan
    } else {
        Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
        Write-Host "Installing Microsoft Graph Module..." -ForegroundColor Yellow
        Install-Module -Name "Microsoft.Graph" -Force
        if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph"}) {
            Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
            Import-Module -Name 'Microsoft.Graph.Users', 'Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Identity.SignIns'
            Write-Host "Microsoft Graph Module is imported." -ForegroundColor Cyan
        } else {
            Write-Host "Operation aborted. Microsoft Graph Module was not installed." -ForegroundColor Red
            Exit
        }
    }
    Write-Host "Connecting to Microsoft Graph PowerShell..." -ForegroundColor Magenta
    try {
        Connect-MgGraph -ClientId "YourAppClientID" -TenantId "YourTenantID" -CertificateThumbprint "YourCertThumbprint" -NoWelcome
        $MgContext = Get-MgContext
        Write-Host "User '$($MgContext.Account)' has connected to TenantId '$($MgContext.TenantId)' Microsoft Graph API successfully." -ForegroundColor Green
    } catch {
        Write-Host "Operation aborted. Unable to connect to Microsoft Graph API." -ForegroundColor Red
        exit
    }
}

Cls

'===================================================================================================='
Write-Host '                             Microsoft 365 User Information and License Report                                  ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red 
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and on an 'as is' basis without any warranties of any kind," -ForegroundColor Yellow 
Write-Host "express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow 
Write-Host "fitness for a particular purpose, or non-infringement. The user assumes all risks related to the" -ForegroundColor Yellow 
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "The script collects comprehensive user information from Microsoft 365, including:" -ForegroundColor Yellow 
Write-Host " - User details (name, email, job title, department, etc.)" -ForegroundColor Yellow 
Write-Host " - Sign-in activity and password change data" -ForegroundColor Yellow
Write-Host " - License assignments and product names" -ForegroundColor Yellow
Write-Host " - Manager information and password policies" -ForegroundColor Yellow
Write-Host " - Employee ID and type" -ForegroundColor Yellow
Write-Host ""
Write-Host "It exports the retrieved information to a CSV file located in the user's Documents folder." -ForegroundColor Yellow
Write-Host "Additionally, the script handles errors gracefully and provides meaningful messages." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and user data management, please visit the following links:" -ForegroundColor Yellow 
Write-Host " - https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host " - https://learn.microsoft.com/en-us/graph/api/user-get?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host " - https://learn.microsoft.com/en-us/graph/api/resources/users?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

# Retrieve all users with specified properties
$users = Get-MgUser -All -Filter "userType eq 'Member'" -Property Id, DisplayName, UserPrincipalName, UserType, Mail, JobTitle, Department, OfficeLocation, MobilePhone, BusinessPhones, StreetAddress, City, PostalCode, State, Country, AccountEnabled, CreatedDateTime, SignInActivity, PasswordPolicies, EmployeeID, EmployeeType

# Function to download and cache the CSV file
function Download-LicenseCSV {
    param (
        [string]$LicenseURL = 'https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv',
        [string]$LocalFilePath = "ProductLicenses.csv"
    )

    if (-not (Test-Path $LocalFilePath) -or (Get-Date) -gt ((Get-Item $LocalFilePath).LastWriteTime).AddDays(7)) {
        Write-Output "Downloading CSV file..."
        try {
            Invoke-WebRequest -Uri $LicenseURL -OutFile $LocalFilePath
            Write-Output "Download complete."
        } catch {
            Write-Error "Failed to download the file. $_"
            return
        }
    } else {
        Write-Output "CSV file is up-to-date."
    }

    try {
        return Import-Csv -Path $LocalFilePath
    } catch {
        Write-Error "Failed to import CSV file. $_"
        return $null
    }
}

# Function to get sign-in activity and password change date
function Get-SignInActivity {
    param (
        [string]$UserId
    )

    try {
        $user = Get-MgUser -UserId $UserId -Property 'SignInActivity', 'LastPasswordChangeDateTime'
        $signInActivity = $user.SignInActivity

        return @{
            LastSignInDateTime = $signInActivity?.LastSignInDateTime -or "No sign-in data"
            LastNonInteractiveSignInDateTime = $signInActivity?.LastNonInteractiveSignInDateTime -or "No non-interactive sign-in data"
            LastPasswordChangeDateTime = $user.LastPasswordChangeDateTime
        }
    } catch {
        return @{
            LastSignInDateTime = "Error retrieving sign-in data"
            LastNonInteractiveSignInDateTime = "Error retrieving non-interactive sign-in data"
            LastPasswordChangeDateTime = "Error retrieving password change data"
        }
    }
}

# Function to get user licenses
function Get-UserLicenses {
    param (
        [string]$UserId,
        [string]$LocalFilePath = "ProductLicenses.csv"
    )

    try {
        $csvContent = Download-LicenseCSV -LocalFilePath $LocalFilePath
        if (-not $csvContent) {
            Write-Warning "Failed to load license data from $LocalFilePath"
            return "Error loading license data"
        }

        $userLicenses = Get-MgUserLicenseDetail -UserId $UserId -ErrorAction Stop
        if (-not $userLicenses) {
            return "No Licenses Assigned"
        }

        $productNames = $userLicenses | ForEach-Object {
            $licenseSku = $_.SkuId
            $csvContent | Where-Object { $_.GUID -eq $licenseSku } | Select-Object -ExpandProperty Product_Display_Name
        }

        return ($productNames | Sort-Object -Unique) -join ", "
    } catch {
        Write-Warning "Failed to retrieve licenses for UserId: $UserId - $_"
        return "Error retrieving license details"
    }
}

# Function to get manager's name
function Get-ManagerName {
    param (
        [string]$UserId
    )

    try {
        $user = Get-MgUser -UserId $UserId -ExpandProperty 'Manager'
        return $user.Manager?.DisplayName -or "No manager data"
    } catch {
        Write-Error "Error retrieving manager data for user '$UserId': $_"
        return "Error retrieving manager data"
    }
}

# Function to determine if the password never expires
function Get-PasswordNeverExpires {
    param (
        [string]$PasswordPolicies
    )

    return $PasswordPolicies -contains "DisablePasswordExpiration"
}

# Function to get employee details
function Get-EmployeeDetails {
    param (
        [string]$UserId
    )

    try {
        $user = Get-MgUser -UserId $UserId -Property 'EmployeeID', 'EmployeeType'
        return @{
            EmployeeID = $user.EmployeeID -or "N/A"
            EmployeeType = $user.EmployeeType -or "N/A"
        }
    } catch {
        return @{
            EmployeeID = "Error retrieving Employee ID"
            EmployeeType = "Error retrieving Employee Type"
        }
    }
}

# Collect user data for export
$userData = @()

foreach ($user in $users) {
    $signInDetails = Get-SignInActivity -UserId $user.Id
    $licenseDetails = Get-UserLicenses -UserId $user.Id
    $managerName = Get-ManagerName -UserId $user.Id
    $passwordNeverExpires = Get-PasswordNeverExpires -PasswordPolicies $user.PasswordPolicies
    $employeeDetails = Get-EmployeeDetails -UserId $user.Id

    $userObject = [PSCustomObject]@{
        "Display Name" = $user.DisplayName
        "User ID" = $user.Id
        "Account Enabled" = $user.AccountEnabled
        "User Principal Name" = $user.UserPrincipalName
        "Email" = $user.Mail
        "User Type" = $user.UserType
        "Manager" = $managerName
        "Job Title" = $user.JobTitle
        "Department" = $user.Department
        "Employee ID" = $employeeDetails.EmployeeID
        "Employee Type" = $employeeDetails.EmployeeType
        "Office Location" = $user.OfficeLocation
        "Mobile Phone" = $user.MobilePhone
        "Business Phones" = $user.BusinessPhones -Join ", "
        "Street Address" = $user.StreetAddress
        "City" = $user.City
        "Postal Code" = $user.PostalCode
        "State" = $user.State
        "Country" = $user.Country
        "Created DateTime" = $user.CreatedDateTime
        "Last Sign-In" = $signInDetails.LastSignInDateTime
        "Last Non-Interactive Sign-In" = $signInDetails.LastNonInteractiveSignInDateTime
        "Last Password Change" = $signInDetails.LastPasswordChangeDateTime
        "Licenses" = $licenseDetails
        "Password Never Expires" = $passwordNeverExpires
    }

    $userData += $userObject
}

# Save path and export
$savePath = Join-Path -Path $env:USERPROFILE -ChildPath "Documents\AzureADUsersReport.csv"

if (Test-Path $savePath) {
    Remove-Item -Path $savePath -Force
}

$userData | Export-Csv -Path $savePath -NoTypeInformation
