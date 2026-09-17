function Write($message) {
    Write-Output $message
}

# Fail loud: any unhandled cmdlet error is terminating so a broken bake stops
# at THIS provisioner instead of limping onward to validate_image.
$ErrorActionPreference = 'Stop'

# Invoke-Choco: run a Chocolatey install and THROW (naming the package) if it
# returns a non-zero exit code. choco does not throw on failure by itself, so we
# must inspect $LASTEXITCODE explicitly or a failed install would pass silently.
function Invoke-Choco {
    param([Parameter(Mandatory = $true)][string] $Package)
    Write "Installing $Package"
    choco install -y --no-progress $Package
    if ($LASTEXITCODE -ne 0) {
        throw "install_horde_agent_tools: choco install '$Package' failed with exit code $LASTEXITCODE"
    }
}

# Horde build-agent runtimes and tooling.
#
# The Horde module's own first-boot user_data (config/agent/agent-config.ps1)
# runs `choco install dotnet-6.0-runtime` and `choco install p4`. Baking those
# here makes the module's boot-time installs idempotent no-ops (choco detects
# the package is already present), which shaves first-boot time and removes a
# per-boot network dependency. The .NET version baked here matches the module's
# agent_dotnet_runtime_version default (6.0).

# .NET 6 runtime - matches Horde module agent_dotnet_runtime_version default.
Invoke-Choco -Package dotnet-6.0-runtime

# .NET 8 SDK - required by Unreal Engine 5.5 UnrealAutomationTool (UAT).
Invoke-Choco -Package dotnet-8.0-sdk

# Perforce command-line client (p4.exe) - matches the module's boot install.
Invoke-Choco -Package p4

# AWS CLI - used by the iSCSI/SAN pipeline scripts (secrets, S3 p4 trust, etc.)
Invoke-Choco -Package awscli

# NOTE: Do NOT call Chocolatey's `RefreshEnv` / `RefreshEnv.cmd` as the last
# statement here. When dot-invoked from this PowerShell process it prints
# "RefreshEnv.cmd does not work when run from this process" and leaves a
# non-zero exit code, which Packer's elevated wrapper propagates via
# `exit $LastExitCode` - failing the build even though every install above
# succeeded. Each Packer provisioner runs in a fresh shell that re-reads the
# machine PATH on connect, so an in-session PATH refresh is unnecessary.
exit 0
