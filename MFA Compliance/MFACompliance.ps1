param (
    [switch]$CloudOnlyAccount,
    [switch]$OnPremAccount
)

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
            IsMfaRegistered               = $DefaultMFAMethod.IsMfaRegistered
            SystemMFAPreference           = $SystemMFAPreference -Join ', '
        }
    } catch {
        Write-Error "Error fetching MFA preferences for user '$UserId': $_"
        return [PSCustomObject]@{ MFAPreference = "Error occurred while fetching MFA preferences" }
    }
}

# Function to fetch authentication methods for a user
function Get-AuthMethods {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserId
    )

    $AllMethods = @()  # Initialize an empty array to hold method descriptions

    try {
        # Fetch the user's authentication methods from Microsoft Graph
        $AuthMethods = Get-MgBetaUserAuthenticationMethod -UserId $UserId
        
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

# Function to fetch sign-in activity for a user
function Get-SignInActivity {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserId,
        [Parameter(Mandatory = $false)]
        [int]$Top = 30
    )
    try {
        # Fetch sign-in activity from the last 30 days
        $Date30DaysAgo = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $SignIns = Get-MgAuditLogSignIn -Filter "userPrincipalName eq '$UserId' and createdDateTime ge $Date30DaysAgo" -Top $Top
        return $SignIns
    } catch {
        Write-Error "Error fetching sign-in activity for user '$UserId': $_"
        return @()  # Return an empty array instead of null
    }
}

# Function to fetch user risk status
function Get-RiskyUserStatus {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserId
    )

    try {
        # Ensure the UserId is valid
        if (-not $UserId) {
            Write-Error "UserId is missing or invalid."
            return "Invalid UserId."
        }

        # Fetch the risky user status from Microsoft Graph
        $RiskyUser = Get-MgRiskyUser -RiskyUserId $UserId -ErrorAction SilentlyContinue

        # Check if RiskyUser was found
        if ($RiskyUser) {
            # Map the riskLevel to a concise message
            $RiskLevelMessage = switch ($RiskyUser.riskLevel) {
                "low" { "Low Risk: Minimal suspicious activity." }
                "medium" { "Medium Risk: Unusual behavior detected." }
                "high" { "High Risk: Potential compromise detected." }
                "hidden" { "Risk level is hidden." }
                "none" { "No Risk: No suspicious activity." }
                "unknownFutureValue" { "Risk level unknown or may change." }
                default { "Unknown risk level." }
            }

            # Map the riskState to a concise message
            $RiskStateMessage = switch ($RiskyUser.riskState) {
                "none" { "No action needed." }
                "confirmedSafe" { "Account safe." }
                "remediated" { "Risk resolved." }
                "dismissed" { "Risk dismissed." }
                "atRisk" { "User at risk." }
                "confirmedCompromised" { "Account compromised." }
                "unknownFutureValue" { "Risk state unknown." }
                default { "Unknown state." }
            }

            # Return both riskLevel and riskState messages
            return "$RiskLevelMessage`n$RiskStateMessage"
        } else {
            return "No Risk: No risky user found."
        }
    } catch {
        # Handle errors in fetching risk status
        Write-Error "Error fetching risk status for user '$UserId': $_"
        return "Error occurred while fetching risk status."
    }
}


# Initialize report data collection
$ReportData = @()

# Fetch all users in one go to reduce API calls
$Users = Get-MgUser -All -Filter "userType eq 'member'" -Property Id, DisplayName, UserPrincipalName, UserType, Mail, AccountEnabled, CreatedDateTime, OnPremisesSyncEnabled

# Filter users based on the switches
if ($CloudOnlyAccount -and -not $OnPremAccount) {
    $Users = $Users | Where-Object { ($_.OnPremisesSyncEnabled -eq $null) -or ($_.OnPremisesSyncEnabled -ne $true) }
} elseif ($OnPremAccount -and -not $CloudOnlyAccount) {
    $Users = $Users | Where-Object { $_.OnPremisesSyncEnabled -eq $true }
}

foreach ($User in $Users) {
    try {
        $AuthMethods = Get-AuthMethods -UserId $User.Id
        $MFAInfo = Get-UserMFAInfo -UserId $User.Id
        $SignInActivity = Get-SignInActivity -UserId $User.UserPrincipalName -Top 30
        
        # Fetch User Risk Status
        $UserRiskStatus = Get-RiskyUserStatus -UserId $User.Id

        # Check for Risk Level and State
        $RiskLevel = if ($UserRiskStatus) { ($UserRiskStatus.Split("`n")[0]) } else { "No Risk" }
        $RiskState = if ($UserRiskStatus) { ($UserRiskStatus.Split("`n")[1]) } else { "No Risk State" }

        $ConditionalAccessStatus = if ($SignInActivity) { ($SignInActivity | Select-Object -First 1).conditionalAccessStatus } else { "No sign-in data" }
        
        # Fetch the conditional access policies and display "Not Applied" if none are found
        $ConditionalAccessPolicies = if ($SignInActivity) {
            $AppliedPolicies = $SignInActivity | ForEach-Object {
                $_.AppliedConditionalAccessPolicies | Where-Object { $_.Result -eq 'Applied' }
            }

            # If policies were applied, return their DisplayNames
            $PolicyNames = $AppliedPolicies | ForEach-Object { $_.DisplayName }
            if ($PolicyNames.Count -gt 0) {
                $PolicyNames -join ', '
            } else {
                "Not Applied"
            }
        } else {
            "No sign-in data"
        }

        # Create a custom object for the user
        $UserReport = [PSCustomObject]@{
            "User Display Name"          = $User.DisplayName
            "User Id"                    = $User.Id
            "Email"                      = $User.Mail
            "UserPrincipalName"          = $User.UserPrincipalName
            "User Type"                  = $User.UserType
            "Account Enabled"            = $User.AccountEnabled
            "On-Premises Sync Enabled"   = if ($User.OnPremisesSyncEnabled -eq $true) { "Enabled" } else { "Disabled" }
            "MFA Registration Status"    = $MFAInfo.IsMfaRegistered
            "Authentication Methods"     = $AuthMethods
            "System MFA Preference"      = $MFAInfo.SystemMFAPreference
            "User Risk Level"            = $RiskLevel
            "User Risk State"            = $RiskState
            "Conditional Access Status"  = $ConditionalAccessStatus
            "Conditional Access Policies"= $ConditionalAccessPolicies
            "Interactive Sign-In"        = ($SignInActivity | Select-Object -First 1).isInteractive
            "Sign-In App Display Name"   = ($SignInActivity | Select-Object -First 1).appDisplayName
            "Client App Used"            = ($SignInActivity | Select-Object -First 1).clientAppUsed
            "Sign-In IP Address"         = ($SignInActivity | Select-Object -First 1).ipAddress
            "Last Sign In"               = if ($SignInActivity) { ($SignInActivity | Select-Object -First 1).createdDateTime } else { "No sign-in records available" }
            "Authentication Gaps"        = if ($MFAInfo.IsMfaRegistered -eq $false) { "Non-Compliant" } else { "Compliant" }
        }

        $ReportData += $UserReport
    } catch {
        Write-Error "Error fetching data for user $($User.UserPrincipalName): $_"
    }
}

# Export to CSV
$documentsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Documents")
$ExportPath = [System.IO.Path]::Combine($documentsPath, "UserAuthenticationReport_Last30Days.csv")
$ReportData | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Report generated successfully at: $ExportPath"
