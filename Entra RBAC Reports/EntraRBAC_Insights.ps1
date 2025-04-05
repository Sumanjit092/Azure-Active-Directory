<#
.SYNOPSIS
    Generates a comprehensive report of Microsoft Entra role assignments, including 
    eligible and active roles, user and group details, licensing, mailbox status, and 
    sign-in activity.

.DESCRIPTION
    EntraRBAC_Insights.ps1 connects to Microsoft Graph to retrieve both active and eligible 
    Microsoft Entra role assignments. The script supports user and group-based assignments, 
    expanding group members where applicable. It collects additional user properties such 
    as license status, department, mailbox presence, and last sign-in timestamp. The final 
    report is sorted by assigned type and exported to a CSV file. The script includes robust 
    error handling for group lookups and data access, ensuring reliable and consistent output.

.AUTHOR
    Sumanjit Pan

.VERSION
    1.0 - Initial Version

.DATE
    6th April, 2025

.FIRST PUBLISH DATE
    6th April, 2025
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
    if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph" }) {
        Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
        Import-Module -Name 'Microsoft.Graph.Identity.Governance', 'Microsoft.Graph.Users', 'Microsoft.Graph.Groups'
        Write-Host "Microsoft Graph Module is imported." -ForegroundColor Cyan
    } else {
        Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
        Write-Host "Installing Microsoft Graph Module..." -ForegroundColor Yellow
        Install-Module -Name "Microsoft.Graph" -Force
        if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph" }) {
            Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
            Import-Module -Name 'Microsoft.Graph.Identity.Governance', 'Microsoft.Graph.Users', 'Microsoft.Graph.Groups'
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
Write-Host '                             Microsoft Entra Roles & Privileged Access Report                       ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and is offered 'as is' without any warranties of any kind," -ForegroundColor Yellow
Write-Host "whether express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow
Write-Host "fitness for a particular purpose, or non-infringement. Users assume all risks associated with the" -ForegroundColor Yellow
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "This script retrieves and processes comprehensive information about Microsoft Entra role assignments," -ForegroundColor Yellow
Write-Host "including both active and eligible roles. It expands group-based assignments, gathers user and group" -ForegroundColor Yellow
Write-Host "properties like license status, mailbox availability, account status, and last sign-in activity, and" -ForegroundColor Yellow
Write-Host "exports a detailed report to CSV format for further analysis and auditing purposes." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and role management, please visit the following links:" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/entra/roles/permissions-directory" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/directoryrole?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/rolemanagement?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

$documentsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents")
$ExportPath = [System.IO.Path]::Combine($documentsPath, "EntraRBAC_Report.csv")

function Get-UserLicenseInfo {
    param (
        [string]$userId
    )

    $userLicenses = Get-MgUserLicenseDetail -UserId $userId -ErrorAction SilentlyContinue
    $licenseInfo = if ($userLicenses) {
        ($userLicenses | ForEach-Object { $_.SkuPartNumber }) -join ", "
    } else {
        "No Licenses Assigned"
    }
    return $licenseInfo
}

function Get-UserDetails {
    param (
        [string]$userId
    )

    $userInfo = Get-MgUser -UserId $userId -Property AccountEnabled, Mail, Department, SignInActivity -ErrorAction SilentlyContinue
    $accountEnabled = if ($userInfo.AccountEnabled -eq $true) { "Active" } 
    elseif ($userInfo.AccountEnabled -eq $false){ "Disabled" } else { "N/A"}
    $hasMailbox = if ($userInfo.Mail) { "Yes" } else { "No" }
    $Email      = $userInfo.Mail
    $department = $userInfo.Department
    $LastSignIn = ($userInfo | Select-Object -ExpandProperty SignInActivity).LastSignInDateTime

    return @{
        AccountStatus = $accountEnabled
        HasMailbox = $hasMailbox
        Email      = $Email
        Department = $department
        LastSignIn = $LastSignIn
    }
}

# Retrieve eligible and assigned roles
try {
    $eligibleRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty *
    $assignedRoles = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -All -ExpandProperty *
} catch {
    Write-Error "Failed to retrieve roles: $_"
    exit
}

# Combine the roles into a single collection
$allRoles = $eligibleRoles + $assignedRoles

# Initialize the report list
$report = @()

# Start stopwatch
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Initialize progress bar
$totalRoles = $allRoles.Count
$currentIndex = 0

foreach ($role in $allRoles) {
    $currentIndex++
    Write-Progress -Activity "Processing Roles" -Status "Processing role $currentIndex of $totalRoles" -PercentComplete (($currentIndex / $totalRoles) * 100)

    $expirationDate = if ($role.ScheduleInfo.Expiration.EndDateTime) {
        $role.ScheduleInfo.Expiration.EndDateTime
    } else {
        "N/A"
    }

    $assignedTypeValue = $role.Principal.AdditionalProperties.'@odata.type' -replace '^.*\.', ''

    if ($assignedTypeValue -eq "group") {
        $groupId = $role.Principal.Id

        try {
            $group = Get-MgGroup -GroupId $groupId -ErrorAction Stop
            $groupMembers = Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop

            foreach ($groupMember in $groupMembers) {
                $licenseInfo = Get-UserLicenseInfo -userId $groupMember.Id
                $userDetails = Get-UserDetails -userId $groupMember.Id

                $report += [pscustomobject]@{
                    "Assigned"                 = $groupMember.AdditionalProperties.displayName
                    "UserPrincipalName"        = $groupMember.AdditionalProperties.userPrincipalName
                    "Assigned Type"            = "Group"
                    "Group Name"               = $group.DisplayName
                    "Assigned Role"            = $role.RoleDefinition.DisplayName
                    "Assigned Role Scope"      = if ($role.DirectoryScopeId -eq "/"){"Directory"} else {$role.DirectoryScopeId}
                    "Assignment Type"          = if ($role.AssignmentType -eq "Assigned") { "Active" } else { "Eligible" }
                    "Is Built-In"              = if ($role.RoleDefinition.isBuiltIn -eq $true) {"Yes"} else {"No"}
                    "Created Date"             = $role.CreatedDateTime
                    "Expiration Type"          = if ($role.ScheduleInfo.Expiration.type -eq "noExpiration") { "No Expiration" } 
                                                 elseif ($role.ScheduleInfo.Expiration.type -eq "afterDateTime") { "Expiration" } 
                                                 else { "Unknown" }
                    "Expiration Date"          = $expirationDate
                    "Licenses Assigned"        = $licenseInfo
                    "Has Mailbox"              = $userDetails.hasMailbox
                    "Email"                    = $userDetails.Email
                    "Account Status"           = $userDetails.AccountStatus
                    "Account Type"             = $userDetails.Department
                    "Last Sign-In"             = $userDetails.LastSignIn
                }
            }
        } catch {
            Write-Warning "Failed to retrieve group or group members for GroupId $($role.Principal.AdditionalProperties.displayName): $_"
        }

    } else {
        $licenseInfo = Get-UserLicenseInfo -userId $role.Principal.Id
        $userDetails = Get-UserDetails -userId $role.Principal.Id

        $assignedTypeLabel = switch ($assignedTypeValue) {
            "user"             { "User" }
            "servicePrincipal" { "Service Principal" }
            default            { "Unknown" }
        }

        $report += [pscustomobject]@{
            "Assigned"                 = $role.Principal.AdditionalProperties.displayName
            "UserPrincipalName"        = if ($null -ne $role.Principal.AdditionalProperties.userPrincipalName) {
                                            $role.Principal.AdditionalProperties.userPrincipalName } else { "N/A" }
            "Assigned Type"            = $assignedTypeLabel
            "Group Name"               = "N/A"
            "Assigned Role"            = $role.RoleDefinition.DisplayName
            "Assigned Role Scope"      = if ($role.DirectoryScopeId -eq "/"){"Directory"} else {$role.DirectoryScopeId}
            "Assignment Type"          = if ($role.AssignmentType -eq "Assigned") { "Active" } else { "Eligible" }
            "Is Built-In"              = if ($role.RoleDefinition.isBuiltIn -eq $true) {"Yes"} else {"No"}
            "Created Date"             = $role.CreatedDateTime
            "Expiration Type"          = if ($role.ScheduleInfo.Expiration.type -eq "noExpiration") { "No Expiration" } 
                                         elseif ($role.ScheduleInfo.Expiration.type -eq "afterDateTime") { "Expiration" } 
                                         else { "Unknown" }
            "Expiration Date"          = $expirationDate
            "Licenses Assigned"        = $licenseInfo
            "Has Mailbox"              = $userDetails.hasMailbox
            "Email"                    = $userDetails.Email
            "Account Status"           = $userDetails.AccountStatus
            "Account Type"             = $userDetails.Department
            "Last Sign-In"             = $userDetails.LastSignIn
        }
    }
}

# Stop stopwatch
$stopwatch.Stop()

# Check if report is empty
if ($report.Count -eq 0) {
    Write-Output "No data found for any roles."
} else {
    # Sort the report by "Assigned Type" with "Group" entries first
    $sortedReport = $report | Sort-Object -Property @{ Expression = 'Assigned Type'; Descending = $false }, @{
        Expression = { $_ -eq "Group" }; Descending = $false
    }

    # Export the report to CSV
    try {
        $sortedReport | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Output "Report successfully exported to $ExportPath"
    } catch {
        Write-Error "Failed to export CSV: $_"
    }
}
Write-Host ("Script execution completed in {0:D2}h:{1:D2}m:{2:D2}s." -f $stopwatch.Elapsed.Hours, $stopwatch.Elapsed.Minutes, $stopwatch.Elapsed.Seconds)
