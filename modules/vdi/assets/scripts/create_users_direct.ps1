<powershell>
# Direct VDI User Creation - No SSM Required
# Creates users directly from Secrets Manager during boot

$ErrorActionPreference = "Continue"

try {
    Write-EventLog -LogName Application -Source "Application" -EventId 2001 -EntryType Information -Message "Starting direct user creation script"
    
    # Import AWS PowerShell module
    Import-Module AWS.Tools.SecretsManager -Force
    
    # Get instance metadata
    $instanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -TimeoutSec 10
    $region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region" -TimeoutSec 10
    
    Write-EventLog -LogName Application -Source "Application" -EventId 2002 -EntryType Information -Message "Instance: $instanceId, Region: $region"
    
    # Create VDIAdmin user with secure password
    Write-EventLog -LogName Application -Source "Application" -EventId 2003 -EntryType Information -Message "Creating VDIAdmin user"
    
    $VDIAdminPassword = -join ((65..90) + (97..122) + (48..57) + (33,35,36,37,38,42,43,45,61,63,64) | Get-Random -Count 16 | ForEach-Object {[char]$_})
    $SecureVDIAdminPassword = ConvertTo-SecureString $VDIAdminPassword -AsPlainText -Force
    
    try {
        New-LocalUser -Name 'VDIAdmin' -Password $SecureVDIAdminPassword -FullName 'VDI Administrator' -Description 'VDI Management Account' -ErrorAction Stop
        Write-EventLog -LogName Application -Source "Application" -EventId 2004 -EntryType Information -Message "Created new VDIAdmin user"
    } catch {
        if ($_.Exception.Message -like '*already exists*') {
            Write-EventLog -LogName Application -Source "Application" -EventId 2005 -EntryType Information -Message "VDIAdmin user already exists, updating password"
            Set-LocalUser -Name 'VDIAdmin' -Password $SecureVDIAdminPassword
        } else {
            Write-EventLog -LogName Application -Source "Application" -EventId 9002 -EntryType Error -Message "VDIAdmin creation failed: $_"
        }
    }
    
    Add-LocalGroupMember -Group 'Administrators' -Member 'VDIAdmin' -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group 'Remote Desktop Users' -Member 'VDIAdmin' -ErrorAction SilentlyContinue
    
    # Create john-doe user (hardcoded for now)
    Write-EventLog -LogName Application -Source "Application" -EventId 2006 -EntryType Information -Message "Creating john-doe user"
    
    try {
        # Get password from Secrets Manager
        $UserSecretName = "cgd/vdi-001/users/john-doe"
        $UserSecretValue = Get-SECSecretValue -SecretId $UserSecretName -Region $region
        $UserData = $UserSecretValue.SecretString | ConvertFrom-Json
        $UserPassword = ConvertTo-SecureString $UserData.password -AsPlainText -Force
        
        # Create the user
        New-LocalUser -Name "john-doe" -Password $UserPassword -FullName "$($UserData.given_name) $($UserData.family_name)" -Description "VDI User" -ErrorAction Stop
        Add-LocalGroupMember -Group 'Remote Desktop Users' -Member "john-doe" -ErrorAction Stop
        
        Write-EventLog -LogName Application -Source "Application" -EventId 2007 -EntryType Information -Message "Successfully created user john-doe"
        
        # Create DCV session
        Write-EventLog -LogName Application -Source "Application" -EventId 2008 -EntryType Information -Message "Creating DCV session for john-doe"
        
        $dcvPath = 'C:\Program Files\NICE\DCV\Server\bin\dcv.exe'
        
        # Close console session to free up session slots
        & $dcvPath close-session console 2>$null
        
        # Create DCV session
        & $dcvPath create-session --owner "john-doe" "john-doe-session" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-EventLog -LogName Application -Source "Application" -EventId 2009 -EntryType Information -Message "Created DCV session: john-doe-session"
        } else {
            Write-EventLog -LogName Application -Source "Application" -EventId 9003 -EntryType Error -Message "Failed to create DCV session for john-doe"
        }
        
    } catch {
        Write-EventLog -LogName Application -Source "Application" -EventId 9004 -EntryType Error -Message "Failed to create user john-doe: $_"
    }
    
    Write-EventLog -LogName Application -Source "Application" -EventId 2010 -EntryType Information -Message "Direct user creation script completed"
    
} catch {
    Write-EventLog -LogName Application -Source "Application" -EventId 9001 -EntryType Error -Message "Direct user creation script failed: $_"
}
</powershell>