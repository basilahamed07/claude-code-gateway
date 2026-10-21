@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Claude Code (Custom Gateway)

rem Preserve caller's current working directory (do not cd)
set "GATEWAY_DIR=%~dp0"
if "%GATEWAY_DIR:~-1%"=="\" set "GATEWAY_DIR=%GATEWAY_DIR:~0,-1%"

rem Check parent folder if run from inside scripts\windows
if exist "%GATEWAY_DIR%\..\..\.env" (
    for %%I in ("%GATEWAY_DIR%\..\..") do set "GATEWAY_DIR=%%~fI"
)

rem --- Gateway Discovery ---
if not exist "%GATEWAY_DIR%\.env" (
    if defined CLAUDE_GATEWAY_DIR if exist "%CLAUDE_GATEWAY_DIR%\.env" set "GATEWAY_DIR=%CLAUDE_GATEWAY_DIR%"
)
if not exist "%GATEWAY_DIR%\.env" if exist "%USERPROFILE%\.claude-gateway-root" (
    for /f "usebackq delims=" %%R in ("%USERPROFILE%\.claude-gateway-root") do (
        if exist "%%R\.env" set "GATEWAY_DIR=%%R"
    )
)
if not exist "%GATEWAY_DIR%\.env" (
    echo [ERROR] Could not locate the gateway's ".env" file.
    echo If you copied this script to another folder, either:
    echo   1. Run setup.bat or start.bat once from the gateway directory to register it.
    echo   2. Or set CLAUDE_GATEWAY_DIR to the gateway path:
    echo      setx CLAUDE_GATEWAY_DIR "path\to\claude-code-gateway"
    endlocal & exit /b 40
)

rem --- 1. Locate Claude Code executable (never match this .bat itself) ---
set "CLAUDE_EXE="
set "SELF_PATH=%~f0"

rem Check user override
if defined CLAUDE_PATH if exist "%CLAUDE_PATH%" set "CLAUDE_EXE=%CLAUDE_PATH%"

rem Search PATH for claude.cmd only (never bare "claude" which matches this .bat)
if not defined CLAUDE_EXE (
    for /f "delims=" %%I in ('where claude.cmd 2^>nul') do (
        if not defined CLAUDE_EXE set "CLAUDE_EXE=%%I"
    )
)

rem Check common npm install locations via %APPDATA%
if not defined CLAUDE_EXE if defined APPDATA (
    for /f "delims=" %%A in ("%APPDATA%") do (
        if exist "%%A\npm\claude.cmd" set "CLAUDE_EXE=%%A\npm\claude.cmd"
    )
)

rem Fallback: %LOCALAPPDATA%\npm
if not defined CLAUDE_EXE if defined LOCALAPPDATA (
    for /f "delims=" %%A in ("%LOCALAPPDATA%") do (
        if exist "%%A\npm\claude.cmd" set "CLAUDE_EXE=%%A\npm\claude.cmd"
    )
)

rem Fallback: global nodejs directory
if not defined CLAUDE_EXE (
    if exist "%ProgramFiles%\nodejs\claude.cmd" set "CLAUDE_EXE=%ProgramFiles%\nodejs\claude.cmd"
)

if not defined CLAUDE_EXE (
    echo [ERROR] Claude Code CLI was not found.
    echo Please install it globally via: npm install -g @anthropic-ai/claude-code
    echo Or specify its path by setting CLAUDE_PATH in your environment.
    endlocal & exit /b 41
)

rem --- 2. Load gateway settings from .env ---
for /f "usebackq tokens=1,* delims==" %%A in ("%GATEWAY_DIR%\.env") do (
    if /i "%%A"=="GATEWAY_PORT" set "GATEWAY_PORT=%%B"
    if /i "%%A"=="GATEWAY_MASTER_KEY" set "GATEWAY_MASTER_KEY=%%B"
    if /i "%%A"=="GATEWAY_MODEL_ALIAS" set "GATEWAY_MODEL_ALIAS=%%B"
)

