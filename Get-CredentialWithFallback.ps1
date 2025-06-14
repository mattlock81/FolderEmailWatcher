
function Get-CredentialWithFallback {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Target
    )

    # Ensure CredentialManager module is loaded
    if (-not (Get-Module -Name CredentialManager)) {
        try {
            Import-Module CredentialManager -ErrorAction Stop
        } catch {
            Write-Warning "CredentialManager module is not installed or failed to load."
            return $null
        }
    }

    # Attempt to get stored credential
    try {
        $stored = CredentialManager\Get-StoredCredential -Target $Target
        if ($stored) {
            Write-Verbose "Successfully retrieved stored credential for '$Target'."
            return $stored
        } else {
            Write-Warning "No stored credential found for '$Target'."
        }
    } catch {
        Write-Warning "Error retrieving stored credential: $_"
    }

    # Fallback: prompt user interactively
    try {
        $username = Read-Host "Enter username for $Target"
        $prompted = Get-Credential -UserName $username -Message "Enter password for $Target"

        if ($prompted) {
            $choice = Read-Host "Do you want to save this credential for future use? [Y/N]"
            if ($choice -match '^[Yy]') {
                try {
                    CredentialManager\New-StoredCredential -Target $Target `
                        -UserName $prompted.UserName `
                        -Password ($prompted.GetNetworkCredential().Password) `
                        -Persist LocalMachine

                    Write-Host "Credential for '$Target' saved to Windows Credential Manager."
                } catch {
                    Write-Warning "Failed to save credential: $_"
                }
            }
            return $prompted
        }
    } catch {
        Write-Warning "Interactive credential prompt failed: $_"
    }

    return $null
}
