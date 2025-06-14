# PowerShell Folder Email Watcher Utility

## Overview

This utility provides automation for monitoring a folder and sending email alerts when new files are detected. It includes:

- **Start-FolderEmailWatcher**: Monitors a folder and sends an email on file creation.
- **Get-CredentialWithFallback**: Retrieves credentials securely from Windows Credential Manager or prompts interactively.

## Requirements

- PowerShell 5.1 or 7+
- CredentialManager module (`Install-Module CredentialManager`)

## Usage

### Store SMTP Credentials

```powershell
$cred = Get-Credential
New-StoredCredential -Target "smtp_emailwatcher" -UserName $cred.UserName -Password $cred.GetNetworkCredential().Password -Persist LocalMachine
```

### Run the Watcher

```powershell
Start-FolderEmailWatcher -WatchPath "C:\Inbound" -CredentialTarget "smtp_emailwatcher"
```

### Parameters

- `WatchPath`: Path to folder to monitor.
- `EmailFrom`: (optional) Sender address. Defaults to `noreply@event-engine.com`.
- `EmailTo`: (optional) Recipient. Defaults to the credential's username.
- `SmtpServer`: SMTP server to use.
- `CredentialTarget`: Credential Manager entry name.

## Packaging Instructions

1. Place the `.ps1` files into a folder.
2. Import as needed or build a module.
3. Add to your `$PROFILE` or scripts for persistent automation.

## License

MIT License — Free for personal and commercial use.
