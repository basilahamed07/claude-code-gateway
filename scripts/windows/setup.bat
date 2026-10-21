@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Claude Code LLM Gateway - Setup

rem Resolve gateway root directory (two levels up from scripts\windows)
for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
cd /d "%PROJECT_DIR%"

echo.
echo =======================================================
echo     Claude Code Universal LLM Gateway - Setup
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

rem 2. Auto-create .venv inside core/ if missing
set "CORE_DIR=%PROJECT_DIR%\core"
set "VENV_PYTHON=%CORE_DIR%\.venv\Scripts\python.exe"
set "VENV_LITELLM=%CORE_DIR%\.venv\Scripts\litellm.exe"

if not exist "%VENV_LITELLM%" (
    echo [SETUP] Setting up virtual environment and installing dependencies...
    if not exist "%VENV_PYTHON%" (
        echo [SETUP] Creating virtual environment in core\.venv...
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

rem 3. Launch interactive configuration wizard
echo [SETUP] Launching Interactive Configuration Wizard...
echo.
"%VENV_PYTHON%" "%CORE_DIR%\configure.py"
if errorlevel 1 (
    echo.
    echo [WARN] Configuration was cancelled or exited with errors.
    pause
    exit /b 13
)

rem 4. Register gateway directory
echo %PROJECT_DIR%>"%USERPROFILE%\.claude-gateway-root"

echo.
echo =======================================================
echo                   Setup Completed!
echo =======================================================
echo Next steps:
echo   1. Start the gateway server : start.bat
echo   2. Test your model backend  : test.bat
echo   3. Launch Claude Code       : claude.bat (from any folder!)
echo.
pause
endlocal
