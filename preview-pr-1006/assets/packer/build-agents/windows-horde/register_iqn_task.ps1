<#
    register_iqn_task.ps1 - IMAGE-TIME step (runs during the Packer build, NOT at
    boot). It bakes the ONSTART trigger that runs set_unique_iqn.ps1 on EVERY boot.

    The per-boot LOGIC lives in C:\ProgramData\horde\set_unique_iqn.ps1 (dropped
    onto the image by the Packer file provisioner). This step only REGISTERS the
    Scheduled Task that invokes that fixed path:
      * Trigger:  AtStartup (ONSTART) - fires on every boot, before any Horde job.
      * Principal: SYSTEM, RunLevel Highest (needs admin to Set-InitiatorPort).
      * Action:   powershell.exe -File C:\ProgramData\horde\set_unique_iqn.ps1

    validate_image.ps1 asserts BOTH the task and the script file exist, so the
    build fails if either is missing.
#>

$ErrorActionPreference = 'Stop'

function Write($message) { Write-Output $message }

$TaskName   = 'Horde-SetUniqueIqn'
$ScriptPath = 'C:\ProgramData\horde\set_unique_iqn.ps1'

if (-not (Test-Path $ScriptPath)) {
    throw "Expected baked script not found at $ScriptPath - the file provisioner must run before this step."
}

Write "Registering ONSTART Scheduled Task '$TaskName' -> $ScriptPath"

# Remove any pre-existing task so the build is idempotent.
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write "Removing existing task '$TaskName' before re-registration"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings `
    -Description 'Materialise a unique, instance-id-derived iSCSI initiator IQN on every boot (input-free).' | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
Write "Registered task '$($task.TaskName)' (State=$($task.State))"
Write "Boot-time unique-IQN task registration complete."
