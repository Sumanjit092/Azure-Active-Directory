<#
.SYNOPSIS:
   The User Authentication Report PowerShell Script generates a comprehensive report on user authentication methods and multi-factor authentication (MFA) preferences
   within a Microsoft 365 environment. This script is essential for administrators aiming to enhance security audits and ensure compliance by providing detailed insights
   into user authentication practices.

.DESCRIPTION:
    UserAuthenticationReport.ps1 is a robust PowerShell script designed to manage and report on user authentication methods in Microsoft 365 using the Microsoft Graph API.
    By connecting to Microsoft Graph with the necessary permissions, the script retrieves extensive user information, including authentication methods and MFA preferences.
    It processes this data to generate a detailed report, which is then exported to a CSV file for easy analysis and record-keeping.

.AUTHOR:
    Sumanjit Pan

.VERSION:
    1.0 - Intitial Version

.DATE:
    19th November, 2024

.FIRST PUBLISH DATE:
    19th November, 2024
#>

Function CheckInternet
{
$statuscode = (Invoke-WebRequest -Uri https://adminwebservice.microsoftonline.com/ProvisioningService.svc).statuscode
if ($statuscode -ne 200){
''
''
Write-Host "Operation aborted. Unable to connect to Microsoft Graph, please check your internet connection." -ForegroundColor Red
exit
}
}

Function CheckMSGraph{
''
Write-Host "Checking Microsoft Graph Module..." -ForegroundColor Yellow
                            
    if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph" -or $_.Name -like "Microsoft.Graph.Beta" }) 
    {
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Beta.Identity.SignIns', 'Microsoft.Graph.Reports', 'Microsoft.Graph.Beta.Identity.SignIns', 'Microsoft.Graph.Beta.Reports' 
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
    ''
    Write-Host "Installing Microsoft Graph Module....." -ForegroundColor Yellow
    Install-Module -Name "Microsoft.Graph", "Microsoft.Graph.Beta" -Force
                                
    if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph" -or $_.Name -like "Microsoft.Graph.Beta" }) 
    {                                
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Beta.Identity.SignIns', 'Microsoft.Graph.Reports', 'Microsoft.Graph.Beta.Identity.SignIns', 'Microsoft.Graph.Beta.Reports' 
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    ''
    ''
    Write-Host "Operation aborted. Microsoft Graph Module was not installed." -ForegroundColor Red
    Exit
    }
}

Write-Host "Connecting to Microsoft Graph PowerShell..." -ForegroundColor Magenta

Connect-MgGraph -ClientId "App Client ID" -TenantId "Entra ID Tenant ID" -NoWelcome

$MgContext= Get-MgContext

Write-Host "User '$($MgContext.Account)' has connected to TenantId '$($MgContext.TenantId)' Microsoft Graph API successfully." -ForegroundColor Green
''
''
}

Cls

'===================================================================================================='
Write-Host '                                  User Authentication Report Script                                                 ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red 
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and on an 'as is' basis without any warranties of any kind," -ForegroundColor Yellow 
Write-Host "express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow 
Write-Host "fitness for a particular purpose, or non-infringement. The user assumes all risks related to the" -ForegroundColor Yellow 
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "The script fetches and processes user authentication methods in Microsoft 365 using Microsoft Graph API." -ForegroundColor Yellow 
Write-Host "It generates a detailed report on user authentication methods, MFA preferences, and other related information." -ForegroundColor Yellow
Write-Host "Additionally, it logs any errors encountered during execution." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and user authentication methods, please visit the following links:" -ForegroundColor Yellow 
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/user?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/authenticationmethod?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

$ErrorActionPreference = SilentlyContinue
$documentsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents")
$ExportPath = [System.IO.Path]::Combine($documentsPath, "UserAuthenticationReport.csv")

# Function to fetch authentication methods for a user
function Get-AuthMethods {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserId
    )

    $AllMethods = @()  # Initialize an empty array to hold method descriptions

    try {
        # Fetch the user's authentication methods from Microsoft Graph
        $AuthMethods = Get-MgUserAuthenticationMethod -UserId $UserId
        
        # Loop through each authentication method
        foreach ($AuthMethod in $AuthMethods) {
            $MethodType = $AuthMethod.AdditionalProperties['@odata.type']  # Get the type of method
            $MethodDescription = ""

            # Handle different authentication method types
            switch ($MethodType) {
                "#microsoft.graph.passwordAuthenticationMethod" {
                    $MethodDescription = "Password: Traditional password"
                }
                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                    $DisplayName = $AuthMethod.AdditionalProperties['displayName']
                    $DeviceTag = $AuthMethod.AdditionalProperties['deviceTag']
                    $PhoneAppVersion = $AuthMethod.AdditionalProperties['phoneAppVersion']
                    $MethodDescription = "Authenticator app on '$DisplayName' ('$DeviceTag', version: '$PhoneAppVersion')"
                }
                "#microsoft.graph.fido2AuthenticationMethod" {
                    $Model = $AuthMethod.AdditionalProperties['model']
                    $MethodDescription = "FIDO2 Key: '$Model'"
                }
                "#microsoft.graph.phoneAuthenticationMethod" {
                    $PhoneNumber = $AuthMethod.AdditionalProperties['phoneNumber']
                    $PhoneType = $AuthMethod.AdditionalProperties['phoneType']
                    $MethodDescription = "SMS to '$PhoneNumber' (Type: '$PhoneType')"
                }
                "#microsoft.graph.emailAuthenticationMethod" {
                    $EmailAddress = $AuthMethod.AdditionalProperties['emailAddress']
                    $MethodDescription = "Email (SSPR) to '$EmailAddress'"
                }
                "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" {
                    $CreatedDate = Get-Date($AuthMethod.AdditionalProperties['createdDateTime']) -format "dd-MMM-yyyy HH:mm"
                    $MethodDescription = "Passwordless on '$CreatedDate'"
                }

                "#microsoft.graph.platformCredentialAuthenticationMethod" {
                    $DisplayName = $AuthMethod.AdditionalProperties['displayName']
                    $Platform = $AuthMethod.AdditionalProperties['platform']
                    $keyStrength = $AuthMethod.AdditionalProperties['keyStrength']
                    $MethodDescription = "Platform Credential on '$DisplayName', OS: '$Platform', Strength: '$keyStrength'"
                }

                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    $DisplayName = $AuthMethod.AdditionalProperties['displayName']
                    $CreatedDate = Get-Date($AuthMethod.AdditionalProperties['createdDateTime']) -format "dd-MMM-yyyy HH:mm"
                    $MethodDescription = "Windows Hello on '$DisplayName' ($CreatedDate)"
                }
                Default {
                    $MethodDescription = "Unknown method: '$MethodType'"  # Handle unknown methods
                }
            }

            # Add the description of the method to the list
            $AllMethods += $MethodDescription
        }

        return $AllMethods -join ", "
    } catch {
        Write-Error "Error fetching authentication methods for user '$UserId': $_"
        return "An error occurred while fetching authentication methods."
    }
}

