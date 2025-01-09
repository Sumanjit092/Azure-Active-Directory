<#
.SYNOPSIS
   The Reset User Password PowerShell Script resets user passwords within a Microsoft 365 environment.
   This script is essential for administrators aiming to manage and reset user passwords efficiently.

.DESCRIPTION
    ResetUserPassword.ps1 is a robust PowerShell script designed to manage and reset user passwords in Microsoft 365 using the Microsoft Graph API.
    By connecting to Microsoft Graph with the necessary permissions, the script generates a new random password and resets the password for a specified user.
    It ensures that the user is prompted to change their password at the next sign-in, logging any errors encountered during execution.

.AUTHOR
    Sumanjit Pan

.VERSION
    1.0 - Initial Version
    1.1 - Patch Version (Bug Fix)

.DATE
    9th January, 2025

.FIRST PUBLISH DATE
    2nd January, 2025
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName
)

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
        Import-Module -Name 'Microsoft.Graph.Users'
        Write-Host "Microsoft Graph Module is imported." -ForegroundColor Cyan
    } else {
        Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
        Write-Host "Installing Microsoft Graph Module..." -ForegroundColor Yellow
        Install-Module -Name "Microsoft.Graph" -Force
        if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph"}) {
            Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
            Import-Module -Name 'Microsoft.Graph.Users'
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
Write-Host '                                  Reset User Passwords                                           ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and on an 'as is' basis without any warranties of any kind," -ForegroundColor Yellow
Write-Host "express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow
Write-Host "fitness for a particular purpose, or non-infringement. The user assumes all risks related to the" -ForegroundColor Yellow
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "The script checks internet connectivity, verifies the installation of the Microsoft Graph module," -ForegroundColor Yellow
Write-Host "and processes user password resets in Microsoft 365 using Microsoft Graph API." -ForegroundColor Yellow
Write-Host "It generates a new random password for the specified user and forces them to change it at the next sign-in." -ForegroundColor Yellow
Write-Host "Any errors encountered during execution are logged." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and user management, please visit the following links:" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/user?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

# Function to generate a random password
function Generate-RandomPassword {
    param (
        [int]$Length = 10
    )
    $upperCase = Get-Random -Count 2 -InputObject ([char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ')
    $lowerCase = Get-Random -Count 2 -InputObject ([char[]]'abcdefghijklmnopqrstuvwxyz')
    $numbers = Get-Random -Count 2 -InputObject ([char[]]'0123456789')
    $specialChars = Get-Random -Count 2 -InputObject ([char[]]'!@#$%^&*()-_=+[]{}|;:,.<>?')

    # Combine and shuffle the characters
    $allChars = $upperCase + $lowerCase + $numbers + $specialChars
    $shuffledChars = $allChars | Sort-Object {Get-Random}

    # Ensure password length
    $remainingLength = $Length - $shuffledChars.Length
    if ($remainingLength -gt 0) {
        $additionalChars = Get-Random -Count $remainingLength -InputObject ([char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+[]{}|;:,.<>?')
        $shuffledChars += $additionalChars
    }

    # Shuffle again to randomize further
    ($shuffledChars | Sort-Object {Get-Random}) -join ''
}

# Function to reset a user's password
function Reset-UserPassword {
    param (
        [string]$UserPrincipalName
    )

    # Generate a random password
    $newPassword = Generate-RandomPassword
    # Reset the password
    try {
        Update-MgUser -UserId $UserPrincipalName -AccountEnabled:$true -PasswordProfile @{
            forceChangePasswordNextSignIn = $true
            password = $newPassword
        }

        Write-Host "Password reset successfully for user: $($UserPrincipalName)"
        Write-Host "New Password: $($newPassword)"
    } catch {
        Write-Error "Failed to reset password for user: '$($UserPrincipalName)'. Error: $_"
    }
}

# Reset the user's password
Reset-UserPassword -UserPrincipalName "$($UserPrincipalName)"

# Disconnect from Microsoft Graph
Disconnect-MgGraph
