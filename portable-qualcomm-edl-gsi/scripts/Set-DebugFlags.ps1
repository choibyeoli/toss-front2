. (Join-Path $PSScriptRoot 'Common.ps1')

$configPath = Join-Path $PatchRoot 'debug-flags.json'
Assert-File $configPath 'debug-flags.json'
$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if (-not $cfg.enabled) { throw 'debug-flags.json is a disabled template. Identify the target storage block and set enabled to true.' }
if (-not $cfg.writes -or $cfg.sector -eq 0) { throw 'debug-flags.json is incomplete.' }

$run = Join-Path $BackupRoot ("debug-flags-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $run | Out-Null
$before = Join-Path $run 'before.bin'
Read-EdlRange $cfg.lun $cfg.sector $cfg.sectors $before
$data = [byte[]](Get-Content -LiteralPath $before -AsByteStream -Raw)

foreach ($write in $cfg.writes) {
    $bytes = [Text.Encoding]::ASCII.GetBytes([string]$write.text)
    if ($bytes.Length -gt $write.length) { throw "Value at offset $($write.offset) is longer than its configured field." }
    if (($write.offset + $write.length) -gt $data.Length) { throw "Value at offset $($write.offset) exceeds the configured read range." }
    [Array]::Clear($data, $write.offset, $write.length)
    [Array]::Copy($bytes, 0, $data, $write.offset, $bytes.Length)
}

$after = Join-Path $run 'after.bin'
[IO.File]::WriteAllBytes($after, $data)
Write-EdlRange $cfg.lun $cfg.sector $after
$verify = Join-Path $run 'verify.bin'
Read-EdlRange $cfg.lun $cfg.sector $cfg.sectors $verify
if ((Get-Sha256 $after) -ne (Get-Sha256 $verify)) { throw 'Debug flag readback mismatch.' }
Write-Host "Debug flags written and verified. Backup/readback folder: $run"
