@echo off
setlocal
 title Evil Nun - Offline Game
where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo Windows PowerShell was not found. This launcher is designed for Windows.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Root "%~dp0"
if errorlevel 1 pause
endlocal
