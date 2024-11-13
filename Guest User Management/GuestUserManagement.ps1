<#

.SYNOPSIS:
    The Guest User Management PowerShell Script facilitates the administration of guest users within a Microsoft 365 environment. It allows administrators to identify and
    handle inactive guest accounts, based on their sign-in activity and synchronization status. The script supports disabling or removing users, as well as filtering between
    cloud-only and on-premises synchronized accounts. It generates detailed reports for disabled users, removed users, and inactive users, and logs any errors encountered
    during execution.

.DESCRIPTION:
    GuestUserManagement.ps1 is a PowerShell script designed to manage guest users in Microsoft 365 through the Microsoft Graph API. It connects to Microsoft Graph with appropriate
    permissions and retrieves guest user information. The script filters users based on activity, synchronization status, and specified parameters. Users who have been inactive for
    a defined period or have no sign-in records are processed for disabling or removal.

.AUTHOR:
    Sumanjit Pan

.VERSION:
    1.0 - Intitial Version
    1.1 - Patch: Account Creation Threshold Days

.DATE:
    13th November, 2024

.FIRST PUBLISH DATE:
    6th September, 2024

#>

param (
    [switch]$Remove,
    [switch]$Disable,
    [switch]$CloudOnlyAccount,
    [switch]$OnPremAccount
)

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
                            
    if (Get-Module -ListAvailable | Where-Object {$_.Name -like "Microsoft.Graph"}) 
    {
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Identity.DirectoryManagement'
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
    ''
    Write-Host "Installing Microsoft Graph Module....." -ForegroundColor Yellow
    Install-Module -Name "Microsoft.Graph" -Force
                                
    if (Get-Module -ListAvailable | Where-Object {$_.Name -like "Microsoft.Graph"}) {                                
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Identity.DirectoryManagement'
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    ''
    ''
    Write-Host "Operation aborted. Microsoft Graph Module was not installed." -ForegroundColor Red
    Exit}
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
Write-Host '                                  Guest User Management Script                                                 ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red 
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and on an 'as is' basis without any warranties of any kind," -ForegroundColor Yellow 
Write-Host "express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow 
Write-Host "fitness for a particular purpose, or non-infringement. The user assumes all risks related to the" -ForegroundColor Yellow 
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "The script identifies and processes guest users in Microsoft 365 based on their activity and" -ForegroundColor Yellow 
Write-Host "synchronization status. It can disable or remove users, filter based on account type, and generates" -ForegroundColor Yellow
Write-Host "reports for disabled and removed users. Additionally, it logs any errors encountered during execution." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and user management, please visit the following links:" -ForegroundColor Yellow 
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/user?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/user-delete?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/microsoft-365/admin/add-users/about-guest-users?view=o365-worldwide" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

# Define paths for the reports and error log in the Documents folder
$documentsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents")
$disabledReportPath = [System.IO.Path]::Combine($documentsPath, "DisabledUsersReport.csv")
$removedReportPath = [System.IO.Path]::Combine($documentsPath, "RemovedUsersReport.csv")
$inactiveReportPath = [System.IO.Path]::Combine($documentsPath, "InactiveUsersReport.csv")
$errorLogPath = [System.IO.Path]::Combine($documentsPath, "ErrorLog.txt")

# Function to log errors
function Log-Error {
    param (
        [string]$Message
    )
    $timestamp = (Get-Date -AsUTC)
    $logEntry = "$timestamp - ERROR: $Message"
    Add-Content -Path $errorLogPath -Value $logEntry
}

# Define the number of days after which guest users are considered inactive
$inactiveThresholdDays = 90
$accountCreationThresholdDays = 90

# Get today's date in UTC
$today = Get-Date -AsUTC

# Initialize lists and map
$usersToDisable = @()
$usersToRemove = @()
$invitesMap = @{}

# Get all guest users
try {
    $guestUsers = Get-MgUser -All -Filter "userType eq 'Guest'" -Property Id, DisplayName, UserPrincipalName, UserType, SignInActivity, Mail, AccountEnabled, CreatedDateTime, OnPremisesSyncEnabled
} catch {
    Log-Error "Failed to retrieve guest users: $_"
    exit
}

# Filter guest users based on the switches
if ($CloudOnlyAccount -and -not $OnPremAccount) {
    $guestUsers = $guestUsers | Where-Object { ($_.OnPremisesSyncEnabled -eq $null) -or ($_.OnPremisesSyncEnabled -ne $true) }
} elseif ($OnPremAccount -and -not $CloudOnlyAccount) {
    $guestUsers = $guestUsers | Where-Object { $_.OnPremisesSyncEnabled -eq $true }
}

Write-Host "Filtered guest users: $($guestUsers.Count)" -ForegroundColor Cyan

# Get all pending and accepted invitations
try {
    $pendingInvites = Get-MgUser -All -Filter "externalUserState eq 'PendingAcceptance'"
    $acceptedInvites = Get-MgUser -All -Filter "externalUserState eq 'Accepted'"
} catch {
    Write-Error "Failed to retrieve invitations: $_"
    exit
}

# Populate invites map
foreach ($invite in $pendingInvites) {
    $invitesMap[$invite.Id] = "PendingAcceptance"
}
foreach ($invite in $acceptedInvites) {
    $invitesMap[$invite.Id] = "Accepted"
}

# Process each guest user
foreach ($user in $guestUsers) {
    # Check if the account creation date is older than the threshold
    $accountCreationDate = $user.CreatedDateTime
    $daysSinceAccountCreation = if ($accountCreationDate) { ($today - [DateTime]$accountCreationDate).Days } else { $null }

    # Skip users whose account was created less than $accountCreationThresholdDays ago
    if ($daysSinceAccountCreation -lt $accountCreationThresholdDays) {
        Write-Host "User $($user.UserPrincipalName) was created less than $accountCreationThresholdDays days ago, skipping." -ForegroundColor Yellow
        continue  # Skip this user from further processing
    }

    # If account is old enough, proceed with inactivity check
    $signInDate = $user.SignInActivity.LastSignInDateTime
    $daysSinceLastSignIn = if ($signInDate) { ($today - [DateTime]$signInDate).Days } else { $null }
    $onPremisesStatus = if ($user.OnPremisesSyncEnabled -eq $true) { "Enabled" } else { "Disabled" }

    # Create a custom object with user details
    $userDetails = [PSCustomObject]@{
        DisplayName            = $user.DisplayName
        UPN                    = $user.UserPrincipalName
        ObjectId               = $user.Id
        AccountEnabled         = $user.AccountEnabled
        Email                  = $user.Mail
        CreationDate           = $user.CreatedDateTime
        LastSignIn             = if ($signInDate) { $signInDate } else { "No sign-in records available" }
        DaysSinceLastSignIn    = if ($signInDate) { $daysSinceLastSignIn } else { "No sign-in records available" }
        UserType               = $user.UserType
        OnPremisesSyncEnabled  = $onPremisesStatus
        ExternalUserState      = $invitesMap[$user.Id]
    }

    # Check if the user should be disabled
    if ($signInDate -and $daysSinceLastSignIn -ge $inactiveThresholdDays) {
        Write-Host "User $($user.UserPrincipalName) has been inactive for $daysSinceLastSignIn days." -ForegroundColor Yellow
        $usersToDisable += $userDetails
    } elseif (-not $signInDate) {
        Write-Host "User $($user.UserPrincipalName) has no sign-in records." -ForegroundColor Magenta
        $usersToDisable += $userDetails
    }
}

# Process users based on action switches
foreach ($user in $usersToDisable) {
    if ($user.ObjectId) {
        try {
            if ($Disable) {
                # Disable user
                Update-MgUser -UserId $user.ObjectId -AccountEnabled:$false
                Write-Host "Disabled user $($user.UPN)." -ForegroundColor Red
            }

            if ($Remove) {
                # Fetch user details to confirm the user is disabled
                $userDetails = Get-MgUser -UserId $user.ObjectId -Property AccountEnabled
                if (-not $userDetails.AccountEnabled) {
                    Write-Host "Removing disabled user $($user.UPN)." -ForegroundColor Yellow
                    Remove-MgUser -UserId $user.ObjectId
                    Write-Host "Removed user $($user.UPN)." -ForegroundColor Red
                    $usersToRemove += $user
                }
            }
        } catch {
            Log-Error "Failed to process user $($user.UPN): $_"
        }
    } else {
        Write-Warning "User $($user.UPN) has an empty ObjectId and cannot be processed."
        Log-Error "User $($user.UPN) has an empty ObjectId and cannot be processed."
    }
}

# Generate the appropriate report based on actions performed
if ($Disable) {
    $usersToDisable | Export-Csv -Path $disabledReportPath -NoTypeInformation
    Write-Host "Disabled users report generated at: $disabledReportPath" -ForegroundColor Green
}

if ($Remove) {
    $usersToRemove | Export-Csv -Path $removedReportPath -NoTypeInformation
    Write-Host "Removed users report generated at: $removedReportPath" -ForegroundColor Green
}

# Generate Inactive Users Report if neither Disable nor Remove is specified
if (-not $Disable -and -not $Remove) {
    $usersToDisable | Export-Csv -Path $inactiveReportPath -NoTypeInformation
    Write-Host "Inactive users report generated at: $inactiveReportPath" -ForegroundColor Green
}
