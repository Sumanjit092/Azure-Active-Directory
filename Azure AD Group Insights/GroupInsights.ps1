<#
.SYNOPSIS:
    The Group Details Retrieval PowerShell Script automates the process of fetching and processing group information from Microsoft Graph. It allows administrators to filter groups
    based on their synchronization status and export detailed group data to an Excel file. The script also logs any errors encountered during execution.

.DESCRIPTION:
    GroupInsights.ps1 is a PowerShell script designed to connect to Microsoft Graph and retrieve comprehensive details about groups within a Microsoft 365 environment. The script
    supports filtering groups based on whether they are cloud-only or synchronized from on-premises. It collects information about group owners, members, and various group properties,
    and exports this data to an Excel file for further analysis.

.AUTHOR:
    Sumanjit Pan

.VERSION:
    1.0 - Initial Version
    1.1 - Patch Update

.DATE:
    23rd December, 2024

.FIRST PUBLISH DATE:
    23rd December, 2024
#>

param (
    [switch]$CloudOnlyGroup,
    [switch]$OnPremGroup
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
        Import-Module -Name 'Microsoft.Graph.Users', 'Microsoft.Graph.Groups'
        Write-Host "Microsoft Graph Module is imported." -ForegroundColor Cyan
    } else {
        Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
        Write-Host "Installing Microsoft Graph Module..." -ForegroundColor Yellow
        Install-Module -Name "Microsoft.Graph" -Force
        if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph"}) {
            Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
            Import-Module -Name 'Microsoft.Graph.Users', 'Microsoft.Graph.Groups'
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
Write-Host '                                       Group Insight Script                                   ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and on an 'as is' basis without any warranties of any kind," -ForegroundColor Yellow
Write-Host "express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow
Write-Host "fitness for a particular purpose, or non-infringement. The user assumes all risks related to the" -ForegroundColor Yellow
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "The script retrieves and processes group details from Microsoft 365 based on their synchronization" -ForegroundColor Yellow
Write-Host "status. It collects information about group owners, members, and various group properties, and" -ForegroundColor Yellow
Write-Host "exports this data to an Excel file for further analysis. Additionally, it logs any errors encountered" -ForegroundColor Yellow
Write-Host "during execution." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and group management, please visit the following links:" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/group?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/group-list?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/manage-groups?view=o365-worldwide" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

# Define paths for documents and output file
$documentsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents")
$outputFilePath = [System.IO.Path]::Combine($documentsPath, "AllGroups.xlsx")
$logFilePath = [System.IO.Path]::Combine($documentsPath, "GroupDetailsLog.txt")

# Set error action preference to silently continue
$ErrorActionPreference = "SilentlyContinue"

# Function to log errors
function Log-Error {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - ERROR: $message"
    Add-Content -Path $logFilePath -Value $logMessage
}

# Retrieve all groups
try {
    $groups = Get-MgGroup -All -Property DisplayName, Id, Description, Mail, MailNickName, GroupTypes, OnPremisesSyncEnabled,
    CreatedDateTime, SecurityEnabled, MailEnabled, IsAssignableToRole, SecurityIdentifier, MembershipRule, ProxyAddresses,
    ExpirationDateTime, RenewedDateTime
} catch {
    Log-Error "Failed to retrieve groups: $_"
    throw
}

# Filter groups based on the switches
if ($CloudOnlyGroup -and -not $OnPremGroup) {
    $groups = $groups | Where-Object { ($_.OnPremisesSyncEnabled -eq $null) -or ($_.OnPremisesSyncEnabled -ne $true) }
} elseif ($OnPremGroup -and -not $CloudOnlyGroup) {
    $groups = $groups | Where-Object { $_.OnPremisesSyncEnabled -eq $true }
}

# Initialize an empty array to store group details
$groupDetails = @()

# Initialize progress bar
$totalGroups = $groups.Count
$currentGroup = 0

foreach ($group in $groups) {
    $currentGroup++
    Write-Progress -Activity "Processing Groups" -Status "Processing group $currentGroup of $totalGroups" -PercentComplete (($currentGroup / $totalGroups) * 100)

    try {
        # Retrieve the count of owners of the current group
        $owners = Get-MgGroupOwner -GroupId $group.Id -All
        $ownerCount = $owners.count

        # Initialize arrays to hold owner names and UPNs
        $ownerNames = @()
        $ownerUPNs = @()

        # Loop through each owner and collect their information
        foreach ($owner in $owners) {
            $ownerNames += $owner.AdditionalProperties.displayName
            $ownerUPNs += $owner.AdditionalProperties.userPrincipalName
        }

        # Retrieve the count of members of the current group
        $members = Get-MgGroupMember -GroupId $group.Id -All
        $memberCount = $members.count

        # Initialize arrays to hold member names and UPNs
        $memberNames = @()
        $memberUPNs = @()

        # Loop through each member and collect their information
        foreach ($member in $members) {
            $memberNames += $member.AdditionalProperties.displayName
            $memberUPNs += $member.AdditionalProperties.userPrincipalName
        }

        # Expand and process the group type
        $groupTypes = ($group | Select-Object -ExpandProperty GroupTypes)

        # Determine the group type description
        $groupType = if ($groupTypes -contains "Unified") {
            "Office 365 Group"
        } elseif ($groupTypes -contains "DynamicMembership") {
            "Dynamic Security Group"
        } elseif ($null -eq $groupTypes -and $null -ne $group.Mail) {
            "Mail-Enabled Security Group"
        } elseif ($null -eq $groupTypes -and $null -eq $group.Mail) {
            "Security Group"
        } else {
            "Unknown"
        }

        # Determine the group source
        $Source = if ($group.OnPremisesSyncEnabled -eq $true) { 
            "On-Premise Group" 
        } else {
            "Cloud Group"
        }

        # Determine the group security status
        $securityStatus = if ($group.SecurityEnabled -eq $true) {
            "Yes"
        } elseif ($group.SecurityEnabled -eq $false) {
            "No"
        } else {
            "Unknown"
        }

        # Determine the group mail status
        $mailStatus = if ($group.MailEnabled -eq $true) {
            "Yes"
        } elseif ($group.MailEnabled -eq $false) {
            "No"
        } else {
            "Unknown"
        }

         # Determine the group role assignement status
        $roleAssignmentStatus = if ($Group.IsAssignableToRole -eq $true) {
            "Yes"
        } else {
            "No"
        }

        # Get the first audit log entry for the group (customizable: pick properties you want)
        $auditLogEntry = Get-GroupAuditLogEntry -ObjectId $group.Id

        # Collect the group details
        $groupDetail = [PSCustomObject]@{
            "Group Name"           = $group.DisplayName
            "Object Id"            = $group.Id
            "Description"          = $group.Description
            "Group Type"           = $groupType
            "Security Enabled"     = $securityStatus
            "Mail Enabled"         = $mailStatus
            "Mail"                 = $group.Mail
            "Mail Nickname"        = $group.MailNickname
            "Source"               = $Source
            "Security Identifier"  = $group.SecurityIdentifier
            "IsAssignableToRole"   = $roleAssignmentStatus
            "Membership Rule"      = $group.MembershipRule
            "Proxy Addresses"      = ($group | Select-Object -ExpandProperty ProxyAddresses) -join ";"
            "Owner Count"          = $ownerCount
            "Owners Name"          = $ownerNames -join "; "
            "Owners UPN"           = $ownerUPNs -join "; "
            "Member Count"         = $memberCount
            "Members Name"         = $memberNames -join "; "
            "Members UPN"          = $memberUPNs -join "; "
            "Created Date Time"    = $group.CreatedDateTime
            "Expiration Date Time" = $group.ExpirationDateTime
            "Renewed Date Time"    = $group.RenewedDateTime
        }
        $groupDetails += $groupDetail
    } catch {
        Log-Error "Failed to process group $($group.DisplayName): $_"
    }
}

# Output the group details to an Excel file
try {
    # Ensure the ImportExcel module is available
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host "ImportExcel module is not installed. Installing now..." -ForegroundColor Yellow
        Install-Module -Name ImportExcel -Force
    }
    Import-Module -Name ImportExcel

    $groupDetails | Export-Excel -Path $outputFilePath
    Write-Host "Export to Excel completed successfully. File saved at: $outputFilePath" -ForegroundColor Green
} catch {
    Log-Error "Failed to export group details to Excel: $_"
    Write-Host "An error occurred during the export process. Please check the log file for details." -ForegroundColor Red
    throw
}
