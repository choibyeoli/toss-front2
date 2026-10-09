$ErrorActionPreference = 'Stop'

$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$EdlRoot = Join-Path $ToolkitRoot 'tools\edl'
$EdlPy = Join-Path $EdlRoot 'edl.py'
$Firehose = Join-Path $EdlRoot 'firehose.elf'
$Fastboot = Join-Path $ToolkitRoot 'tools\platform-tools\fastboot.exe'
$PatchRoot = Join-Path $ToolkitRoot 'inputs\patches'
$BackupRoot = Join-Path $ToolkitRoot 'backups'
$LogRoot = Join-Path $ToolkitRoot 'logs'

New-Item -ItemType Directory -Force -Path $BackupRoot,$LogRoot | Out-Null

function Assert-File([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label is missing: $Path"
    }
}

function Get-PythonCommand {
    $candidate = Get-Command python -ErrorAction SilentlyContinue
    if (-not $candidate) { throw 'Python 3 is required but was not found in PATH.' }
    return $candidate.Source
}

function Assert-EdlTools {
    Assert-File $EdlPy 'edl.py'
    Assert-File $Firehose 'firehose.elf'
}

function Invoke-Edl([string[]]$Arguments) {
    Assert-EdlTools
    $python = Get-PythonCommand
    $log = Join-Path $LogRoot ("edl-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    & $python $EdlPy '--loader' $Firehose '--memory=ufs' @Arguments 2>&1 | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) { throw "EDL command failed. Log: $log" }
}

function Invoke-Fastboot([string[]]$Arguments) {
    Assert-File $Fastboot 'fastboot.exe'
    & $Fastboot @Arguments
    if ($LASTEXITCODE -ne 0) { throw "fastboot command failed: fastboot $($Arguments -join ' ')" }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-Sha256([string]$Path, [string]$Expected, [string]$Label) {
    if ($Expected -notmatch '^[0-9a-fA-F]{64}$') { throw "$Label has no valid SHA-256 in its JSON plan." }
    $actual = Get-Sha256 $Path
    if ($actual -ne $Expected.ToLowerInvariant()) { throw "$Label SHA-256 mismatch. Expected $Expected, got $actual" }
}

function Read-EdlRange([int]$Lun, [UInt64]$Sector, [int]$Sectors, [string]$Output) {
    Invoke-Edl @("--lun=$Lun", 'rs', "$Sector", "$Sectors", $Output)
}

function Write-EdlRange([int]$Lun, [UInt64]$Sector, [string]$Input) {
    Invoke-Edl @("--lun=$Lun", 'ws', "$Sector", $Input)
}
