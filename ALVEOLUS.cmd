@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\alveolus-workflow.ps1" %*
exit /b %errorlevel%