# Function to get simplified MFA preferences for a user
function Get-UserMFAPreference {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserId
    )

    try {
        # Get the user's authentication sign-in preferences
        $DefaultMFAMethod = Get-MgBetaUserAuthenticationSignInPreference -UserId $UserId

        # Check if the user has a preferred method for secondary authentication
        if ($DefaultMFAMethod.userPreferredMethodForSecondaryAuthentication) {
            # Assign the preferred method to MFAMethod
            $UserMFAPreference = $DefaultMFAMethod.userPreferredMethodForSecondaryAuthentication
            
            # Determine the user-friendly name for the MFA method
            $UserMFAPreference = switch ($DefaultMFAMethod.UserPreferredMethodForSecondaryAuthentication) {
                "push"                 { "Microsoft Authenticator App" }
                "oath"                 { "Authenticator App or Hardware Token" }
                "voiceMobile"          { "Mobile Phone" }
                "voiceAlternateMobile" { "Voice Alternate Mobile Phone" }
                "voiceOffice"          { "Office Phone" }
                "sms"                  { "SMS" }
                default                { "Unknown Method" }
            }
        } else {
            # No preferred method is set
            $UserMFAPreference = "Not Enabled"
        }

        # Return the user's preferred MFA method
        return $UserMFAPreference
    } catch {
        Write-Error "Error fetching MFA preferences: '$_'"
        return "An error occurred while fetching MFA preferences."
    }
}

