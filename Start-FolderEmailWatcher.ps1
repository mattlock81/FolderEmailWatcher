
function Start-FolderEmailWatcher {
    <#
    .SYNOPSIS
        Monitors a specified folder for newly created files and sends an email notification when a new file is detected.

    .DESCRIPTION
        This function uses the FileSystemWatcher .NET object to monitor file system changes. When a new file is created,
        an email is sent to a specified recipient using the stored SMTP credentials from Windows Credential Manager.

        The function also ensures clean-up of event registrations when the session exits or when Ctrl+C is pressed.

    .PARAMETER WatchPath
        The full path to the folder to monitor. Default is 'Drive:\PathToWatchFolder'.

    .PARAMETER EmailFrom
        The sender email address. If not provided, defaults to 'noreply@event-engine.com'.

    .PARAMETER EmailTo
        The recipient email address. If not provided, defaults to the username from the stored credential.

    .PARAMETER SmtpServer
        The SMTP server address. Default is 'smtp.internal.corp.net'.

    .PARAMETER SmtpPort
        The port to use for SMTP communication. Default is 587.

    .PARAMETER UseSsl
        Indicates whether SSL should be used. Default is $true.

    .PARAMETER CredentialTarget
        The name of the stored credential in Windows Credential Manager.

    .EXAMPLE
        Start-FolderEmailWatcher -WatchPath 'C:\Shared\DropFolder' -CredentialTarget 'corp_smtp'

        Starts watching the specified path using credentials stored under 'corp_smtp'.

    .EXAMPLE
        Start-FolderEmailWatcher -EmailTo 'alerts@domain.com' -EmailFrom 'service@domain.com'

        Sends notifications to 'alerts@domain.com' using the specified sender address.

    #>
    [CmdletBinding()]
    param (
        [string]$WatchPath = 'Drive:\PathToWatchFolder',
        [string]$EmailFrom = '',
        [string]$EmailTo = '',
        [string]$SmtpServer = 'smtp.internal.corp.net',
        [int]$SmtpPort = 587,
        [switch]$UseSsl = $true,
        [string]$CredentialTarget = 'smtp_emailwatcher'
    )

    # Retrieve credential securely
    try {
        $Credential = Get-CredentialWithFallback -Target $CredentialTarget
        if (-not $Credential) {
            throw "No usable credentials retrieved."
        }
    } catch {
        Write-Warning "Credential loading failed: $_"
        return
    }

    if ([string]::IsNullOrWhiteSpace($EmailTo)) {
        $EmailTo = $Credential.UserName
        Write-Verbose "EmailTo not provided. Using credential username: $EmailTo"
    }

    if ([string]::IsNullOrWhiteSpace($EmailFrom)) {
        $EmailFrom = 'noreply@event-engine.com'
        Write-Verbose "EmailFrom not provided. Using default: $EmailFrom"
    }

    Write-Host "Watcher config: From=$EmailFrom To=$EmailTo Server=$SmtpServer"

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $WatchPath
    $watcher.Filter = '*.*'
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    $sourceId = 'Watcher.NewFile'

    try {
        Register-ObjectEvent -InputObject $watcher -EventName 'Created' -SourceIdentifier $sourceId -MessageData @{
            EmailFrom   = $EmailFrom
            EmailTo     = $EmailTo
            SmtpServer  = $SmtpServer
            SmtpPort    = $SmtpPort
            UseSsl      = $UseSsl
            Credential  = $Credential
        } -Action {
            try {
                $config = $event.MessageData
                $filePath = $Event.SourceEventArgs.FullPath
                $subject = "New File Detected: $($filePath)"
                $body = "A new file was created: $($filePath) at $(Get-Date)"

                Send-MailMessage -From $config.EmailFrom -To $config.EmailTo -Subject $subject -Body $body `
                    -SmtpServer $config.SmtpServer -Port $config.SmtpPort -UseSsl:$config.UseSsl -Credential $config.Credential

                Write-Host "[$(Get-Date -Format 'T')] Email sent for: $filePath"
            } catch {
                Write-Warning "[$(Get-Date -Format 'T')] Email send failed: $_"
            }
        }

        Write-Host "[$(Get-Date -Format 'T')] Watching: $WatchPath. Press Ctrl+C to stop."
    } catch {
        Write-Error "[$(Get-Date -Format 'T')] Failed to register watcher: $_"
        return
    }

    $cancelSource = [System.Threading.CancellationTokenSource]::new()

    $null = Register-EngineEvent -SourceIdentifier 'PowerShell.Exiting' -Action {
        try {
            Unregister-Event -SourceIdentifier 'Watcher.NewFile' -ErrorAction SilentlyContinue
            Remove-Event -SourceIdentifier 'Watcher.NewFile' -ErrorAction SilentlyContinue
            Write-Host "[$(Get-Date -Format 'T')] Watcher cleaned up (PowerShell.Exiting)."
        } catch {
            Write-Warning "Failed to unregister watcher on PowerShell exit: $_"
        }
    }

    try {
        while (-not $cancelSource.IsCancellationRequested) {
            Start-Sleep -Seconds 1
        }
    } catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host "`nCtrl+C detected. Cleaning up..."
    } finally {
        try {
            $cancelSource.Cancel()
            Unregister-Event -SourceIdentifier 'Watcher.NewFile' -ErrorAction SilentlyContinue
            Remove-Event -SourceIdentifier 'Watcher.NewFile' -ErrorAction SilentlyContinue
            Write-Host "Watcher stopped."
        } catch {
            Write-Warning "Final cleanup failed: $_"
        }
    }
}
