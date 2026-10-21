@echo off
setlocal EnableExtensions

rem Resolve gateway root directory (two levels up from scripts\windows)
for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "CORE_DIR=%PROJECT_DIR%\core"
set "STOP_PORT=%~1"

rem Stop litellm processes running from this repository or on the specified port
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$targetPort = $env:STOP_PORT; " ^
  "$coreVenv = Join-Path $env:CORE_DIR '.venv'; " ^
  "$stopped = $false; " ^
  "$procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like ('*' + $coreVenv + '*litellm*') }; " ^
  "if ($procs) { " ^
  "  foreach ($p in $procs) { " ^
  "    try { Stop-Process -Id $p.ProcessId -Force; Write-Host ('Stopped gateway process PID ' + $p.ProcessId); $stopped = $true; } catch {} " ^
  "  } " ^
  "} " ^
  "if ($targetPort) { " ^
  "  try { " ^
  "    $conns = Get-NetTCPConnection -LocalPort $targetPort -State Listen -ErrorAction SilentlyContinue; " ^
  "    foreach ($c in $conns) { " ^
  "      $cp = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + $c.OwningProcess) -ErrorAction SilentlyContinue; " ^
  "      if ($cp -and $cp.CommandLine -like '*litellm*') { " ^
  "        Stop-Process -Id $cp.ProcessId -Force; Write-Host ('Stopped gateway process on port ' + $targetPort + ' PID ' + $cp.ProcessId); $stopped = $true; " ^
  "      } " ^
  "    } " ^
  "  } catch {} " ^
  "} " ^
  "if (-not $stopped) { Write-Host 'No active gateway process found.' }"

del /q "%CORE_DIR%\.gateway*.pid" >nul 2>&1
echo Done.
endlocal