# Function to get detailed MFA preferences for a user
function Get-UserMFAInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserId
    )

    try {
        # Fetch MFA preferences from Microsoft Graph API
        $DefaultMFAMethod = Get-MgBetaReportAuthenticationMethodUserRegistrationDetail -UserRegistrationDetailsId $UserId

        if ($DefaultMFAMethod.SystemPreferredAuthenticationMethods -and $DefaultMFAMethod.SystemPreferredAuthenticationMethods.Count -gt 0) {
            $SystemMFAPreference = $DefaultMFAMethod.SystemPreferredAuthenticationMethods | ForEach-Object {
                switch ($_){
                    "Sms"                  { "SMS" }
                    "Voice"                { "Mobile Phone" }
                    "PhoneAppNotification" { "Microsoft Authenticator App" }
                    "PhoneAppOTP"          { "Microsoft Authenticator App Code" }
                    "SoftwareOTP"          { "Authenticator App or Hardware Token" }
                    "Fido2"                { "FIDO2 Key" }
                    default                { "Unknown Method" }
                }
            }
        } else {
            # Handle case where SystemPreferredAuthenticationMethods is blank or not configured
            $SystemMFAPreference = "Not Configured"
        }

        return [PSCustomObject]@{
            IsAdmin                       = $DefaultMFAMethod.IsAdmin
            IsMfaCapable                  = $DefaultMFAMethod.IsMfaCapable
            IsMfaRegistered               = $DefaultMFAMethod.IsMfaRegistered
            IsPasswordlessCapable         = $DefaultMFAMethod.IsPasswordlessCapable
            IsSsprCapable                 = $DefaultMFAMethod.IsSsprCapable
            IsSsprEnabled                 = $DefaultMFAMethod.IsSsprEnabled
            IsSsprRegistered              = $DefaultMFAMethod.IsSsprRegistered
            IsSystemMFAPrefernceEnabled   = $DefaultMFAMethod.IsSystemPreferredAuthenticationMethodEnabled
            SystemMFAPreference           = $SystemMFAPreference -Join ', '
        }
    } catch {
        Write-Error "Error fetching MFA preferences for user '$UserId': $_"
        return [PSCustomObject]@{ MFAPreference = "Error occurred while fetching MFA preferences" }
    }
}

# Initialize an array to hold the report data
$ReportData = @()

# Get all users
$Users = Get-MgUser -All -Filter "userType eq 'member'" -Property Id, DisplayName, UserPrincipalName, UserType, Mail, AccountEnabled, CreatedDateTime, OnPremisesSyncEnabled

foreach ($User in $Users) {
    # Process each user as per the logic you have
    $onPremisesStatus = if ($user.OnPremisesSyncEnabled -eq $true) { "Enabled" } else { "Disabled" }

    try {
        # Fetch the authentication methods for the user
        $AuthMethods = Get-AuthMethods -UserId $User.Id

        # Fetch the simplified MFA preference for the user
        $MFAPreference = Get-UserMFAPreference -UserId $User.Id

        # Fetch the detailed MFA info for the user
        $MFAInfo = Get-UserMFAInfo -UserId $User.Id

        # Create a custom object to hold the user's information and authentication details
        $UserReport = [PSCustomObject]@{
            "User DisplayName"           = $User.DisplayName
            "User Id"                    = $User.Id
            "Email"                      = $User.Mail
            "UserPrincipalName"          = $User.UserPrincipalName
            "User Type"                  = $User.UserType
            "Account Enabled"            = $User.AccountEnabled
            "On-Premises Sync Enabled"   = $onPremisesStatus
            "Admin User"                 = $MFAInfo.IsAdmin
            "User MFA Preference"        = $MFAPreference
            "Authentication Methods"     = $AuthMethods
            "MFA Capable"                = $MFAInfo.IsMfaCapable
            "MFA Registered"             = $MFAInfo.IsMfaRegistered
            "Passwordless Capable"       = $MFAInfo.IsPasswordlessCapable
            "SSPR Capable"               = $MFAInfo.IsSsprCapable
            "SSPR Enabled"               = $MFAInfo.IsSsprEnabled
            "SSPR Registered"            = $MFAInfo.IsSsprRegistered
            "System Preference Enabled"  = $MFAInfo.IsSystemMFAPreferenceEnabled
            "System MFA Preference"      = $MFAInfo.SystemMFAPreference
        }

        # Add the user report to the array
        $ReportData += $UserReport
    } catch {
        Write-Error "Error fetching data for user $($User.UserPrincipalName): $_"
    }
}

# Export the report data to a CSV file
$ReportData | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Report generated successfully at: $ExportPath"
