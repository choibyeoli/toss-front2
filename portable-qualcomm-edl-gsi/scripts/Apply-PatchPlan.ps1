param(
    [ValidateSet('preflight','apply','restore')][string]$Mode = 'preflight'
)
. (Join-Path $PSScriptRoot 'Common.ps1')

$planPath = Join-Path $PatchRoot 'patch-plan.json'
Assert-File $planPath 'patch-plan.json'
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
if (-not $plan.entries -or $plan.entries.Count -eq 0) { throw 'patch-plan.json has no entries.' }
if ($plan.entries[0].original -eq 'example_init_original.bin') { throw 'Replace the template patch-plan.json with a target-device plan.' }

$run = Join-Path $BackupRoot ("patch-plan-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $run | Out-Null

$items = @($plan.entries)
if ($Mode -eq 'restore') { [array]::Reverse($items) }

foreach ($entry in $items) {
    $original = Join-Path $PatchRoot $entry.original
    $modified = Join-Path $PatchRoot $entry.modified
    Assert-File $original "Original for $($entry.label)"
    Assert-File $modified "Modified for $($entry.label)"
    Assert-Sha256 $original $entry.original_sha256 "Original file for $($entry.label)"
    Assert-Sha256 $modified $entry.modified_sha256 "Modified file for $($entry.label)"

    $before = Join-Path $run ("{0}-before.bin" -f $entry.label)
    Read-EdlRange $entry.lun $entry.sector $entry.sectors $before
    $live = Get-Sha256 $before
    $expected = if ($Mode -eq 'apply') { $entry.original_sha256 } else { $entry.modified_sha256 }
    if ($Mode -eq 'preflight') { $expected = $entry.original_sha256 }
    if ($live -ne $expected.ToLowerInvariant()) {
        throw "$($entry.label) does not match the expected live hash. Refusing to write. Readback: $before"
    }
    Write-Host "Verified $($entry.label)"
    if ($Mode -eq 'preflight') { continue }

    $payload = if ($Mode -eq 'apply') { $modified } else { $original }
    Write-EdlRange $entry.lun $entry.sector $payload
    $verify = Join-Path $run ("{0}-verify.bin" -f $entry.label)
    Read-EdlRange $entry.lun $entry.sector $entry.sectors $verify
    $wanted = if ($Mode -eq 'apply') { $entry.modified_sha256 } else { $entry.original_sha256 }
    Assert-Sha256 $verify $wanted "Readback for $($entry.label)"
    Write-Host "Written and verified $($entry.label)"
}

Write-Host "Patch plan $Mode complete. Backup/readback folder: $run"
