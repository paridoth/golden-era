@echo off
setlocal DisableDelayedExpansion
set "GE_ROOT=%~dp0"
if defined GOLDEN_ERA_DATA_DIR (
  set "GE_DATA=%GOLDEN_ERA_DATA_DIR%"
) else (
  set "GE_DATA=%LOCALAPPDATA%\GoldenEraPlaytest"
)
if not exist "%GE_DATA%\worlds\playtest" mkdir "%GE_DATA%\worlds\playtest"
if not exist "%GE_DATA%\logs" mkdir "%GE_DATA%\logs"
if not exist "%GE_DATA%\settings.conf" copy /y "%GE_ROOT%defaults\playtest.conf" "%GE_DATA%\settings.conf" >nul
if not exist "%GE_DATA%\worlds\playtest\world.mt" (
  >"%GE_DATA%\worlds\playtest\world.mt" (
    echo gameid = golden_era_playtest
    echo backend = sqlite3
    echo player_backend = sqlite3
    echo auth_backend = sqlite3
    echo mod_storage_backend = sqlite3
  )
)
if not exist "%GE_DATA%\engine-5.17.0\bin\luanti.exe" (
  echo Downloading the official Luanti engine once, about 18 MB...
  powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $spec=(Get-Content -LiteralPath (Join-Path $env:GE_ROOT 'engine-downloads.json') -Raw | ConvertFrom-Json).windows_x86_64; $stage=Join-Path $env:GE_DATA ('download-' + [Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $stage | Out-Null; try { $zip=Join-Path $stage 'engine.zip'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $spec.url -OutFile $zip; if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $spec.sha256) { throw 'Engine download checksum mismatch; nothing will be launched.' }; Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $stage 'extracted'); $engine=Join-Path (Join-Path $stage 'extracted') $spec.archive_root; if (-not (Test-Path -LiteralPath (Join-Path $engine 'bin\luanti.exe'))) { throw 'Expected engine executable is missing.' }; $target=Join-Path $env:GE_DATA 'engine-5.17.0'; $executable=Join-Path $target 'bin\luanti.exe'; if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $executable)) { $backup=Join-Path $env:GE_DATA ('engine-5.17.0-incomplete-' + [Guid]::NewGuid().ToString('N')); [IO.Directory]::Move($target,$backup) }; if (-not (Test-Path -LiteralPath $executable)) { try { [IO.Directory]::Move($engine,$target) } catch { if (-not (Test-Path -LiteralPath $executable)) { throw } } } } finally { Remove-Item -LiteralPath $stage -Recurse -Force }"
  if errorlevel 1 goto failed
)
set "LUANTI_GAME_PATH=%GE_ROOT%games"
set "LUANTI_USER_PATH=%GE_DATA%\engine-user"
"%GE_DATA%\engine-5.17.0\bin\luanti.exe" --go --gameid golden_era_playtest --world "%GE_DATA%\worlds\playtest" --config "%GE_DATA%\settings.conf" --logfile "%GE_DATA%\logs\client.log" --name Tester
if errorlevel 1 goto failed
exit /b 0
:failed
echo.
echo Golden Era could not start. See START-HERE.txt and the log at:
echo "%GE_DATA%\logs\client.log"
pause
exit /b 1
