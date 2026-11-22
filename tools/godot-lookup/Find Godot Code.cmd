@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Find-GodotCode.ps1" %*
exit /b %errorlevel%
