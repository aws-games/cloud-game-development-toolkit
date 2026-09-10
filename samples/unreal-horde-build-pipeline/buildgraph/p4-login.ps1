<#
    p4-login.ps1 - mint a Perforce ticket for the build agent's Compile node.

    WHY THIS EXISTS: a fresh build agent runs `p4 flush` / `p4 sync` against the
    server with no ticket on the host, so those commands fail authentication.
    The P4 password's ONLY job is to run `p4 login` ONCE to mint a TICKET;
    every subsequent p4 command in the node uses that ticket, not the password.

    WHY IT DOES NOT OVERRIDE P4TICKETS/P4TRUST (contrast with the hydrator):
    hydrate-source-lun.ps1 overrides P4TICKETS/P4TRUST to a temp file because it
    does ALL of its p4 work inside ONE script process, so a private ticket file
    is fine there. This build node is different: BuildGraph runs each <Spawn> as
    a SEPARATE process, and environment set inside THIS script does NOT persist
    to the sibling `p4 flush` / `p4 sync` spawns. So this script must write the
    ticket where those sibling spawns read it BY DEFAULT - the user-profile
    ticket file at %USERPROFILE%\p4tickets.txt (and trust at
    %USERPROFILE%\p4trust.txt). Overriding them to a temp path here would hide
    the ticket from the very commands that need it. `p4 login` WITHOUT -p writes
    a ticket usable by later commands running as the same OS user, which is
    exactly the case: all spawns in the Compile node run as the same agent user.

    Called from BuildPipeline.xml as the FIRST step of the Compile node, before
    create-build-client.ps1 (which also talks to p4 and needs auth). If the
    secret read fails, warn and continue - an existing ticket may already be
    present, same behaviour as the hydrator.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $P4Port,
    [string] $P4User           = 'perforce',
    [string] $P4PasswordSecret = '',
    [string] $AwsRegion        = 'us-east-1'
)

$ErrorActionPreference = 'Stop'

$env:P4PORT = $P4Port
$env:P4USER = $P4User

# Deliberately DO NOT set $env:P4TRUST / $env:P4TICKETS to a temp path here.
# Letting p4 use the default user-profile locations means the sibling
# `p4 flush` / `p4 sync` spawns (which also use the defaults) find the ticket.

# Trust the server first; -y auto-accepts the fingerprint and handles the ssl:
# prefix on $P4Port.
& p4 trust -y *> $null

if ($P4PasswordSecret) {
    $pw = & aws secretsmanager get-secret-value --secret-id $P4PasswordSecret --region $AwsRegion --query SecretString --output text
    if ($LASTEXITCODE -eq 0 -and $pw) {
        # login WITHOUT -p writes a ticket to the default user-profile ticket
        # file, usable by the later flush/sync spawns as the same OS user.
        $pw | & p4 login *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "[p4-login] ticket minted for $P4User@$P4Port" }
        else { Write-Warning "p4 login failed (exit $LASTEXITCODE) - relying on an existing ticket" }
    }
    else {
        Write-Warning "could not read P4 password secret '$P4PasswordSecret' - relying on an existing ticket"
    }
}
else {
    Write-Host "[p4-login] no P4PasswordSecret supplied - relying on an existing ticket"
}
