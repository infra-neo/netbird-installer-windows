@echo off
REM Netbird Windows Installer Batch Launcher
REM This batch file checks for administrator privileges and launches the PowerShell installer

REM Check for administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as Administrator
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Launch PowerShell script with execution policy bypass
echo Starting Netbird installer...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*

REM Check if PowerShell script succeeded
if %errorlevel% neq 0 (
    echo.
    echo Installation failed. Please check the error messages above.
    pause
    exit /b %errorlevel%
)

echo.
echo Installation completed!
pause
