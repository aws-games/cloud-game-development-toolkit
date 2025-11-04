param(
    [string]$WorkstationKey,
    [string]$AssignedUser,
    [string]$ProjectPrefix,
    [string]$Region
)

Write-Host "Creating VDI users for $WorkstationKey"

# Get all secrets for this workstation
$AllSecrets = aws secretsmanager list-secrets --region $Region --query "SecretList[?starts_with(Name, '$ProjectPrefix/$WorkstationKey/users/')].Name" --output text

foreach ($SecretName in ($AllSecrets -split '\s+')) {
    if ($SecretName -and $SecretName.Trim() -ne "") {
        Write-Host "Processing secret: $SecretName"
        try {
            $UserSecretJson = aws secretsmanager get-secret-value --secret-id $SecretName --region $Region --query SecretString --output text

            if ($UserSecretJson) {
                $UserData = $UserSecretJson | ConvertFrom-Json
                $Username = $UserData.username
                $UserPassword = ConvertTo-SecureString $UserData.password -AsPlainText -Force
                $FullName = "$($UserData.given_name) $($UserData.family_name)"

                Write-Host "Creating user: $Username (Type: $($UserData.user_type))"

                # Check if user already exists
                $existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
                if ($existingUser) {
                    Write-Host "User $Username already exists, updating password"
                    Set-LocalUser -Name $Username -Password $UserPassword -ErrorAction SilentlyContinue
                } else {
                    Write-Host "Creating new user: $Username"
                    New-LocalUser -Name $Username -Password $UserPassword -FullName $FullName -Description "VDI User" -ErrorAction SilentlyContinue
                }

                # Add to Remote Desktop Users group
                Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $Username -ErrorAction SilentlyContinue

                # Add to Administrators group if needed
                if ($UserData.user_type -eq 'administrator' -or $UserData.user_type -eq 'fleet_administrator') {
                    Add-LocalGroupMember -Group 'Administrators' -Member $Username -ErrorAction SilentlyContinue
                }

                Write-Host "Successfully processed user: $Username"
            }
        } catch {
            Write-Host "Failed to process secret $SecretName : $_" -ForegroundColor Red
            return
        }
    }
}

# Configure DCV for assigned user
if ($AssignedUser -and $AssignedUser -ne "none") {
    Write-Host "Configuring DCV for user: $AssignedUser"
    try {
        $registryPath = "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\session-management"

        # Create registry keys if they don't exist
        $regKey = "HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv"
        if (-not (Test-Path "Registry::$regKey")) {
            New-Item -Path "Registry::$regKey" -Force | Out-Null
        }
        if (-not (Test-Path "Registry::$registryPath")) {
            New-Item -Path "Registry::$registryPath" -Force | Out-Null
        }

        # Enable automatic session creation for assigned user
        Set-ItemProperty -Path "Registry::$registryPath" -Name "create-session" -Value 1 -Type DWord
        Set-ItemProperty -Path "Registry::$registryPath" -Name "owner" -Value $AssignedUser -Type String

        Write-Host "Configured DCV for automatic session creation"

        # Restart DCV service to apply configuration
        Restart-Service -Name dcvserver -Force -ErrorAction SilentlyContinue
        Write-Host "DCV service restarted"

    } catch {
        Write-Host "Failed to configure DCV: $_" -ForegroundColor Yellow
    }
}

Write-Host "User creation completed"
