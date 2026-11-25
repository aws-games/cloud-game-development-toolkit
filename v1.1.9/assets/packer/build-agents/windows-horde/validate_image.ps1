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

# --- 3b. MSDSM automatic claim of iSCSI devices IS IN EFFECT ---
# The MPIO feature being installed (section 3) is NOT enough: a two-portal LUN
# only collapses to a single disk if MSDSM is actually claiming iSCSI devices.
# configure_mpio_claim.ps1 enables + verifies this post-reboot; assert it here
# too so a regression fails the bake. Read Get-MSDSMAutomaticClaimSettings
# handling BOTH the hashtable and the list-of-rows output shapes.
try {
    $claim = Get-MSDSMAutomaticClaimSettings -ErrorAction Stop
    $iscsiClaimed = $false

    if ($null -eq $claim) {
        $iscsiClaimed = $false
    }
    elseif ($claim -is [System.Collections.IDictionary]) {
        # Shape A: hashtable keyed by bus type.
        foreach ($key in $claim.Keys) {
            if ("$key" -match 'iSCSI') { $iscsiClaimed = [bool]$claim[$key] }
        }
    }
    else {
        # Shape B: single object with an iSCSI property.
        $prop = $claim.PSObject.Properties | Where-Object { $_.Name -match 'iSCSI' } | Select-Object -First 1
        if ($prop) {
            $iscsiClaimed = [bool]$prop.Value
        }
        else {
            # Shape C: list of rows, one per bus type.
            foreach ($row in @($claim)) {
                $busProp = $row.PSObject.Properties | Where-Object { $_.Name -match 'BusType|Bus' } | Select-Object -First 1
                if ($busProp -and "$($busProp.Value)" -match 'iSCSI') {
                    $valProp = $row.PSObject.Properties |
                        Where-Object { $_.Name -match 'Enabled|Value|Claim|AutomaticClaim' } |
                        Select-Object -First 1
                    $iscsiClaimed = if ($valProp) { [bool]$valProp.Value } else { $true }
                }
            }
        }
    }

    if ($iscsiClaimed) {
        Write "FOUND MSDSM automatic claim for iSCSI: IN EFFECT"
    }
    else {
        $failures += "MSDSM automatic claim for iSCSI is NOT in effect (two-portal LUN would enumerate as two disks)"
    }
}
catch {
    $failures += "MSDSM iSCSI claim check errored: $_"
}

# --- 4. Boot-time unique-IQN mechanism (baked ONSTART task + baked script) ---
try {
    $iqnScript = "C:\ProgramData\horde\set_unique_iqn.ps1"
    if (Test-Path $iqnScript) {
        Write "FOUND baked unique-IQN script: $iqnScript"
    }
    else {
        $failures += "unique-IQN script not found at $iqnScript"
    }

    $iqnTask = Get-ScheduledTask -TaskName "Horde-SetUniqueIqn" -ErrorAction SilentlyContinue
    if ($iqnTask) {
        $trigger = ($iqnTask.Triggers | Select-Object -First 1).CimClass.CimClassName
        Write "FOUND ONSTART task 'Horde-SetUniqueIqn': State=$($iqnTask.State) Trigger=$trigger"
    }
    else {
        $failures += "Scheduled Task 'Horde-SetUniqueIqn' not found (boot-time IQN mechanism missing)"
    }
}
catch {
    $failures += "boot-time unique-IQN mechanism check errored: $_"
}

# --- 4b. EXERCISE the baked script and PROVE the IQN actually changed ---
# Presence of the task/script is NOT proof it works: a prior revision called
# Set-InitiatorPort without the mandatory -NewNodeAddress, threw on every boot,
# and left every agent on its hostname-derived DEFAULT IQN - undetected, because
# this validator only checked that the task existed. Run the script here on the
# build instance (which has IMDS), then assert the initiator comes back as the
# instance-id-derived IQN. The bake FAILS otherwise.
try {
    $iqnScript = "C:\ProgramData\horde\set_unique_iqn.ps1"
    if (Test-Path $iqnScript) {
        # The script now throws (fail-loud) if it cannot set the IQN; capture a
        # non-zero exit as a validation failure.
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $iqnScript | Out-Null
        $iqnExit = $LASTEXITCODE

        $iqnNow = (Get-InitiatorPort -ErrorAction Stop |
            Where-Object { $_.NodeAddress -like 'iqn.*' } |
            Select-Object -First 1).NodeAddress

        # On the build instance IMDS is available, so the IQN MUST be the
        # instance-id form iqn.1991-05.com.microsoft:i-<id>. A hostname/default
        # IQN (WinServer-style) or the local-* fallback here means the set failed.
        if ($iqnExit -ne 0) {
            $failures += "set_unique_iqn.ps1 exited $iqnExit (fail-loud) - IQN was NOT set; see C:\ProgramData\horde\set_unique_iqn.log"
        }
        elseif ($iqnNow -match '^iqn\.1991-05\.com\.microsoft:i-[0-9a-f]+$') {
            Write "VERIFIED instance-id-derived initiator IQN after running set_unique_iqn.ps1: $iqnNow"
        }
        else {
            $failures += "set_unique_iqn.ps1 ran but the initiator IQN is '$iqnNow' (expected iqn.1991-05.com.microsoft:i-<instance-id>) - the boot-time IQN change did not take effect; see C:\ProgramData\horde\set_unique_iqn.log"
        }
    }
    else {
        $failures += "cannot exercise unique-IQN: script not found at $iqnScript"
    }
}
catch {
    $failures += "unique-IQN exercise errored (script likely threw / IQN not set): $_"
}

# --- 5. .NET runtimes (evidence, non-fatal beyond presence of dotnet) ---
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

Write "==== VALIDATION PASSED: MSVC toolchain + iSCSI initiator + MPIO + MSDSM iSCSI claim + boot-time unique-IQN task present ===="
