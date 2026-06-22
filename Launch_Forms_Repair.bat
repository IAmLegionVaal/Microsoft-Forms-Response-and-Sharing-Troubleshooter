@echo off
setlocal
cd /d "%~dp0"

:menu
set "ACTION="
cls
echo ============================================================
echo   MICROSOFT FORMS REPAIR TOOLKIT
echo ============================================================
echo   1. Diagnose only
echo   2. Run safe repair set
echo   3. Restart Microsoft Edge and open Forms
echo   4. Rebuild Edge browser caches
echo   5. Reset Edge sign-in session
echo   6. Clear temporary internet files
echo   7. Flush DNS cache
echo   8. Open Microsoft Forms
echo   0. Exit
echo ============================================================
set /p CHOICE=Select an option: 

if "%CHOICE%"=="1" set "ACTION=Diagnose"
if "%CHOICE%"=="2" set "ACTION=RepairAllSafe"
if "%CHOICE%"=="3" set "ACTION=RestartBrowser"
if "%CHOICE%"=="4" set "ACTION=ResetBrowserCaches"
if "%CHOICE%"=="5" set "ACTION=ResetSignInSession"
if "%CHOICE%"=="6" set "ACTION=ClearWinInetCache"
if "%CHOICE%"=="7" set "ACTION=FlushDns"
if "%CHOICE%"=="8" set "ACTION=OpenForms"
if "%CHOICE%"=="0" goto end
if not defined ACTION goto menu

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair.ps1" -Action "%ACTION%"
echo.
pause
goto menu

:end
endlocal
