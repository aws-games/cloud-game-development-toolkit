$ErrorActionPreference = 'Continue'
$LogFile = 'C:\temp\vdi-ssm-setup.log'
New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
Start-Transcript -Path $LogFile -Append

Write-Host "=== SSM VDI User Creation Started ===" -ForegroundColor Green
$WorkstationKey = "{{ WorkstationKey }}"
$AssignedUser = "{{ AssignedUser }}"
$ProjectPrefix = "{{ ProjectPrefix }}"
$Region = "{{ Region }}"

# Create VDI users from Terraform-generated passwords in Secrets Manager
try {
    $AllSecrets = aws secretsmanager list-secrets --region $Region --query "SecretList[?starts_with(Name, '$ProjectPrefix/$WorkstationKey/users/')].Name" --output text
    foreach ($SecretName in ($AllSecrets -split '\s+')) {
        if ($SecretName) {
            $UserSecretJson = aws secretsmanager get-secret-value --secret-id $SecretName --region $Region --query SecretString --output text
            if ($UserSecretJson) {
                $UserData = $UserSecretJson | ConvertFrom-Json
                $UserPassword = ConvertTo-SecureString $UserData.password -AsPlainText -Force
                $Username = $UserData.username
                $UserType = $UserData.user_type
                
                try {
                    New-LocalUser -Name $Username -Password $UserPassword -FullName "$($UserData.given_name) $($UserData.family_name)" -Description "VDI $UserType User" -ErrorAction Stop
                    Write-Host "Created user: $Username ($UserType)" -ForegroundColor Green
                } catch {
                    if ($_.Exception.Message -like '*already exists*') {
                        Set-LocalUser -Name $Username -Password $UserPassword
                        Write-Host "Updated user: $Username" -ForegroundColor Yellow
                    } else {
                        Write-Warning "Failed to create $Username: $($_.Exception.Message)"
                    }
                }
                
                Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $Username -ErrorAction SilentlyContinue
                if ($UserType -eq 'administrator') {
                    Add-LocalGroupMember -Group 'Administrators' -Member $Username -ErrorAction SilentlyContinue
                } else {
                    Add-LocalGroupMember -Group 'Users' -Member $Username -ErrorAction SilentlyContinue
                }
            }
        }
    }
} catch {
    Write-Warning "User creation failed: $($_.Exception.Message)"
}

# Configure DCV
$dcvPath = 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe'
Start-Service -Name dcvserver -ErrorAction SilentlyContinue
Set-Service -Name dcvserver -StartupType Automatic

# Close existing sessions (SYSTEM session from AMI)
Write-Host "Closing existing DCV sessions..." -ForegroundColor Yellow
$existingSessions = & $dcvPath list-sessions 2>$null | Select-String "Session:" | ForEach-Object { ($_ -split "'")[1] }
foreach ($session in $existingSessions) {
    Write-Host "Closing session: $session"
    & $dcvPath close-session $session 2>$null
}
Start-Sleep -Seconds 5

$permissionsContent = @"
[permissions]
%any% allow connect-session
Administrator allow builtin
vdiadmin allow builtin
$AssignedUser allow builtin
"@
$permissionsContent | Out-File -FilePath 'C:\Program Files\NICE\DCV\Server\conf\default.pv' -Encoding ASCII -Force

Restart-Service dcvserver -Force
Start-Sleep -Seconds 15

$userExists = Get-LocalUser -Name $AssignedUser -ErrorAction SilentlyContinue
if ($userExists) {
    & $dcvPath create-session --owner $AssignedUser "$AssignedUser-session" 2>$null
    Write-Host "Created DCV session for $AssignedUser" -ForegroundColor Green
}

Write-Host "=== SSM VDI Setup Completed ===" -ForegroundColor Green
Stop-Transcript