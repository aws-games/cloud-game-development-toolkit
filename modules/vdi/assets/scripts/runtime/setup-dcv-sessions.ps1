# DCV Session Management Script
# Creates per-user DCV sessions with admin sharing for fleet management
$ErrorActionPreference = "Stop"

# Parameters passed from Terraform
param(
    [Parameter(Mandatory=$true)]
    [string]$AssignedUser,
    
    [Parameter(Mandatory=$true)]
    [string]$UserSource,  # "local" or "ad"
    
    [Parameter(Mandatory=$false)]
    [bool]$EnableAdminFleetAccess = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$AdminDefaultPermissions = "full",  # "view" or "full"
    
    [Parameter(Mandatory=$false)]
    [bool]$EnableAD = $false
)

function Write-DCVLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [DCV-SESSION] [$Level] $Message"
    
    # Write to console and Windows Event Log
    Write-Host $logMessage
    Write-EventLog -LogName Application -Source "VDI-DCV" -EventId 2001 -EntryType Information -Message $Message -ErrorAction SilentlyContinue
}

try {
    Write-DCVLog "Starting DCV session management setup..."
    Write-DCVLog "Assigned User: $AssignedUser, User Source: $UserSource, Admin Fleet Access: $EnableAdminFleetAccess"
    
    # Ensure DCV service is running
    Write-DCVLog "Ensuring DCV service is running..."
    Start-Service -Name dcvserver -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    
    # Get DCV executable path
    $dcvExe = "C:\Program Files\NICE\DCV\Server\bin\dcv.exe"
    if (-not (Test-Path $dcvExe)) {
        throw "DCV executable not found at $dcvExe"
    }
    
    # Function to create DCV session safely
    function New-DCVSession {
        param(
            [string]$Owner,
            [string]$SessionName
        )
        
        try {
            # Check if session already exists
            $existingSessions = & $dcvExe list-sessions 2>$null
            if ($existingSessions -match $SessionName) {
                Write-DCVLog "Session $SessionName already exists, closing it first..."
                & $dcvExe close-session $SessionName 2>$null
                Start-Sleep -Seconds 2
            }
            
            # Create new session
            Write-DCVLog "Creating DCV session: $SessionName (owner: $Owner)..."
            $result = & $dcvExe create-session --owner=$Owner $SessionName 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-DCVLog "Successfully created session: $SessionName" -Level "SUCCESS"
                return $true
            } else {
                Write-DCVLog "Failed to create session $SessionName`: $result" -Level "ERROR"
                return $false
            }
        } catch {
            Write-DCVLog "Exception creating session $SessionName`: $_" -Level "ERROR"
            return $false
        }
    }
    
    # Function to share DCV session safely
    function Share-DCVSession {
        param(
            [string]$SessionName,
            [string]$User,
            [string]$Permissions = "full"
        )\n        \n        try {\n            Write-DCVLog \"Sharing session $SessionName with user $User (permissions: $Permissions)...\"\n            $result = & $dcvExe share-session --user=$User --permissions=$Permissions $SessionName 2>&1\n            \n            if ($LASTEXITCODE -eq 0) {\n                Write-DCVLog \"Successfully shared session $SessionName with $User\" -Level \"SUCCESS\"\n                return $true\n            } else {\n                Write-DCVLog \"Failed to share session $SessionName with $User`: $result\" -Level \"WARNING\"\n                return $false\n            }\n        } catch {\n            Write-DCVLog \"Exception sharing session $SessionName with $User`: $_\" -Level \"WARNING\"\n            return $false\n        }\n    }\n    \n    # Create sessions for all user accounts on this instance\n    $sessionsCreated = @()\n    \n    # 1. Administrator session (break-glass)\n    Write-DCVLog \"Creating Administrator session...\"\n    if (New-DCVSession -Owner \"Administrator\" -SessionName \"administrator-session\") {\n        $sessionsCreated += \"administrator-session\"\n    }\n    \n    # 2. VDIAdmin session (automation)\n    Write-DCVLog \"Creating VDIAdmin session...\"\n    if (New-DCVSession -Owner \"VDIAdmin\" -SessionName \"vdiadmin-session\") {\n        $sessionsCreated += \"vdiadmin-session\"\n    }\n    \n    # 3. DomainAdmin session (if AD enabled)\n    if ($EnableAD) {\n        Write-DCVLog \"Creating DomainAdmin session...\"\n        if (New-DCVSession -Owner \"DomainAdmin\" -SessionName \"domainadmin-session\") {\n            $sessionsCreated += \"domainadmin-session\"\n        }\n    }\n    \n    # 4. Assigned user session (primary user)\n    Write-DCVLog \"Creating assigned user session for: $AssignedUser\"\n    $userSessionName = \"$AssignedUser-session\"\n    if (New-DCVSession -Owner $AssignedUser -SessionName $userSessionName) {\n        $sessionsCreated += $userSessionName\n        \n        # Share user session with admins (if fleet access enabled)\n        if ($EnableAdminFleetAccess) {\n            Write-DCVLog \"Enabling admin fleet access for user session...\"\n            \n            # Share with Administrator\n            Share-DCVSession -SessionName $userSessionName -User \"Administrator\" -Permissions $AdminDefaultPermissions\n            \n            # Share with VDIAdmin\n            Share-DCVSession -SessionName $userSessionName -User \"VDIAdmin\" -Permissions $AdminDefaultPermissions\n            \n            # Share with DomainAdmin (if AD enabled)\n            if ($EnableAD) {\n                Share-DCVSession -SessionName $userSessionName -User \"DomainAdmin\" -Permissions $AdminDefaultPermissions\n            }\n        }\n    }\n    \n    # Log final session status\n    Write-DCVLog \"DCV session setup completed. Sessions created: $($sessionsCreated -join ', ')\"\n    \n    # List all sessions for verification\n    Write-DCVLog \"Current DCV sessions:\"\n    $allSessions = & $dcvExe list-sessions 2>&1\n    Write-DCVLog \"$allSessions\"\n    \n    # Create registry entry for session management info\n    $sessionInfo = @{\n        AssignedUser = $AssignedUser\n        UserSource = $UserSource\n        SessionsCreated = $sessionsCreated\n        AdminFleetAccess = $EnableAdminFleetAccess\n        SetupTimestamp = (Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")\n    }\n    \n    $sessionInfoJson = $sessionInfo | ConvertTo-Json -Compress\n    New-Item -Path \"HKLM:\\SOFTWARE\\VDI\" -Force | Out-Null\n    Set-ItemProperty -Path \"HKLM:\\SOFTWARE\\VDI\" -Name \"DCVSessionInfo\" -Value $sessionInfoJson\n    \n    Write-DCVLog \"DCV session management setup completed successfully\" -Level \"SUCCESS\"\n    \n} catch {\n    Write-DCVLog \"DCV session setup failed: $_\" -Level \"ERROR\"\n    throw\n}\n