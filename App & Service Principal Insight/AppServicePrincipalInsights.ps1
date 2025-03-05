<#
.SYNOPSIS:
    The Application and Service Principal Insight PowerShell Script automates the retrieval and processing of detailed information about applications and service principals from
    Microsoft Graph. It enables administrators to gather comprehensive data and export it to a CSV file for further analysis. The script also includes robust error logging to
    ensure thorough tracking and troubleshooting.

.DESCRIPTION:
    AppServicePrincipalInsights.ps1 is a PowerShell script designed to connect to Microsoft Graph and retrieve extensive details about applications and service principals within
    a Microsoft 365 environment. The script collects data on their owners, types, and various properties, and exports this information to a CSV file for further analysis. Additionally,
    it logs any errors encountered during execution to ensure comprehensive tracking and troubleshooting.

.AUTHOR:
    Sumanjit Pan

.VERSION:
    1.0 - Initial Version

.DATE:
    17th January, 2025

.FIRST PUBLISH DATE:
    17th January, 2025
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
        Import-Module -Name 'Microsoft.Graph.Applications', 'Microsoft.Graph.Users'
        Write-Host "Microsoft Graph Module is imported." -ForegroundColor Cyan
    } else {
        Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
        Write-Host "Installing Microsoft Graph Module..." -ForegroundColor Yellow
        Install-Module -Name "Microsoft.Graph" -Force
        if (Get-Module -ListAvailable | Where-Object { $_.Name -like "Microsoft.Graph" }) {
            Write-Host "Microsoft Graph Module is installed." -ForegroundColor Green
            Import-Module -Name 'Microsoft.Graph.Applications', 'Microsoft.Graph.Users'
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
Write-Host '                              Microsoft 365 Application and Service Principal Insight                    ' -ForegroundColor Green
'===================================================================================================='

Write-Host ""
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor Red
Write-Host "===================================================================================================="
Write-Host "This script is provided as freeware and is offered 'as is' without any warranties of any kind," -ForegroundColor Yellow
Write-Host "whether express or implied. This includes, but is not limited to, warranties of defect-free code," -ForegroundColor Yellow
Write-Host "fitness for a particular purpose, or non-infringement. Users assume all risks associated with the" -ForegroundColor Yellow
Write-Host "quality and performance of this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "This script retrieves and processes detailed information about applications and service principals" -ForegroundColor Yellow
Write-Host "from Microsoft 365. It gathers data on their owners, types, and various properties, and exports this" -ForegroundColor Yellow
Write-Host "information to a CSV file for further analysis. Additionally, it logs any errors encountered during" -ForegroundColor Yellow
Write-Host "execution to ensure comprehensive tracking and troubleshooting." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information on Microsoft Graph API and application management, please visit the following links:" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/resources/application?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/graph/api/application-list?view=graph-rest-1.0" -ForegroundColor Yellow
Write-Host "https://learn.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals" -ForegroundColor Yellow
Write-Host "===================================================================================================="
Write-Host ""

CheckInternet
CheckMSGraph

# Define paths for documents and output file
$documentsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents")
$outputFilePath = [System.IO.Path]::Combine($documentsPath, "Application_Report.csv")
$logFilePath = [System.IO.Path]::Combine($documentsPath, "Application_DetailsLog.txt")

# Function to log errors
function Log-Error {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFilePath -Value "$timestamp - $message"
}

# Create a Stopwatch instance
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Create an empty array to store results
$allResults = @()

# Function to process owners
function Process-Owner {
    param (
        [string]$ownerId
    )

    try {
        $ownerDetails = Get-MgUser -UserId $ownerId -ErrorAction Stop
        return [PSCustomObject]@{
            OwnerType              = 'User'
            OwnerDisplayName       = $ownerDetails.DisplayName
            OwnerUserPrincipalName = $ownerDetails.UserPrincipalName
        }
    } catch {
        Log-Error "Failed to get user details for owner ID $($ownerId): $_"
        try {
            $ownerDetails = Get-MgServicePrincipal -ServicePrincipalId $ownerId -ErrorAction Stop
            return [PSCustomObject]@{
                OwnerType              = 'Service Principal'
                OwnerDisplayName       = $ownerDetails.DisplayName
                OwnerUserPrincipalName = $null
            }
        } catch {
            Log-Error "Failed to get service principal details for owner ID $($ownerId): $_"
            Write-Output "Owner not found: $ownerId"
            return $null
        }
    }
}

# Process all applications
$Apps = Get-MgApplication -All
$AppCount = $Apps.Count
$i = 0

foreach ($App in $Apps) {
    try {
        $ownerIds = Get-MgApplicationOwner -ApplicationId $App.Id | Select-Object -ExpandProperty Id
        $ownerDetailsList = @()

        foreach ($ownerId in $ownerIds) {
            $ownerDetails = Process-Owner -ownerId $ownerId
            if ($ownerDetails) {
                $ownerDetailsList += $ownerDetails
            }
        }

        $allResults += [PSCustomObject]@{
            "Name"                     = $App.DisplayName
            "Object Id"                = $App.Id
            "Application Id"           = $App.AppId
            "Account Enabled"          = 'N/A'
            "Type"                     = 'Application'
            "Sub Type"                 = if ($App.PublicClient.RedirectUris -ne $null) { "Public Client/ Native" } else { "Web/ API" }
            "Publisher Domain"         = $App.PublisherDomain
            "SignIn Audience"          = $App.SignInAudience
            "Owner Type"               = if ($ownerIds.Count -eq 0) { 'None' } else { ($ownerDetailsList.OwnerType | Sort-Object -Unique) -join ', ' }
            "Owner DisplayName"        = if ($ownerIds.Count -eq 0) { 'N/A' } else { ($ownerDetailsList.OwnerDisplayName | Sort-Object -Unique) -join ', ' }
            "Owner UserPrincipalName"  = if ($ownerIds.Count -eq 0) { $null } else { ($ownerDetailsList.OwnerUserPrincipalName | Sort-Object -Unique) -join ', ' }
            "Creation Timestamp"       = $App.createdDateTime
        }

        # Update progress
        $i++
        Write-Progress -Activity "Processing Applications" -Status "$i of $AppCount" -PercentComplete (($i / $AppCount) * 100)
    } catch {
        Log-Error "Failed to process application ID $($App.Id): $_"
    }
}

$stopwatch.Stop()  # Stop the stopwatch
$elapsed = $stopwatch.Elapsed
Write-Output ("Time taken to process applications: {0:D2}:{1:D2}:{2:D2}" -f $elapsed.Hours, $elapsed.Minutes, $elapsed.Seconds)

# Process all service principals
$Tenant = (Get-MgDomain | Where-Object { $_.IsInitial -eq $true }).Id
$SPNs = Get-MgServicePrincipal -All
$SPNCount = $SPNs.Count
$i = 0

$stopwatch.Restart()  # Start the stopwatch for service principals processing

foreach ($SPN in $SPNs) {
    try {
        $ownerIds = Get-MgServicePrincipalOwner -ServicePrincipalId $SPN.Id | Select-Object -ExpandProperty Id
        $ownerDetailsList = @()

        foreach ($ownerId in $ownerIds) {
            $ownerDetails = Process-Owner -ownerId $ownerId
            if ($ownerDetails) {
                $ownerDetailsList += $ownerDetails
            }
        }

        $allResults += [PSCustomObject]@{
            "Name"                     = $SPN.DisplayName
            "Object Id"                = $SPN.Id
            "Application Id"           = $SPN.AppId
            "Account Enabled"          = $SPN.AccountEnabled
            "Type"                     = 'Service Principal'
            "Sub Type"                 = $SPN.ServicePrincipalType
            "Publisher Domain"         = $Tenant
            "SignIn Audience"          = 'N/A'
            "Owner Type"               = if ($ownerIds.Count -eq 0) { 'None' } else { ($ownerDetailsList.OwnerType | Sort-Object -Unique) -join ', ' }
            "Owner DisplayName"        = if ($ownerIds.Count -eq 0) { 'N/A' } else { ($ownerDetailsList.OwnerDisplayName | Sort-Object -Unique) -join ', ' }
            "Owner UserPrincipalName"  = if ($ownerIds.Count -eq 0) { $null } else { ($ownerDetailsList.OwnerUserPrincipalName | Sort-Object -Unique) -join ', ' }
            "Creation Timestamp"       = ([datetime]::Parse($SPN.AdditionalProperties.createdDateTime)).ToString("M/d/yyyy HH:mm:ss")
        }

        # Update progress
        $i++
        Write-Progress -Activity "Processing Service Principals" -Status "$i of $SPNCount" -PercentComplete (($i / $SPNCount) * 100)
    } catch {
        Log-Error "Failed to process service principal ID $($SPN.Id): $_"
    }
}

$stopwatch.Stop()  # Stop the stopwatch
$elapsed = $stopwatch.Elapsed
Write-Output ("Time taken to process service principals: {0:D2}:{1:D2}:{2:D2}" -f $elapsed.Hours, $elapsed.Minutes, $elapsed.Seconds)

# Export results
$allResults | Export-Csv -Path $outputFilePath -NoTypeInformation

# Complete progress
Write-Progress -Activity "Processing Complete" -Completed
