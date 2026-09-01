<#
    OntapSan.psm1 - shared ONTAP + Windows iSCSI helpers for the FSxN hydration
    pipeline. Imported by hydrate-source-lun.ps1, attach-clone-lun.ps1 and
    teardown-clone-lun.ps1.

    WHY SAN INSTEAD OF NFS
    ---------------------
    ADR-002 chose NFSv3 and rejected iSCSI on throughput grounds. Running the
    pipeline proved that reasoning incomplete: throughput was never the binding
    constraint, Windows filesystem SEMANTICS were. On a Windows NFSv3 mount:

      * UBA (Unreal Build Accelerator) detours file I/O and calls
        NtQueryInformationFile on every input; the Windows NFS redirector answers
        0xc000000d (STATUS_INVALID_PARAMETER). Measured 628 failures, all on
        Engine/Source/*. UBA therefore cannot be used at all.
      * The DDC and the shader library fail or corrupt on write.
      * The stager's SafeCopyFile -> SetFileTime fails and retries FOREVER, so
        the job HANGS instead of erroring.

    A LUN presents real NTFS, so all four work and UBA can stay enabled. It also
    hydrates faster (measured ~40% on a 49.55 GB seed: 9m30s vs 15m33s) because
    block I/O skips per-file metadata round-trips.

    THE CONSTRAINT THIS INTRODUCES - READ IT
    ----------------------------------------
    NTFS IS NOT A SHARED FILESYSTEM. A LUN has exactly one legitimate writer.
    Hence two igroups, deliberately:

      * source LUN  -> a SINGLE-HOST igroup (the hydrator). Mapping it to a
        shared igroup would let two hosts mount one NTFS volume read-write and
        corrupt it.
      * clone LUNs  -> a shared igroup is fine, because each clone is used by
        exactly one job on one agent.

    Also: connect exactly ONE iSCSI portal unless the MPIO feature is installed.
    Two portals without MPIO make Windows enumerate one LUN as two separate
    disks, which is its own corruption trap.

    ONTAP REST NOTES learned the hard way
    -------------------------------------
      * LUNs, igroups and NFS/SAN options are not all in the documented REST
        surface. The private-CLI passthrough POST /api/private/cli/<cmd> covers
        the rest.
      * On the private CLI, "initiator" must be a JSON ARRAY even for a single
        value, or you get error 262254.
      * DELETE on private/cli/lun/mapping by query string matches NOTHING. Use
        the documented /api/protocols/san/lun-maps/{lun.uuid}/{igroup.uuid}.
      * ONTAP volume names reject hyphens: build-{jobId} fails with an opaque
        HTTP 400. Use build_{jobid}, lowercased. New-OntapCloneName enforces it.
#>

Set-StrictMode -Version Latest

# FSxN's management endpoint presents a self-signed certificate.
# -SkipCertificateCheck is PowerShell 7+; Windows Server ships PS 5.1, so use a
# compiled callback.
function Enable-OntapCertBypass {
    if (-not ('OntapCertBypass' -as [type])) {
        Add-Type 'using System.Net;public static class OntapCertBypass{public static void Enable(){ServicePointManager.ServerCertificateValidationCallback=(s,c,ch,e)=>true;}}'
    }
    [OntapCertBypass]::Enable()
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

function Connect-Ontap {
    <#  Builds a connection context. The password comes from Secrets Manager at
        runtime and is never written to disk or logged. #>
    param(
        [Parameter(Mandatory)] [string] $ManagementEndpoint,
        [Parameter(Mandatory)] [string] $PasswordSecretName,
        [Parameter(Mandatory)] [string] $AwsRegion,
        [string] $User = 'fsxadmin',
        [Parameter(Mandatory)] [string] $Svm
    )
    Enable-OntapCertBypass

    $pw = & aws secretsmanager get-secret-value --secret-id $PasswordSecretName `
        --region $AwsRegion --query SecretString --output text
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($pw)) {
        throw "Could not read ONTAP password from Secrets Manager secret '$PasswordSecretName' in $AwsRegion."
    }

    return [pscustomobject]@{
        Api     = "https://$ManagementEndpoint/api"
        Svm     = $Svm
        Headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String(
                        [Text.Encoding]::ASCII.GetBytes("${User}:${pw}")) }
    }
}

function Invoke-Ontap {
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $Path,
        [string] $Method = 'Get',
        $Body = $null,
        [int] $TimeoutSec = 120
    )
    $uri = "$($Ctx.Api)$Path"
    if ($null -ne $Body) {
        return Invoke-RestMethod -Uri $uri -Method $Method -Headers $Ctx.Headers `
            -Body ($Body | ConvertTo-Json -Depth 8 -Compress) `
            -ContentType 'application/json' -TimeoutSec $TimeoutSec
    }
    return Invoke-RestMethod -Uri $uri -Method $Method -Headers $Ctx.Headers -TimeoutSec $TimeoutSec
}

function New-OntapCloneName {
    <#  ONTAP volume names: must start with a letter or underscore, then only
        letters/digits/underscore, max 203 chars. NO HYPHENS - a Horde job id is
        hex so it is safe, but a branch or template name is not, and the failure
        is an opaque 400. Normalise rather than trust the caller. #>
    param([Parameter(Mandatory)] [string] $JobId, [string] $Prefix = 'build')
    $safe = ($JobId -replace '[^A-Za-z0-9_]', '_').ToLowerInvariant()
    $name = "${Prefix}_${safe}"
    if ($name.Length -gt 203) { $name = $name.Substring(0, 203) }
    return $name
}

function Get-OntapVolume {
    param([Parameter(Mandatory)] $Ctx, [Parameter(Mandatory)] [string] $Name)
    $r = Invoke-Ontap -Ctx $Ctx -Path "/storage/volumes?name=$Name&svm.name=$($Ctx.Svm)&fields=uuid,name,state"
    if ($r.num_records -eq 0) { return $null }
    return $r.records[0]
}

function New-OntapSnapshot {
    <#  Snapshot a SAN volume. THE Write-VolumeCache CALL IS NOT OPTIONAL: an
        ONTAP snapshot captures blocks as the array sees them, so anything still
        sitting in the Windows write cache is simply absent from the snapshot.
        Without the flush you get a crash-consistent image of NTFS - which may
        mount, then fail chkdsk or lose the tail of the p4 sync. #>
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $VolumeName,
        [Parameter(Mandatory)] [string] $SnapshotName,
        [string] $FlushDriveLetter
    )
    $vol = Get-OntapVolume -Ctx $Ctx -Name $VolumeName
    if (-not $vol) { throw "Volume '$VolumeName' not found on SVM '$($Ctx.Svm)'." }

    if ($FlushDriveLetter) {
        Write-Host "  flushing NTFS write cache on $FlushDriveLetter`: before snapshot"
        Write-VolumeCache -DriveLetter $FlushDriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
    }

    $existing = Invoke-Ontap -Ctx $Ctx -Path "/storage/volumes/$($vol.uuid)/snapshots?name=$SnapshotName"
    if ($existing.num_records -gt 0) {
        Write-Host "  snapshot '$SnapshotName' already exists - leaving it alone"
        return
    }

    Invoke-Ontap -Ctx $Ctx -Path "/storage/volumes/$($vol.uuid)/snapshots" -Method Post `
        -Body @{ name = $SnapshotName } | Out-Null

    for ($i = 0; $i -lt 60; $i++) {
        $r = Invoke-Ontap -Ctx $Ctx -Path "/storage/volumes/$($vol.uuid)/snapshots?name=$SnapshotName"
        if ($r.num_records -ge 1) { Write-Host "  created snapshot '$SnapshotName'"; return }
        Start-Sleep -Seconds 1
    }
    throw "Snapshot '$SnapshotName' did not appear within 60s."
}

function New-OntapFlexClone {
    <#  Create a FlexClone of a snapshot.

        NOTE the absence of a `nas` block. For NAS you junction the clone so a
        client can mount it; a SAN clone must NOT be junctioned - the LUN inside
        it is reached through a LUN map, and junctioning it would additionally
        expose the filesystem over NAS. #>
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $ParentVolume,
        [Parameter(Mandatory)] [string] $SnapshotName,
        [Parameter(Mandatory)] [string] $CloneName
    )
    if (Get-OntapVolume -Ctx $Ctx -Name $CloneName) {
        throw "Clone volume '$CloneName' already exists. Delete it first, or use a unique name."
    }

    Invoke-Ontap -Ctx $Ctx -Path '/storage/volumes' -Method Post -Body @{
        name = $CloneName
        svm  = @{ name = $Ctx.Svm }
        clone = @{
            is_flexclone    = $true
            parent_volume   = @{ name = $ParentVolume }
            parent_snapshot = @{ name = $SnapshotName }
        }
        comment = "FlexClone of $ParentVolume@$SnapshotName"
    } | Out-Null

    # Poll rather than sleep. A FlexClone is a metadata operation; measured at
    # ~1.2 s on a 45 GiB volume, so a fixed 10 s sleep would be ~8x the work.
    for ($i = 0; $i -lt 60; $i++) {
        $v = Get-OntapVolume -Ctx $Ctx -Name $CloneName
        if ($v) { return $v }
        Start-Sleep -Milliseconds 500
    }
    throw "Clone '$CloneName' was not visible within 30s."
}

function Remove-OntapVolume {
    param([Parameter(Mandatory)] $Ctx, [Parameter(Mandatory)] [string] $Name)
    $v = Get-OntapVolume -Ctx $Ctx -Name $Name
    if (-not $v) { Write-Host "  volume '$Name' already gone"; return }
    Invoke-Ontap -Ctx $Ctx -Path "/storage/volumes/$($v.uuid)" -Method Delete | Out-Null
    Write-Host "  delete requested for volume '$Name'"
}

function Get-LocalIqn {
    <#  Windows derives its IQN from the hostname
        (iqn.1991-05.com.microsoft:<fqdn>), so it CHANGES when the machine is
        renamed - which EC2 does on first boot. Starting the initiator service is
        what materialises it, so do that first. #>
    Set-Service -Name MSiSCSI -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name MSiSCSI -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 30; $i++) {
        $iqn = (Get-InitiatorPort -ErrorAction SilentlyContinue |
                 Where-Object { $_.NodeAddress -like 'iqn.*' } |
                 Select-Object -First 1).NodeAddress
        if ($iqn) { return $iqn }
        Start-Sleep -Seconds 2
    }
    throw 'Could not determine this host iSCSI IQN. Is the MSiSCSI service running?'
}

function Add-OntapIgroupInitiator {
    <#  Create-if-absent igroup, then add this initiator if missing.

        $SingleHost is the safety switch. For the SOURCE LUN's igroup it MUST be
        $true: if the igroup already contains a different initiator, that means
        another host believes it owns the LUN, and adding ourselves would put two
        writers on one NTFS volume. Fail loudly instead. #>
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $Igroup,
        [Parameter(Mandatory)] [string] $Iqn,
        [switch] $SingleHost
    )
    $r = Invoke-Ontap -Ctx $Ctx -Path "/private/cli/lun/igroup?vserver=$($Ctx.Svm)&igroup=$Igroup&fields=initiator"

    if ($r.num_records -eq 0) {
        # "initiator" must be an ARRAY even for one value (private CLI error
        # 262254 otherwise).
        Invoke-Ontap -Ctx $Ctx -Path '/private/cli/lun/igroup' -Method Post -Body @{
            vserver   = $Ctx.Svm
            igroup    = $Igroup
            protocol  = 'iscsi'
            ostype    = 'windows'
            initiator = @($Iqn)
        } | Out-Null
        Write-Host "  created igroup '$Igroup' with $Iqn"
        return
    }

    $current = @($r.records[0].initiator) | Where-Object { $_ }
    if ($current -contains $Iqn) { Write-Host "  igroup '$Igroup' already contains this host"; return }

    if ($SingleHost -and $current.Count -gt 0) {
        throw @"
REFUSING to add this host to igroup '$Igroup'.
It already contains: $($current -join ', ')
That igroup owns a SOURCE LUN, which carries NTFS - a filesystem with exactly one
legitimate writer. Adding a second initiator invites silent corruption.
If the listed initiator belongs to a terminated host, remove it explicitly first:
  lun igroup remove -vserver $($Ctx.Svm) -igroup $Igroup -initiator <stale-iqn>
"@
    }

    Invoke-Ontap -Ctx $Ctx -Path '/private/cli/lun/igroup/add' -Method Post -Body @{
        vserver   = $Ctx.Svm
        igroup    = $Igroup
        initiator = @($Iqn)
    } | Out-Null
    Write-Host "  added $Iqn to igroup '$Igroup'"
}

function New-OntapLunMap {
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $LunPath,
        [Parameter(Mandatory)] [string] $Igroup
    )
    $existing = Invoke-Ontap -Ctx $Ctx -Path "/private/cli/lun/mapping?vserver=$($Ctx.Svm)&path=$LunPath&igroup=$Igroup"
    if ($existing.num_records -gt 0) { Write-Host "  LUN already mapped to '$Igroup'"; return }

    Invoke-Ontap -Ctx $Ctx -Path '/private/cli/lun/mapping' -Method Post -Body @{
        vserver = $Ctx.Svm
        path    = $LunPath
        igroup  = $Igroup
    } | Out-Null
    Write-Host "  mapped $LunPath -> $Igroup"
}

function Remove-OntapLunMap {
    <#  Use the DOCUMENTED lun-maps endpoint. DELETE on
        private/cli/lun/mapping?path=...&igroup=... returns success and deletes
        NOTHING, which leaves the clone undeletable and the snapshot pinned. #>
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $LunPath,
        [string] $Igroup
    )
    $q = "/protocols/san/lun-maps?lun.name=$LunPath&fields=lun.uuid,igroup.uuid,igroup.name"
    if ($Igroup) { $q += "&igroup.name=$Igroup" }
    $maps = Invoke-Ontap -Ctx $Ctx -Path $q
    if ($maps.num_records -eq 0) { Write-Host "  no LUN map to remove for $LunPath"; return }
    foreach ($m in $maps.records) {
        Invoke-Ontap -Ctx $Ctx -Path "/protocols/san/lun-maps/$($m.lun.uuid)/$($m.igroup.uuid)" -Method Delete | Out-Null
        Write-Host "  unmapped $LunPath from $($m.igroup.name)"
    }
}

function New-OntapLun {
    <#  Create-if-absent thin LUN. space-allocation lets ONTAP report
        thin-provision exhaustion to Windows over SCSI, instead of the LUN
        silently going read-only when the containing volume fills. #>
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $LunPath,
        [Parameter(Mandatory)] [string] $Size,
        [string] $OsType = 'windows_2008'
    )
    $r = Invoke-Ontap -Ctx $Ctx -Path "/private/cli/lun?vserver=$($Ctx.Svm)&path=$LunPath"
    if ($r.num_records -gt 0) { Write-Host "  LUN $LunPath already exists"; return }

    Invoke-Ontap -Ctx $Ctx -Path '/private/cli/lun' -Method Post -Body @{
        vserver            = $Ctx.Svm
        path               = $LunPath
        size               = $Size
        ostype             = $OsType
        'space-reserve'    = 'disabled'
        'space-allocation' = 'enabled'
    } | Out-Null
    Write-Host "  created LUN $LunPath ($Size, thin, space-allocation on)"
}

function Connect-SanPortal {
    <#  Connect exactly ONE portal unless MPIO is installed. With two portals and
        no MPIO, Windows enumerates the same LUN twice as two disks; mounting
        both is a corruption trap. #>
    param([Parameter(Mandatory)] [string[]] $PortalAddresses)

    Set-Service -Name MSiSCSI -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name MSiSCSI -ErrorAction SilentlyContinue

    $mpio = $false
    try { $mpio = (Get-WindowsFeature -Name 'Multipath-IO' -ErrorAction SilentlyContinue).Installed } catch { }

    $use = if ($mpio) { $PortalAddresses } else { @($PortalAddresses[0]) }
    if (-not $mpio -and $PortalAddresses.Count -gt 1) {
        Write-Host "  MPIO not installed - connecting ONE portal ($($use[0])) of $($PortalAddresses.Count) on purpose"
    }

    foreach ($p in $use) {
        if (-not (Get-IscsiTargetPortal -ErrorAction SilentlyContinue | Where-Object { $_.TargetPortalAddress -eq $p })) {
            New-IscsiTargetPortal -TargetPortalAddress $p | Out-Null
            Write-Host "  added iSCSI portal $p"
        }
    }
    Get-IscsiTargetPortal -ErrorAction SilentlyContinue | Update-IscsiTargetPortal -ErrorAction SilentlyContinue

    foreach ($t in @(Get-IscsiTarget -ErrorAction SilentlyContinue)) {
        if (-not $t.IsConnected) {
            Connect-IscsiTarget -NodeAddress $t.NodeAddress -IsPersistent $true -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  connected target $($t.NodeAddress)"
        }
    }
}

function Wait-SanDisk {
    <#  Find the iSCSI disk for a LUN by its SERIAL, not by "the only iSCSI
        disk": an agent may legitimately see more than one (e.g. a previous
        job's LUN still detaching), and picking the wrong one formats live data.
        ONTAP reports the serial; Windows exposes it as Disk.SerialNumber. #>
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $LunPath,
        [int] $TimeoutSec = 120
    )
    $info = Invoke-Ontap -Ctx $Ctx -Path "/private/cli/lun?vserver=$($Ctx.Svm)&path=$LunPath&fields=serial-hex,serial"
    if ($info.num_records -eq 0) { throw "LUN $LunPath not found." }
    $serial = $info.records[0].serial

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Update-HostStorageCache -ErrorAction SilentlyContinue
        $disk = Get-Disk -ErrorAction SilentlyContinue |
                Where-Object { $_.BusType -eq 'iSCSI' -and $_.SerialNumber -and $serial -and $_.SerialNumber.Trim() -like "*$($serial.Trim())*" } |
                Select-Object -First 1
        if ($disk) { return $disk }
        Start-Sleep -Seconds 2
    }
    throw "iSCSI disk for LUN $LunPath (serial '$serial') did not appear within ${TimeoutSec}s. Is the LUN mapped to THIS host's igroup?"
}

function Mount-SanLun {
    <#  Bring the LUN's disk online and give it $DriveLetter.

        -Format is a SEPARATE, EXPLICIT switch and defaults off. A clone already
        contains NTFS; formatting it destroys exactly the data we cloned. Only
        the initial source-LUN provisioning should ever pass it. #>
    param(
        [Parameter(Mandatory)] $Ctx,
        [Parameter(Mandatory)] [string] $LunPath,
        [Parameter(Mandatory)] [string] $DriveLetter,
        [switch] $Format,
        [string] $FileSystemLabel = 'p4workspace'
    )
    $letter = $DriveLetter.TrimEnd(':')
    $disk = Wait-SanDisk -Ctx $Ctx -LunPath $LunPath

    if ($disk.IsOffline)  { Set-Disk -Number $disk.Number -IsOffline $false }
    if ($disk.IsReadOnly) { Set-Disk -Number $disk.Number -IsReadOnly $false }

    if ($Format) {
        if ($disk.PartitionStyle -ne 'RAW') {
            Write-Host "  disk $($disk.Number) already initialised - NOT reformatting (pass a RAW disk to -Format)"
        } else {
            Write-Host "  initialising + formatting disk $($disk.Number) (explicitly requested)"
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
            $p = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $letter
            Format-Volume -Partition $p -FileSystem NTFS -NewFileSystemLabel $FileSystemLabel -Confirm:$false | Out-Null
            return "${letter}:"
        }
    }

    Update-HostStorageCache -ErrorAction SilentlyContinue
    $part = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue |
            Where-Object { $_.Size -gt 64MB } | Sort-Object -Property Size -Descending | Select-Object -First 1
    if (-not $part) { throw "No usable partition on disk $($disk.Number) for LUN $LunPath. If this is a fresh LUN, provision it with -Format." }

    if ($part.DriveLetter -ne $letter) {
        Set-Partition -DiskNumber $disk.Number -PartitionNumber $part.PartitionNumber -NewDriveLetter $letter
    }
    Write-Host "  LUN $LunPath online as ${letter}: (disk $($disk.Number))"
    return "${letter}:"
}

function Dismount-SanLun {
    <#  Offline the disk BEFORE the LUN map is removed. Yanking a mapped LUN out
        from under a live NTFS volume is how you get dirty-bit surprises on the
        parent snapshot. Tolerates the disk already being gone. #>
    param([Parameter(Mandatory)] $Ctx, [Parameter(Mandatory)] [string] $LunPath)
    try {
        $disk = Wait-SanDisk -Ctx $Ctx -LunPath $LunPath -TimeoutSec 10
        if ($disk) {
            Write-VolumeCache -DriveLetter (Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue |
                Where-Object { $_.DriveLetter } | Select-Object -First 1).DriveLetter -ErrorAction SilentlyContinue
            Set-Disk -Number $disk.Number -IsOffline $true -ErrorAction SilentlyContinue
            Write-Host "  disk $($disk.Number) offlined"
        }
    } catch {
        Write-Host "  no live disk for $LunPath (already detached) - continuing"
    }
}

Export-ModuleMember -Function Enable-OntapCertBypass, Connect-Ontap, Invoke-Ontap, `
    New-OntapCloneName, Get-OntapVolume, New-OntapSnapshot, New-OntapFlexClone, `
    Remove-OntapVolume, Get-LocalIqn, Add-OntapIgroupInitiator, New-OntapLunMap, `
    Remove-OntapLunMap, New-OntapLun, Connect-SanPortal, Wait-SanDisk, `
    Mount-SanLun, Dismount-SanLun
