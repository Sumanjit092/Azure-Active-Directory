<#
.SYNOPSIS
    Manage Group Member PowerShell script manages membership of a Azure Active Directory group by automating the addition or removal of members based
    on direct input or from a CSV file.

.Description
    The Manage Group Member PowerShell script (./Manage-GroupMember.ps1) streamlines administrative tasks for Azure Active Directory group memberships.
    It processes member information from either direct inputs or CSV files, validating each member's DisplayName or UserPrincipalName format
    to ensure compliance. Utilizing Azure Active Directory integration, the script performs secure operations to add or remove members as specified.
    Whether managing individual member actions or batch operations through CSV files, this tool supports efficient and effective group membership management.

.Author
    Sumanjit Pan

.Version
    1.0

.Date
    2nd July, 2024

.First Publish Date
    2nd July, 2024
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$GroupName,
    
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$Members,
    
    [switch]$AddMembers,
    [switch]$RemoveMembers
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
    Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Groups','Microsoft.Graph.Identity.DirectoryManagement'
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
    Import-Module -Name 'Microsoft.Graph.Users','Microsoft.Graph.Groups','Microsoft.Graph.Identity.DirectoryManagement'
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

Connect-MgGraph -NoWelcome

$MgContext= Get-mgContext

Write-Host "User '$($MgContext.Account)' has connected to TenantId '$($MgContext.TenantId)' Microsoft Graph API successfully." -ForegroundColor Green
''
''
}

Cls
'===================================================================================================='
Write-Host '                              Manage Group Member PowerShell Script                              ' -ForegroundColor Green
'===================================================================================================='

''                    
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red 
Write-Host "===================================================================================================="
Write-Host "This source code is freeware and is provided on an 'as is' basis without warranties of any kind," -ForegroundColor Yellow 
Write-Host "whether express or implied, including without limitation warranties that the code is free of defect," -ForegroundColor Yellow 
Write-Host "fit for a particular purpose or non-infringing. The entire risk as to the quality and performance of" -ForegroundColor Yellow 
Write-Host "the code is with the end user." -ForegroundColor Yellow 
''
Write-Host "This script manages Azure Active Directory group memberships by automating member addition or removal." -ForegroundColor Yellow
Write-Host "It validates member formats (DisplayName or UserPrincipalName) and utilizes Azure Active Directory" -ForegroundColor Yellow
Write-Host "integration for secure operations." -ForegroundColor Yellow
''
Write-Host "For more information on managing Azure Active Directory groups, visit:" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/entra/fundamentals/how-to-manage-groups" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/entra/identity/users/groups-settings-v2-cmdlets" -ForegroundColor Yellow
Write-Host "===================================================================================================="
''
CheckInternet
CheckMSGraph

# Function to validate DisplayName or UserPrincipalName format for Azure Active Directory members
function Test-AadMemberNameFormat {
    param([string]$Name)
    
    # Check if the name contains "@" to identify it as a UserPrincipalName
    if ($Name -match '@') {
        return $true
    }

    # Regular expression pattern to match valid DisplayName
    $Pattern = '^[a-zA-Z0-9\s\(\)\[\]\{\}\-_,.\'']+$'
    
    return $Name -match $Pattern
}

# Function to get group by display name
function Get-Group {
    param([string]$GroupName)
    
    try {
        Get-MgGroup -Filter "DisplayName eq '$GroupName'" -ErrorAction Stop
    }
    catch {
        Write-Host "Group '$GroupName' not found." -ForegroundColor Red
        return $null
    }
}

# Function to add member to a group
function Add-MemberToGroup {
    param(
        [string]$GroupName,
        [string]$MemberName
    )

    $Group = Get-Group -GroupName $GroupName
    if ($Group) {
        try {
            # Determine the member type (UserPrincipalName or DisplayName)
            if ($MemberName -match '@') {
                $MemberObject = Get-MgUser -UserId $MemberName -ErrorAction Stop
            } else {
                $MemberObject = Get-MgUser -Filter "DisplayName eq '$MemberName'" -ErrorAction Stop
                if (-not $MemberObject) {
                    $MemberObject = Get-MgDevice -Filter "DisplayName eq '$MemberName'" -ErrorAction Stop
                }
            }

            New-MgGroupMember -GroupId $Group.Id -DirectoryObjectId $MemberObject.Id
            Write-Host "Added member '$MemberName' to group '$GroupName'." -ForegroundColor Green
        }
        catch {
            Write-Host "Error adding member '$MemberName' to group '$GroupName': $_" -ForegroundColor Red
        }
    }
}

# Function to remove member from a group
function Remove-MemberFromGroup {
    param(
        [string]$GroupName,
        [string]$MemberName
    )

    $Group = Get-Group -GroupName $GroupName
    if ($Group) {
        try {
            # Determine the member type (UserPrincipalName or DisplayName)
            if ($MemberName -match '@') {
                $MemberObject = Get-MgUser -UserId $MemberName -ErrorAction Stop
            } else {
                $MemberObject = Get-MgUser -Filter "DisplayName eq '$MemberName'" -ErrorAction Stop
                if (-not $MemberObject) {
                    $MemberObject = Get-MgDevice -Filter "DisplayName eq '$MemberName'" -ErrorAction Stop
                }
            }

            Remove-MgGroupMemberByRef -GroupId $Group.Id -DirectoryObjectId $MemberObject.Id
            Write-Host "Removed member '$MemberName' from group '$GroupName'." -ForegroundColor Green
        }
        catch {
            Write-Host "Error removing member '$MemberName' from group '$GroupName': $_" -ForegroundColor Red
        }
    }
}

# Process each member from pipeline or direct input
foreach ($Member in $Members) {
    if (Test-Path $Member -PathType Leaf) {
        # If member is a valid path to a CSV file, process CSV
        Import-Csv -Path $Member | ForEach-Object {
            if ($_.UPN -and (Test-AadMemberNameFormat $_.UPN)) {
                Write-Host "UserPrincipalName '$($_.UPN)' is valid." -ForegroundColor Cyan
                if ($RemoveMembers) {
                    Remove-MemberFromGroup -GroupName $GroupName -MemberName $_.UPN
                } elseif ($AddMembers) {
                    Add-MemberToGroup -GroupName $GroupName -MemberName $_.UPN
                }
            } elseif ($_.UPN) {
                Write-Host "Invalid UserPrincipalName: '$($_.UPN)'." -ForegroundColor Yellow
            }

            if ($_.DisplayName -and (Test-AadMemberNameFormat $_.DisplayName)) {
                Write-Host "DisplayName '$($_.DisplayName)' is valid." -ForegroundColor Cyan
                if ($RemoveMembers) {
                    Remove-MemberFromGroup -GroupName $GroupName -MemberName $_.DisplayName
                } elseif ($AddMembers) {
                    Add-MemberToGroup -GroupName $GroupName -MemberName $_.DisplayName
                }
            } elseif ($_.DisplayName) {
                Write-Host "Invalid DisplayName: '$($_.DisplayName)'." -ForegroundColor Yellow
            }
        }
    } elseif (Test-AadMemberNameFormat $Member) {
        # Process each member directly provided
        Write-Host "Member '$Member' is valid." -ForegroundColor Cyan
        if ($RemoveMembers) {
            Remove-MemberFromGroup -GroupName $GroupName -MemberName $Member
        } elseif ($AddMembers) {
            Add-MemberToGroup -GroupName $GroupName -MemberName $Member
        }
    } else {
        Write-Host "Invalid member: '$Member'." -ForegroundColor Yellow
    }
}
