@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Claude Code LLM Gateway

rem Resolve gateway root directory (two levels up from scripts\windows)
for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
cd /d "%PROJECT_DIR%"

echo.
echo =======================================================
echo          Claude Code Universal LLM Gateway
echo =======================================================
echo Gateway Root: %PROJECT_DIR%
echo.

rem 1. Check or locate Python 64-bit
set "PYTHON_CMD="

where py >nul 2>&1
if not errorlevel 1 (
    for /f %%B in ('py -3 -c "import struct;print(struct.calcsize('P')*8)" 2^>nul') do if "%%B"=="64" set "PYTHON_CMD=py -3"
)
if defined PYTHON_CMD goto :python_found

where python >nul 2>&1
if not errorlevel 1 (
    for /f %%B in ('python -c "import struct;print(struct.calcsize('P')*8)" 2^>nul') do if "%%B"=="64" set "PYTHON_CMD=python"
)
if defined PYTHON_CMD goto :python_found

echo [ERROR] 64-bit Python 3.10+ was not found on PATH.
echo Please install 64-bit Python from https://www.python.org/downloads/
pause
exit /b 10

:python_found

rem 2. Auto-create .venv inside core/ if missing or invalid
set "CORE_DIR=%PROJECT_DIR%\core"
set "VENV_PYTHON=%CORE_DIR%\.venv\Scripts\python.exe"
set "VENV_LITELLM=%CORE_DIR%\.venv\Scripts\litellm.exe"

if not exist "%VENV_LITELLM%" (
    echo [SETUP] Setting up virtual environment and installing dependencies...
    if not exist "%VENV_PYTHON%" (
        echo [SETUP] Creating core\.venv...
        %PYTHON_CMD% -m venv "%CORE_DIR%\.venv"
        if errorlevel 1 (
            echo [ERROR] Failed to create virtual environment.
            pause
            exit /b 11
        )
    )
    echo [SETUP] Installing requirements - this may take a minute on first run...
    "%VENV_PYTHON%" -m pip install --upgrade pip >nul 2>&1
    "%VENV_PYTHON%" -m pip install -r "%CORE_DIR%\requirements.txt"
    if errorlevel 1 (
        echo [ERROR] Dependency installation failed.
        pause
        exit /b 12
    )
    echo [SETUP] Dependencies installed successfully.
    echo.
)

rem 3. Check for .env or trigger setup wizard
if not exist "%PROJECT_DIR%\.env" (
    echo [INFO] No .env found. Starting interactive configuration wizard...
    "%VENV_PYTHON%" "%CORE_DIR%\configure.py"
    if not exist "%PROJECT_DIR%\.env" (
        echo [ERROR] Configuration was not completed. Exiting.
        pause
        exit /b 13
    )
)

rem 4. Load all environment variables from .env
for /f "usebackq tokens=1,* delims==" %%A in ("%PROJECT_DIR%\.env") do (
    set "%%A=%%B"
)
if not defined GATEWAY_PORT set "GATEWAY_PORT=4000"

rem Check for command line port override (e.g. start.bat 4001 or start.bat --port 4001)
if not "%~1"=="" (
    if /i "%~1"=="--port" (
        if not "%~2"=="" set "GATEWAY_PORT=%~2"
    ) else (
        set "GATEWAY_PORT=%~1"
    )
)

rem 5. Validate Master Key
if not defined GATEWAY_MASTER_KEY (
    echo [ERROR] GATEWAY_MASTER_KEY is missing from .env.
    echo Run: setup.bat to configure.
    pause
    exit /b 14
)

rem 6. Set UTF-8 encoding for Windows Python console
set "PYTHONIOENCODING=utf-8"
set "PYTHONUTF8=1"

rem 7. Register this directory so claude.bat can find it from any folder
echo %PROJECT_DIR%>"%USERPROFILE%\.claude-gateway-root"

echo Gateway Port : %GATEWAY_PORT%
echo Model Alias  : %GATEWAY_MODEL_ALIAS%
echo Binding to   : 127.0.0.1:%GATEWAY_PORT%
echo.
echo Leave this window open while using Claude Code.
echo Press Ctrl+C or run stop.bat to shut down.
echo.

rem 8. Run LiteLLM proxy from core/ and record PID
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$litellm = Join-Path $env:CORE_DIR '.venv\Scripts\litellm.exe'; " ^
  "$config  = Join-Path $env:CORE_DIR 'config.yaml'; " ^
  "$pidFile = Join-Path $env:CORE_DIR '.gateway.pid'; " ^
  "$env:PYTHONIOENCODING = 'utf-8'; " ^
  "$env:PYTHONUTF8 = '1'; " ^
  "$argsList = @('--config', 'core\config.yaml', '--host', '127.0.0.1', '--port', $env:GATEWAY_PORT); " ^
  "$proc = Start-Process -FilePath $litellm -ArgumentList $argsList -WorkingDirectory $env:PROJECT_DIR -NoNewWindow -PassThru; " ^
  "$proc.Id | Set-Content -LiteralPath $pidFile -Encoding ascii; " ^
  "Write-Host ('Gateway running on PID ' + $proc.Id); " ^
  "try { Wait-Process -Id $proc.Id } finally { Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue }"

set "EXIT_CODE=%ERRORLEVEL%"
pause
endlocal & exit /b %EXIT_CODE%
