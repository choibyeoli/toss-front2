. (Join-Path $PSScriptRoot 'Common.ps1')

$planPath = Join-Path $ToolkitRoot 'inputs\gsi\gsi-plan.json'
Assert-File $planPath 'gsi-plan.json'
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
$image = Join-Path $ToolkitRoot (Join-Path 'inputs\gsi' $plan.system_image)
Assert-File $image 'GSI system image'

Write-Host 'Checking fastbootd connection...'
Invoke-Fastboot @('devices')
$mode = & $Fastboot 'getvar' 'is-userspace' 2>&1
$mode | ForEach-Object { Write-Host $_ }
if (($mode -join "`n") -notmatch 'is-userspace:\s*yes') { throw 'This is not fastbootd. Stop and boot fastbootd first.' }

Write-Host "GSI: $image"
Write-Host "Target logical partition: $($plan.flash_partition)"
Write-Host "Partitions to delete: $($plan.delete_logical_partitions -join ', ')"
$answer = Read-Host 'This can make the device unbootable. Type FLASH to continue'
if ($answer -cne 'FLASH') { Write-Host 'Cancelled.'; exit 0 }

if ($plan.wipe_before_flash) { Invoke-Fastboot @('-w') }
foreach ($partition in @($plan.delete_logical_partitions)) {
    if ([string]::IsNullOrWhiteSpace($partition)) { continue }
    Invoke-Fastboot @('delete-logical-partition', $partition)
}
Invoke-Fastboot @('flash', $plan.flash_partition, $image)
if ($plan.wipe_after_flash) { Invoke-Fastboot @('-w') }
Write-Host 'GSI flash completed. Reboot when ready with: fastboot reboot'
