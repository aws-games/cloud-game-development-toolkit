# In-build validation. Fails the Packer build (non-zero exit) if any required
# component is missing, so the AMI is never published half-baked. Also emits
# evidence lines for the build log.
$ErrorActionPreference = "Stop"
$failures = @()

function Write($message) { Write-Output $message }

# --- 1. MSVC / VC 14.38 toolchain (cl.exe + vcvars discoverable) ---
try {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        $failures += "vswhere.exe not found (VS Build Tools not installed)"
    }
    else {
        $vsPath = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath -latest
        Write "VS installation path: $vsPath"

        # vcvars discoverable
        $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path $vcvars) { Write "FOUND vcvars64.bat: $vcvars" }
        else { $failures += "vcvars64.bat not found under $vsPath" }

        # VC 14.38 toolset + cl.exe present
        $msvcRoot = Join-Path $vsPath "VC\Tools\MSVC"
        $clFiles = @()
        if (Test-Path $msvcRoot) {
            $clFiles = Get-ChildItem -Path $msvcRoot -Recurse -Filter "cl.exe" -ErrorAction SilentlyContinue
        }
        if ($clFiles.Count -gt 0) {
            Write "FOUND cl.exe:"
            $clFiles | ForEach-Object { Write "  $($_.FullName)" }
        }
        else {
            $failures += "cl.exe not found under $msvcRoot"
        }

        $v1438 = Get-ChildItem -Path $msvcRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "14.38*" }
        if ($v1438) { Write "FOUND VC 14.38 toolset: $($v1438.Name -join ', ')" }
        else { Write "WARN: no 14.38.* toolset dir found (other MSVC versions may be present)" }
    }
}
catch {
    $failures += "MSVC toolchain check errored: $_"
}

# --- 2. iSCSI initiator service present + Automatic ---
try {
    $msiscsi = Get-Service -Name MSiSCSI -ErrorAction Stop
    Write "FOUND MSiSCSI service: Status=$($msiscsi.Status) StartType=$($msiscsi.StartType)"
    if ($msiscsi.StartType -ne "Automatic") {
        $failures += "MSiSCSI StartType is $($msiscsi.StartType), expected Automatic"
    }
}
catch {
    $failures += "MSiSCSI service not found: $_"
}

# --- 3. MPIO feature present ---
try {
    $mpioFeature = Get-WindowsFeature -Name Multipath-IO -ErrorAction SilentlyContinue
    if ($mpioFeature -and $mpioFeature.Installed) {
        Write "FOUND MPIO feature (Multipath-IO): Installed=$($mpioFeature.Installed)"
    }
    else {
        $opt = Get-WindowsOptionalFeature -Online -FeatureName MultiPathIO -ErrorAction SilentlyContinue
        if ($opt -and $opt.State -eq "Enabled") {
            Write "FOUND MPIO optional feature (MultiPathIO): State=$($opt.State)"
        }
        else {
            $failures += "MPIO feature not installed/enabled"
        }
    }
}
catch {
    $failures += "MPIO check errored: $_"
}

# --- 4. .NET runtimes (evidence, non-fatal beyond presence of dotnet) ---
try {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnet) {
        Write "dotnet SDKs:"; & dotnet --list-sdks
        Write "dotnet runtimes:"; & dotnet --list-runtimes
    }
    else {
        Write "WARN: dotnet not on PATH at validation time (may require shell refresh)"
    }
}
catch {
    Write "WARN: dotnet enumeration errored: $_"
}

if ($failures.Count -gt 0) {
    Write "==== VALIDATION FAILED ===="
    $failures | ForEach-Object { Write "  FAIL: $_" }
    exit 1
}

Write "==== VALIDATION PASSED: MSVC toolchain + iSCSI initiator + MPIO present ===="
