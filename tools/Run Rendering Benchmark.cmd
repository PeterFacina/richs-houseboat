@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run Rendering Benchmark.ps1" %*
endlocal