if not defined GATEWAY_PORT set "GATEWAY_PORT=4000"
if not defined GATEWAY_MODEL_ALIAS set "GATEWAY_MODEL_ALIAS=custom-model"

if not defined GATEWAY_MASTER_KEY (
    echo [ERROR] Master key is missing in "%GATEWAY_DIR%\.env".
    endlocal & exit /b 42
)

rem --- 3. Port Selection (Supports multiple running servers) ---
set "PORT_OVERRIDE="
set "FORWARD_ARGS="
set "HAS_PORT_ARG=0"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--port" (
    set "PORT_OVERRIDE=%~2"
    set "HAS_PORT_ARG=1"
    shift
    shift
    goto parse_args
)
if defined FORWARD_ARGS (
    set "FORWARD_ARGS=%FORWARD_ARGS% %1"
) else (
    set "FORWARD_ARGS=%1"
)
shift
goto parse_args
:args_done

rem Check CLAUDE_PORT environment variable
if not defined PORT_OVERRIDE if defined CLAUDE_PORT (
    set "PORT_OVERRIDE=%CLAUDE_PORT%"
)

rem If not overridden by flag or env, ask the user interactively
if not defined PORT_OVERRIDE (
    echo.
    set /p "INPUT_PORT=Which Gateway Port is your LLM listening on? [%GATEWAY_PORT%]: "
    if defined INPUT_PORT set "PORT_OVERRIDE=%INPUT_PORT%"
)

if defined PORT_OVERRIDE set "GATEWAY_PORT=%PORT_OVERRIDE%"
echo [CONNECT] Connecting to Gateway on port %GATEWAY_PORT%...

rem --- 4. Validate Gateway and Discover Models on this Port ---
set "DISCOVERED_MODEL="
for /f "delims=" %%M in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u = 'http://127.0.0.1:' + $env:GATEWAY_PORT + '/v1/models'; " ^
  "$h = @{ Authorization = 'Bearer ' + $env:GATEWAY_MASTER_KEY }; " ^
  "try { " ^
  "  $r = Invoke-RestMethod -Uri $u -Headers $h -TimeoutSec 3; " ^
  "  if ($r.data.Count -gt 0) { " ^
  "    $found = $null; " ^
  "    foreach ($m in $r.data) { if ($m.id -eq $env:GATEWAY_MODEL_ALIAS) { $found = $m.id; break } } " ^
  "    if (-not $found) { $found = $r.data[0].id } " ^
  "    Write-Output $found; " ^
  "    exit 0; " ^
  "  } " ^
  "} catch {}; exit 1"') do (
    set "DISCOVERED_MODEL=%%M"
)

if not defined DISCOVERED_MODEL (
    echo [ERROR] Gateway is not running or rejected the key at http://127.0.0.1:%GATEWAY_PORT%/v1/models
    echo Please make sure the gateway is started on port %GATEWAY_PORT%:
    echo   start.bat %GATEWAY_PORT%
    endlocal & exit /b 45
)

set "ACTIVE_MODEL=%DISCOVERED_MODEL%"
echo [CONNECT] Connected! Active Model: %ACTIVE_MODEL%
echo.

rem --- 5. Set process-scoped Anthropic environment variables for Claude Code ---
set "ANTHROPIC_BASE_URL=http://127.0.0.1:%GATEWAY_PORT%"
set "ANTHROPIC_AUTH_TOKEN=%GATEWAY_MASTER_KEY%"
set "ANTHROPIC_MODEL=%ACTIVE_MODEL%"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=%ACTIVE_MODEL%"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=%ACTIVE_MODEL%"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=%ACTIVE_MODEL%"

rem Prevent interference from native Anthropic API keys
set "ANTHROPIC_API_KEY="
set "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1"
set "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1"
set "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1"
set "CLAUDE_CODE_ATTRIBUTION_HEADER=0"

rem --- 6. Launch Claude Code with caller arguments ---
if "%HAS_PORT_ARG%"=="1" (
    call "%CLAUDE_EXE%" %FORWARD_ARGS%
) else (
    call "%CLAUDE_EXE%" %*
)
set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%
