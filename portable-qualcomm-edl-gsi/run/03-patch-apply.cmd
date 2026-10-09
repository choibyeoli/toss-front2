@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Apply-PatchPlan.ps1" -Mode apply
pause
