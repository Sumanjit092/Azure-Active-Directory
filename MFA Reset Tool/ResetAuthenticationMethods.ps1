<#
.SYNOPSIS:
   The Reset Authentication Methods PowerShell Script removes specific user authentication methods within a Microsoft 365 environment.
   This script is essential for administrators aiming to manage and reset user authentication methods efficiently.

.DESCRIPTION:
    ResetAuthenticationMethods.ps1 is a robust PowerShell script designed to manage and reset user authentication methods in Microsoft 365 using the Microsoft Graph API.
    By connecting to Microsoft Graph with the necessary permissions, the script retrieves and removes the specified authentication methods for a user.
    It processes this data to ensure that only the desired authentication methods are reset, logging any errors encountered during execution.

.AUTHOR:
    Sumanjit Pan

.VERSION:
    1.0 - Initial Version
    1.1 - Patch (Import-Module)

.DATE:
    31st December, 2024

.FIRST PUBLISH DATE:
    31st December, 2024
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$UserId
)

Function CheckInternet {
    $statuscode = (Invoke-WebRequest -Uri https://adminwebservice.microsoftonline.com/ProvisioningService.svc -UseBasicParsing).StatusCode
    if ($statuscode -ne 200){
        Write-Host "Operation aborted. Unable to connect to Microsoft Graph, please check your internet connection." -ForegroundColor Red
        exit
    }
}

Function CheckMSGraph {
    Write-Host "Checking Microsoft Graph Module..." -ForegroundColor Yellow
    if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph" -or $_.Name -like "Microsoft.Graph.Beta" }) {
        Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
        Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Reports', 'Microsoft.Graph.Identity.SignIns'
    } else {
        Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
        Write-Host "Installing Microsoft Graph Module..." -ForegroundColor Yellow
        Install-Module -Name "Microsoft.Graph", "Microsoft.Graph.Beta" -Force
        if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph" -or $_.Name -like "Microsoft.Graph.Beta" }) {
            Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
            Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Reports', 'Microsoft.Graph.Identity.SignIns'
            Write-Host "Microsoft Graph Module is imported." -ForegroundColor Cyan
        } else {
            Write-Host "Operation aborted. Microsoft Graph Module was not installed." -ForegroundColor Red
            Exit
        }
    }
    Write-Host "Connecting to Microsoft Graph PowerShell..." -ForegroundColor Magenta
    Connect-MgGraph -ClientId "App Client ID" -TenantId "Entra ID Tenant ID" -CertificateThumbprint "Cert Thumbprint" -NoWelcome
    $MgContext = Get-MgContext
    Write-Host "User '$($MgContext.Account)' has connected to TenantId '$($MgContext.TenantId)' Microsoft Graph API successfully." -ForegroundColor Green
}

Cls

'===================================================================================================='
Write-Host '                                  Reset Authentication Methods                                   ' -ForegroundColor Green
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
Write-Host "and processes user authentication methods in Microsoft 365 using Microsoft Graph API." -ForegroundColor Yellow
Write-Host "It attempts to remove specified authentication methods and logs any errors encountered during execution." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and user authentication methods, please visit the following links:" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/user?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/authenticationmethod?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

# Define a mapping of method types to friendly names
$methodTypeFriendlyNames = @{
    '#microsoft.graph.fido2AuthenticationMethod' = 'FIDO2 Authentication'
    '#microsoft.graph.emailAuthenticationMethod' = 'Email Authentication'
    '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' = 'Microsoft Authenticator Authentication'
    '#microsoft.graph.phoneAuthenticationMethod' = 'Phone Authentication'
    '#microsoft.graph.softwareOathAuthenticationMethod' = 'Software OATH Authentication'
    '#microsoft.graph.temporaryAccessPassAuthenticationMethod' = 'Temporary Access Pass Authentication'
    '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' = 'Windows Hello for Business Authentication'
    '#microsoft.graph.passwordAuthenticationMethod' = 'Password Authentication'
}

# Function to get a friendly name for a given method type
function Get-FriendlyName {
    param (
        [string]$MethodType
    )
    return $methodTypeFriendlyNames[$MethodType]
}

# Define the path for error logs
$ErrorLogPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents", "ErrorLog.txt")

# Function to log errors
function Log-Error {
    param (
        [string]$Message
    )
    # Get the current timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Format the log message
    $logMessage = "$($timestamp): $($Message)"
    # Output the log message to the console in red
    Write-Host $logMessage -ForegroundColor Red
    # Append the log message to the error log file
    Add-Content -Path $ErrorLogPath -Value $logMessage
}

