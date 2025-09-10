param(
    [string]$WorkstationKey,
    [string]$AssignedUser,
    [string]$ProjectPrefix,
    [string]$Region,
    [string]$ForceRun
)

Write-Host "Creating VDI users for $WorkstationKey"

# Get all secrets for this workstation
$AllSecrets = aws secretsmanager list-secrets --region $Region --query "SecretList[?starts_with(Name, '$ProjectPrefix/$WorkstationKey/users/')].Name" --output text

foreach ($SecretName in ($AllSecrets -split '\s+')) {
    if ($SecretName) {
        Write-Host "Processing secret: $SecretName"
        $UserSecretJson = aws secretsmanager get-secret-value --secret-id $SecretName --region $Region --query SecretString --output text
        
        if ($UserSecretJson) {
            $UserData = $UserSecretJson | ConvertFrom-Json
            $UserPassword = ConvertTo-SecureString $UserData.password -AsPlainText -Force
            $Username = $UserData.username
            
            # Create user - no try/catch to avoid $_ issues
            New-LocalUser -Name $Username -Password $UserPassword -FullName "$($UserData.given_name) $($UserData.family_name)" -ErrorAction SilentlyContinue
            Set-LocalUser -Name $Username -Password $UserPassword -ErrorAction SilentlyContinue
            
            Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $Username -ErrorAction SilentlyContinue
            if ($UserData.user_type -eq 'administrator') {
                Add-LocalGroupMember -Group 'Administrators' -Member $Username -ErrorAction SilentlyContinue
            }
            
            Write-Host "Processed user: $Username"
        }
    }
}

# DCV session management
Start-Service dcvserver -ErrorAction SilentlyContinue
$dcvPath = 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe'

# Close existing sessions
& $dcvPath list-sessions | ForEach-Object { 
    if ($_ -match "Session: '(.+)'") { 
        & $dcvPath close-session $matches[1] 
    } 
}

# Create new session for assigned user
& $dcvPath create-session --owner $AssignedUser "$AssignedUser-session"
Write-Host "Created DCV session: $AssignedUser-session"

# Share session with Administrator (built-in account)
& $dcvPath share-session --user Administrator --permissions full "$AssignedUser-session" -ErrorAction SilentlyContinue
Write-Host "Shared session with Administrator"

# Share session with all administrator-type users (case-insensitive)
foreach ($SecretName in ($AllSecrets -split '\s+')) {
    if ($SecretName) {
        $UserSecretJson = aws secretsmanager get-secret-value --secret-id $SecretName --region $Region --query SecretString --output text
        if ($UserSecretJson) {
            $UserData = $UserSecretJson | ConvertFrom-Json
            # Case-insensitive comparison for administrator type
            if ($UserData.user_type -ieq 'administrator') {
                & $dcvPath share-session --user $UserData.username --permissions full "$AssignedUser-session" -ErrorAction SilentlyContinue
                Write-Host "Shared session with administrator user: $($UserData.username)"
            }
        }
    }
}

Write-Host "VDI setup completed"