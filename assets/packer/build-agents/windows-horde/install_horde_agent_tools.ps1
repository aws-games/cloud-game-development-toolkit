function Write($message) {
    Write-Output $message
}

# Horde build-agent runtimes and tooling.
#
# The Horde module's own first-boot user_data (config/agent/agent-config.ps1)
# runs `choco install dotnet-6.0-runtime` and `choco install p4`. Baking those
# here makes the module's boot-time installs idempotent no-ops (choco detects
# the package is already present), which shaves first-boot time and removes a
# per-boot network dependency. The .NET version baked here matches the module's
# agent_dotnet_runtime_version default (6.0).

try {
    # .NET 6 runtime - matches Horde module agent_dotnet_runtime_version default.
    Write "Installing .NET 6.0 runtime"
    choco install -y --no-progress dotnet-6.0-runtime
}
catch {
    Write "Failed to install .NET 6.0 runtime"
}

try {
    # .NET 8 SDK - required by Unreal Engine 5.5 UnrealAutomationTool (UAT).
    Write "Installing .NET 8 SDK"
    choco install -y --no-progress dotnet-8.0-sdk
}
catch {
    Write "Failed to install .NET 8 SDK"
}

try {
    # Perforce command-line client (p4.exe) - matches the module's boot install.
    Write "Installing Perforce p4 client"
    choco install -y --no-progress p4
}
catch {
    Write "Failed to install Perforce p4 client"
}

try {
    # AWS CLI - used by the iSCSI/SAN pipeline scripts (secrets, S3 p4 trust, etc.)
    Write "Installing AWS CLI"
    choco install -y --no-progress awscli
}
catch {
    Write "Failed to install AWS CLI"
}

# NOTE: Do NOT call Chocolatey's `RefreshEnv` / `RefreshEnv.cmd` as the last
# statement here. When dot-invoked from this PowerShell process it prints
# "RefreshEnv.cmd does not work when run from this process" and leaves a
# non-zero exit code, which Packer's elevated wrapper propagates via
# `exit $LastExitCode` - failing the build even though every install above
# succeeded. Each Packer provisioner runs in a fresh shell that re-reads the
# machine PATH on connect, so an in-session PATH refresh is unnecessary.
exit 0
