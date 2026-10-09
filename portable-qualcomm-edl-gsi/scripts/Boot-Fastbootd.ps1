. (Join-Path $PSScriptRoot 'Common.ps1')

$configPath = Join-Path $PatchRoot 'bcb.json'
Assert-File $configPath 'bcb.json'
$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if (-not $cfg.enabled) { throw 'bcb.json is a disabled template. Verify the target BCB location, then set enabled to true.' }
if ($cfg.sector -eq 0 -or $cfg.command_length -lt 16) { throw 'bcb.json is incomplete.' }

$run = Join-Path $BackupRoot ("bcb-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $run | Out-Null
$before = Join-Path $run 'before.bin'
Read-EdlRange $cfg.lun $cfg.sector $cfg.sectors $before
$data = [byte[]](Get-Content -LiteralPath $before -AsByteStream -Raw)
$command = [Text.Encoding]::ASCII.GetBytes([string]$cfg.command)
if ($command.Length -ge $cfg.command_length) { throw 'BCB command is too long for its configured field.' }
if (($cfg.command_offset + $cfg.command_length) -gt $data.Length) { throw 'BCB command field exceeds the configured block.' }
[Array]::Clear($data, $cfg.command_offset, $cfg.command_length)
[Array]::Copy($command, 0, $data, $cfg.command_offset, $command.Length)
$after = Join-Path $run 'boot-fastboot.bin'
[IO.File]::WriteAllBytes($after, $data)
Write-EdlRange $cfg.lun $cfg.sector $after
$verify = Join-Path $run 'verify.bin'
Read-EdlRange $cfg.lun $cfg.sector $cfg.sectors $verify
if ((Get-Sha256 $after) -ne (Get-Sha256 $verify)) { throw 'BCB readback mismatch; refusing reset.' }
Write-Host 'BCB verified. Resetting from EDL; a USB pipe error immediately afterward is expected.'
Invoke-Edl @('reset', '--resetmode=reset')
