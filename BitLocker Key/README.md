# Export-Azure-AD-Device-BitLocker-Key #

.\ExportBitLockerKey.ps1 provides the capability to Extract Device BitLocker Key avaiable on Azure Ad.

BitLocker is an in built encryption feature that has been included with all versions of Windows since Vista. It is designed to protect your files and data from unauthorized access by encrypting your entire hard drive. The encrypted drive can only be accessed with a password or a smart card that you set up when you turned on Bitlocker Drive Encryption on that drive. If anyone tries to access your encrypted drive without proper authentication, access is denied.

BitLocker Drive Encryption is a data protection feature that integrates with the operating system and addresses the threats of data theft or exposure from lost, stolen, or inappropriately decommissioned computers.

BitLocker provides the most protection when used with a Trusted Platform Module (TPM) version 1.2 or later. The TPM is a hardware component installed in many newer computers by the computer manufacturers. It works with BitLocker to help protect user data and to ensure that a computer has not been tampered with while the system was offline.

For more information, kindly visit the link: https://docs.microsoft.com/en-us/windows/security/information-protection/bitlocker/bitlocker-overview

Run Powershell as Elevated User.
To run the PowerShell window with elevated permissions just click Start then type PowerShell then Right-Click on PowerShell icon and select Run as Administrator.

.\ExportBitLockerKey.ps1 will check for Azure Resource Module. If module is not installed it will Install module. Then,
.\ExportBitLockerKey.ps1 will prompt you to enter your Azure Tenant credentials.

Additionally, .\ExportBitLockerKey.ps1 will check for AzureAd Module. If module is not installed it will Install module. Then,
.\ExportBitLockerKey.ps1 will prompt you to enter your Azure Tenant credentials.

You must have read access to your organization Azure Resource Subscription. Also, you should have Gloabal Reader Permission on Azure Ad.

After successful login, .\ExportBitLockerKey.ps1 will Export BitLockerReport.Csv Report under "C:\Temp\" Folder. Report export can take few hours depending on total number of device in AzureAd.

Report contains DeviceName, DriveType, KeyID, RecoveryKey, OwnerUserPrincipalName, OwnerDisplayName, CompanyName

Important Notes:
This source code is freeware and is provided on an "as is" basis without warranties of any kind, whether express or implied, including without limitation warranties that the code is free of defect, fit for a particular purpose or non-infringing. The entire risk as to the quality and performance of the code is with the end user.

If you have any question, suggestion or issue with this script please feel free to leave comments.

