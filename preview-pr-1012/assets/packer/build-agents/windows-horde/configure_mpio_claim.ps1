# Enable AND VERIFY the MSDSM automatic claim of iSCSI devices, fail-loud.
#
# WHY THIS IS A SEPARATE STEP THAT RUNS AFTER A REBOOT
# ----------------------------------------------------
# Installing the Multipath-IO feature (install_iscsi.ps1) does NOT make the
# MSDSM cmdlets fully effective until the feature's filter driver is loaded,
# which requires a reboot. Calling Enable-MSDSMAutomaticClaim in the same
# provisioner that installed the feature can appear to succeed yet leave the
# automatic claim NOT in effect on the running system. So the Packer template
# does: install MPIO -> windows-restart -> THIS script.
#
# WHY WE VERIFY INSTEAD OF FIRE-AND-FORGET
# ----------------------------------------
# The old install_iscsi.ps1 called Enable-MSDSMAutomaticClaim with
# -ErrorAction SilentlyContinue and never checked the result. If the claim did
# not take, agents would attach the SAME LUN over two portals and Windows would
# enumerate it as TWO disks (the corruption trap OntapSan.psm1 warns about) with
# nothing failing the bake. This script reads the claim state back and exits
# non-zero if it is not actually in effect, so the AMI is never published with a
# broken MPIO claim.

$ErrorActionPreference = "Stop"

function Write($message) { Write-Output $message }

function Test-MSDSMiScsiClaim {
    <#  Return $true iff MSDSM is set to automatically claim iSCSI devices.

        Get-MSDSMAutomaticClaimSettings is INCONSISTENT across Windows builds:
          * SOME builds return a single hashtable/dictionary keyed by bus type,
            e.g. @{ iSCSI = $true; SAS = $false }.
          * OTHER builds return a LIST OF ROWS, one object per bus type, each
            with a BusType and an enabled/value property.
        A reader that assumes only one shape silently returns the wrong answer
        on the other. Handle BOTH explicitly. #>
    $settings = Get-MSDSMAutomaticClaimSettings -ErrorAction Stop
    if ($null -eq $settings) { return $false }

    # Shape A: hashtable / dictionary keyed by bus type.
    if ($settings -is [System.Collections.IDictionary]) {
        foreach ($key in $settings.Keys) {
            if ("$key" -match 'iSCSI') {
                return [bool]$settings[$key]
            }
        }
        return $false
    }

    # Shape B: a single object exposing an 'iSCSI' property (PSCustomObject).
    $prop = $settings.PSObject.Properties | Where-Object { $_.Name -match 'iSCSI' } | Select-Object -First 1
    if ($prop) {
        return [bool]$prop.Value
    }

    # Shape C: a list of rows, one per bus type. Find the iSCSI row and read its
    # enabled/value flag (property name also varies across builds).
    foreach ($row in @($settings)) {
        $busProp = $row.PSObject.Properties | Where-Object { $_.Name -match 'BusType|Bus' } | Select-Object -First 1
        if ($busProp -and "$($busProp.Value)" -match 'iSCSI') {
            $valProp = $row.PSObject.Properties |
                Where-Object { $_.Name -match 'Enabled|Value|Claim|AutomaticClaim' } |
                Select-Object -First 1
            if ($valProp) { return [bool]$valProp.Value }
            # No obvious flag column: presence of the iSCSI row implies claimed.
            return $true
        }
    }

    return $false
}

try {
    Write "Enabling MSDSM automatic claim of iSCSI devices"
    # Requires the MPIO feature + its driver (loaded after the reboot that
    # precedes this script).
    Enable-MSDSMAutomaticClaim -BusType iSCSI -Confirm:$false -ErrorAction Stop
    # Set a sensible default load-balance policy for claimed devices.
    Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR -ErrorAction SilentlyContinue
}
catch {
    Write "==== MPIO CLAIM CONFIG FAILED ===="
    Write "  Enable-MSDSMAutomaticClaim threw: $_"
    exit 1
}

# VERIFY the claim is actually in effect - do not trust the enable call alone.
try {
    if (Test-MSDSMiScsiClaim) {
        Write "VERIFIED: MSDSM automatic claim for iSCSI is IN EFFECT."
    }
    else {
        Write "==== MPIO CLAIM VERIFICATION FAILED ===="
        Write "  MSDSM automatic claim for iSCSI is NOT in effect after Enable-MSDSMAutomaticClaim."
        Write "  Without it, a two-portal LUN enumerates as two disks (corruption trap)."
        exit 1
    }
}
catch {
    Write "==== MPIO CLAIM VERIFICATION ERRORED ===="
    Write "  Could not read Get-MSDSMAutomaticClaimSettings: $_"
    exit 1
}

Write "MSDSM iSCSI automatic claim step complete."
