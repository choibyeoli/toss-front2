@echo off
setlocal EnableExtensions
cd /d "%~dp0"

:MENU
cls
echo.
echo ========================================================
echo   Qualcomm EDL / fastbootd / GSI Toolkit
echo ========================================================
echo.
echo   1. EDL INFO - EDL connection and GPT inspection
echo   2. PATCH PREFLIGHT - verify original hashes only
echo   3. APPLY PATCHES - apply init / ABL / AVB patch plan
echo   4. SET DEBUG FLAGS - write device-specific debug settings
echo   5. BOOT FASTBOOTD - set BCB then reset from EDL
echo   6. FLASH GSI - logical partition plan and GSI flash
echo   7. RESTORE PATCHES - restore patch-plan ranges only
echo.
echo   Q. Quit
echo.
choice /c 1234567Q /n /m "Select"
if errorlevel 8 goto END
if errorlevel 7 goto RESTORE
if errorlevel 6 goto FLASH
if errorlevel 5 goto FASTBOOTD
if errorlevel 4 goto DEBUGFLAGS
if errorlevel 3 goto APPLY
if errorlevel 2 goto PREFLIGHT
if errorlevel 1 goto INFO

:INFO
call "%~dp0run\01-edl-info.cmd"
goto MENU

:PREFLIGHT
call "%~dp0run\02-patch-preflight.cmd"
goto MENU

:APPLY
call "%~dp0run\03-patch-apply.cmd"
goto MENU

:DEBUGFLAGS
call "%~dp0run\04-set-debug-flags.cmd"
goto MENU

:FASTBOOTD
call "%~dp0run\05-boot-fastbootd.cmd"
goto MENU

:FLASH
call "%~dp0run\06-flash-gsi.cmd"
goto MENU

:RESTORE
call "%~dp0run\07-patch-restore.cmd"
goto MENU

:END
endlocal