# Function to remove a specific authentication method for a user
function Remove-AuthenticationMethod {
    param (
        [string]$UserId,
        $Method
    )

    # Extract the type of the authentication method
    $methodType = $Method.AdditionalProperties['@odata.type']
    $friendlyName = Get-FriendlyName -MethodType $methodType
    try {
        # Inform the user which method type is being attempted for removal
        Write-Host "Attempting to remove authentication method of type: $friendlyName" -ForegroundColor Yellow
        # Switch-case to handle different types of authentication methods
        switch ($methodType) {
            '#microsoft.graph.fido2AuthenticationMethod' {
                Remove-MgUserAuthenticationFido2Method -UserId $UserId -Fido2AuthenticationMethodId $Method.Id
            }
            '#microsoft.graph.emailAuthenticationMethod' {
                Remove-MgUserAuthenticationEmailMethod -UserId $UserId -EmailAuthenticationMethodId $Method.Id
            }
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
                Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $UserId -MicrosoftAuthenticatorAuthenticationMethodId $Method.Id
            }
            '#microsoft.graph.phoneAuthenticationMethod' {
                Remove-MgUserAuthenticationPhoneMethod -UserId $UserId -PhoneAuthenticationMethodId $Method.Id
            }
            '#microsoft.graph.softwareOathAuthenticationMethod' {
                Remove-MgUserAuthenticationSoftwareOathMethod -UserId $UserId -SoftwareOathAuthenticationMethodId $Method.Id
            }
            '#microsoft.graph.temporaryAccessPassAuthenticationMethod' {
                Remove-MgUserAuthenticationTemporaryAccessPassMethod -UserId $UserId -TemporaryAccessPassAuthenticationMethodId $Method.Id
            }
            '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' {
                Remove-MgUserAuthenticationWindowsHelloForBusinessMethod -UserId $UserId -WindowsHelloForBusinessAuthenticationMethodId $Method.Id
            }
            '#microsoft.graph.passwordAuthenticationMethod' {
                Write-Host "Password authentication method cannot be removed. Skipping..." -ForegroundColor DarkGray
                return $true
            }
            default {
                Write-Host "Unsupported authentication method type: $friendlyName" -ForegroundColor Red
                return $true
            }
        }
        # Inform the user that the method was successfully removed
        Write-Host "Successfully removed authentication method of type: $friendlyName" -ForegroundColor Green
        return $true
    } catch {
        # Log the error if removal fails
        $errorMessage = "Failed to remove method $($Method.Id). Exception: $($_.Exception.Message)"
        Log-Error -Message $errorMessage
        return $false
    }
}

try {
    # Start the process to retrieve authentication methods
    Write-Host "Starting the process to retrieve authentication methods for user $UserId..." -ForegroundColor Cyan
    # Retrieve all authentication methods for the user
    $methods = Get-MgUserAuthenticationMethod -UserId $UserId
    # Inform the user how many authentication methods were found (excluding password authentication)
    Write-Host "Found $($methods.Count - 1) authentication method(s) for user $UserId (excluding password authentication)." -ForegroundColor Cyan

    $defaultMethod = $null

    # Remove each authentication method
    foreach ($authMethod in $methods) {
        $methodType = $authMethod.AdditionalProperties['@odata.type']
        $friendlyName = Get-FriendlyName -MethodType $methodType
        # Inform the user which method is being processed
        Write-Host "Processing authentication method: $friendlyName" -ForegroundColor Blue
        if (-not (Remove-AuthenticationMethod -UserId $UserId -Method $authMethod)) {
            $defaultMethod = $authMethod
        }
    }

    # Handle the default method if identified
    if ($defaultMethod) {
        Write-Host "Attempting to remove the default authentication method..." -ForegroundColor Yellow
        if (-not (Remove-AuthenticationMethod -UserId $UserId -Method $defaultMethod)) {
            Log-Error -Message "Failed to remove the default authentication method."
        }
    }

    # Re-check authentication methods to confirm removal
    Write-Host "Re-checking remaining authentication methods for user $UserId..." -ForegroundColor Cyan
    $remainingMethods = Get-MgUserAuthenticationMethod -UserId $UserId
    # Inform the user how many methods are remaining (excluding password authentication)
    Write-Host "Remaining authentication method(s): $($remainingMethods.Count - 1) (excluding password authentication)." -ForegroundColor Cyan

} catch {
    # Log any critical errors that occur during the process
    Log-Error -Message "Critical error: $($_.Exception.Message)"
}
