@echo off

rem Set the PowerShell script name
set "ps_script=compress.ps1"

rem Check if the PowerShell script exists
if not exist "%ps_script%" (
    echo [ERROR] PowerShell script "%ps_script%" not found.
    pause
    exit /b 1
)

rem Run the PowerShell script with bypass execution policy
echo [INFO] Running PowerShell script: %ps_script%
powershell -NoProfile -ExecutionPolicy Bypass -File "%ps_script%"

rem Pause for user input
pause
