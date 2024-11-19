# Manage Group Member PowerShell Script

This PowerShell script automates Azure Active Directory (AAD) group membership management, allowing administrators to add or remove members efficiently using Microsoft Graph API.

## Features

- **Automated Group Management**: Add or remove members from AAD groups.
- **CSV Support**: Process multiple members via CSV files.
- **Validation**: Ensure correct member formats (UserPrincipalName or DisplayName).
- **Error Handling**: Detailed error messages for troubleshooting.
- **Microsoft Graph Integration**: Utilizes `Microsoft.Graph` PowerShell module for secure operations.

## Installation

### Prerequisites

- PowerShell installed.
- Install `Microsoft.Graph` module:

  ```powershell
  Install-Module -Name Microsoft.Graph -Force
- Download ManageGroupMember.ps1

## Usage
### Parameters
- GroupName: Name of the AAD group to manage.
- Members: List of members (UPN or DisplayName).
- AddMembers: Switch to add members to the group.
- RemoveMembers: Switch to remove members from the group.

### Examples
- Add Members:

  ```powershell
  .\ManageGroupMember.ps1 -GroupName "IT Group" -Members "user1@domain.com", "user2@domain.com" -AddMembers

- Remove Members:

  ```powershell
  .\ManageGroupMember.ps1 -GroupName "IT Group" -Members "user1@domain.com", "user2@domain.com" -RemoveMembers

- Batch Operations with Csv

  ```powershell
  .\ManageGroupMember.ps1 -GroupName "IT Group" -Members .\members.csv -AddMembers
  .\ManageGroupMember.ps1 -GroupName "IT Group" -Members .\members.csv -RemoveMembers

## License

MIT License. See [LICENSE](https://github.com/Sumanjit092/Azure-Active-Directory/blob/main/LICENSE) for details.
