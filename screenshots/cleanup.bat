@echo off
REM Cleanup script for screenshots older than 7 days (Windows)
REM Usage: cleanup.bat

setlocal enabledelayedexpansion
set daysold=7

echo Cleaning up screenshots older than %daysold% days...

for /f %%F in ('dir /b *.png *.jpg 2^>nul') do (
    for /f %%A in ('powershell -Command "(Get-Item '%%F').LastWriteTime | ConvertTo-Json"') do (
        set lastmod=%%A
    )
)

REM PowerShell one-liner version (more reliable)
powershell -Command ^
  "$now = Get-Date; $daysOld = 7; Get-ChildItem -Path $PSScriptRoot -Include *.png, *.jpg | Where-Object { ($now - $_.LastWriteTime).Days -gt $daysOld } | Remove-Item -Force; Write-Host 'Cleanup complete: removed files older than ' $daysOld ' days'"

echo Done.
pause
