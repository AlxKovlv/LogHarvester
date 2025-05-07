@echo off
setlocal
title Logs Harvester
cls
echo. 
echo ===============================================================
echo                     Starting Log Harvest
echo ===============================================================
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0harvest-logs.ps1"
set "exitCode=%ERRORLEVEL%"
echo ===============================================================
if "%exitCode%"=="0" (
    echo             Log Harvest Completed Successfully.
) else if "%exitCode%"=="1" (
    echo [ERROR] Configuration file not found. Please check config.json.
) else if "%exitCode%"=="2" (
    echo [ERROR] Unsupported HarvestMode detected in configuration.
) else if "%exitCode%"=="3" (
    echo [ERROR] Unsupported FileNameFormat detected in configuration.
) else if "%exitCode%"=="4" (
    echo [ERROR] Unreachable remote machines detected. Please check connectivity.
) else if "%exitCode%"=="5" (
    echo [WARNING] One or more log files were missing during harvest.
) else (
    echo [ERROR] An unknown error occurred. Exit Code: %exitCode%
)
echo ===============================================================
echo. 
pause
exit /b %exitCode%
