# Azure AD BitLocker Key Export PowerShell Script

## Synopsis

This PowerShell script automates the process of retrieving BitLocker keys from Azure Active Directory for devices with Windows OS. It exports the BitLocker key information along with device details into a CSV file.

## Motivation

The motivation behind this script is to simplify the task of managing BitLocker keys for organizations using Azure Active Directory. By automating the retrieval process, administrators can quickly generate reports and manage BitLocker keys efficiently.

## Features

- Retrieves BitLocker keys from Azure AD for Windows devices.
- Generates a CSV report containing device information and BitLocker key details.
- Supports both interactive and non-interactive (saved credentials) modes.

## Prerequisites

Before using this script, ensure the following prerequisites are met:

- Azure PowerShell module is installed (`Az`).
- Azure Active Directory PowerShell module is installed (`AzureAD`).
- Proper permissions to access Azure AD and retrieve device information.

## Installation

1. Clone the repository to your local machine:

   ```bash
   git clone https://github.com/yourusername/azure-ad-bitlocker-export.git
