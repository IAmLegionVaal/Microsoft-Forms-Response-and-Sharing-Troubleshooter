@echo off
setlocal
cd /d "%~dp0"

:menu
cls
echo ============================================================
echo   MICROSOFT FORMS REPAIR TOOLKIT
echo ============================================================
echo   1. Diagnose only
echo   2. Run safe repair set
echo   3. Restart Microsoft Edge and open Forms
echo   4. Reset Edge browser caches
echo   5. Reset Edge sign-in session
echo   6. Clear temporary internet files
echo   7. Flush DNS cache
echo   8. Open Microsoft Forms
echo   0. Exit
echo ============================================================
set /p CHOICE=Select an option: 

if "%CHOICE%"=="1" set ACTION=Diagnose&goto run
if "%CHOICE%"=="2" set ACTION=RepairAllSafe&goto run
if "%CHOICE%"=="3" set ACTION=RestartBrowser&goto run
if "%CHOICE%"=="4" set ACTION=ResetBrowserCaches&goto run
if "%CHOICE%"=="5" set ACTION=ResetSignInSession&goto run
if "%CHOICE%"=="6" set ACTION=ClearWinInetCache&goto run
if "%CHOICE%"=="7" set ACTION=FlushDns&goto run
if "%CHOICE%"=="8" set ACTION=OpenForms&goto run
if "%CHOICE%"=="0" goto end
goto menu

:run
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%~dp0Repair.ps1' -ErrorAction SilentlyContinue; & '%~dp0Repair.ps1' -Action '%ACTION%'"
echo.
pause
goto menu

:end
endlocal
