# Reset Authentication Methods PowerShell Script

## Synopsis

The Reset Authentication Methods PowerShell Script removes specific user authentication methods within a Microsoft 365 environment. This script is essential for administrators aiming to manage and reset user authentication methods efficiently.

## Description

`ResetAuthenticationMethods.ps1` is a robust PowerShell script designed to manage and reset user authentication methods in Microsoft 365 using the Microsoft Graph API. By connecting to Microsoft Graph with the necessary permissions, the script retrieves and removes the specified authentication methods for a user. It ensures that only the desired authentication methods are reset, logging any errors encountered during execution.

## Parameters

- **UserId** (Mandatory): The ID of the user whose authentication methods need to be reset.

## Usage

1. **Check Internet Connectivity**: The script verifies the internet connection to ensure it can connect to the Microsoft Graph API.

2. **Check Microsoft Graph Module**: The script checks if the Microsoft Graph module is installed. If not, it installs the module.

3. **Connect to Microsoft Graph**: The script connects to the Microsoft Graph PowerShell with the necessary credentials.

4. **Remove Authentication Methods**: The script retrieves all authentication methods for the specified user and removes them, except for password authentication.

5. **Log Errors**: Any errors encountered during the process are logged to a file located in the user's Documents directory.

## Examples

```powershell
# Example usage:
.\ResetAuthenticationMethods.ps1 -UserId "user@example.com"
