. (Join-Path $PSScriptRoot 'Common.ps1')
Write-Host 'Reading GPT from LUN 0. Confirm the device identity and storage layout before any write.'
Invoke-Edl @('printgpt')
