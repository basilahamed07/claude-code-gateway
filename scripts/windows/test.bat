@echo off
setlocal EnableExtensions

rem Resolve gateway root directory (two levels up from scripts\windows)
for %%I in ("%~dp0..\..") do set "PROJECT_DIR=%%~fI"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "CORE_DIR=%PROJECT_DIR%\core"
set "VENV_PYTHON=%CORE_DIR%\.venv\Scripts\python.exe"

set "PYTHONIOENCODING=utf-8"
set "PYTHONUTF8=1"

rem Load .env variables into this process
for /f "usebackq tokens=1,* delims==" %%A in ("%PROJECT_DIR%\.env") do (
    set "%%A=%%B"
)

if not exist "%VENV_PYTHON%" (
    echo [ERROR] Virtual environment not found. Run setup.bat first.
    pause
    exit /b 1
)

echo Running gateway diagnostics...
echo.
"%VENV_PYTHON%" "%CORE_DIR%\test-connection.py"
set "EXIT_CODE=%ERRORLEVEL%"
pause
endlocal & exit /b %EXIT_CODE%
