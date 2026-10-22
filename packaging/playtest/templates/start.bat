@echo off
setlocal DisableDelayedExpansion
set "GE_ROOT=%~dp0"
if defined GOLDEN_ERA_DATA_DIR (
  set "GE_DATA=%GOLDEN_ERA_DATA_DIR%"
) else (
  set "GE_DATA=%LOCALAPPDATA%\GoldenEraPlaytest"
)
rem Refuse foreign or incomplete saves before creating settings or downloading an engine.
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; try { $world=Join-Path $env:GE_DATA 'worlds\playtest'; $meta=Join-Path $world 'world.mt'; if (Test-Path -LiteralPath $meta) { $game=$null; foreach ($line in ([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($meta)) -split '\n')) { if ($line -cmatch '^[ \t\r\v\f]*#') { continue }; if ($line -cmatch '^[^=]*=[ \t\r\v\f]*(\{|\x22{3})[ \t\r\v\f]*$') { throw 'This world.mt uses structured settings. Choose a different GOLDEN_ERA_DATA_DIR or restore its flat Golden Era metadata; existing files were left unchanged.' }; if ($line -cmatch '^[ \t\r\v\f]*gameid[ \t\r\v\f]*=[ \t\r\v\f]*(.*?)[ \t\r\v\f]*$') { $game=$matches[1] } }; if ($game -cne 'golden_era_playtest') { throw 'This save belongs to another game or has no Golden Era game ID. Choose a different GOLDEN_ERA_DATA_DIR; existing files were left unchanged.' } } else { foreach ($name in @('map.sqlite','map.db','map.sqlite-wal','map_meta.txt','players.sqlite','auth.sqlite','auth.txt','mod_storage.sqlite','players')) { if (Test-Path -LiteralPath (Join-Path $world $name)) { throw 'This save has world data but no world.mt. Restore its world.mt or choose a different GOLDEN_ERA_DATA_DIR; existing files were left unchanged.' } } } } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }"
if errorlevel 1 goto worldfailed
if not exist "%GE_DATA%\worlds\playtest" mkdir "%GE_DATA%\worlds\playtest"
if not exist "%GE_DATA%\logs" mkdir "%GE_DATA%\logs"
if not exist "%GE_DATA%\settings.conf" copy /y "%GE_ROOT%defaults\playtest.conf" "%GE_DATA%\settings.conf" >nul
rem 0.1.8 opens LAN hosting and adds menu and Minecraft-style key defaults once; other tester settings stay.
rem The progress window below reads per-mod lines, which need the info log level unless a tester chose another.
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; try { $path=Join-Path $env:GE_DATA 'settings.conf'; $lines=@([IO.File]::ReadAllLines($path)); $kept=$lines; $changed=$false; if ($lines -cnotcontains 'golden_era_settings = 2') { $defaults=@([IO.File]::ReadAllLines((Join-Path $env:GE_ROOT 'defaults\playtest.conf'))); $kept=@($lines | Where-Object { $_ -cne 'bind_address = 127.0.0.1' -and $_ -cne 'port = 30200' }); foreach ($key in @('menu_last_game','keymap_inventory','keymap_aux1','default_privs')) { if (-not @($kept -cmatch ('^[ \t]*' + $key + '[ \t]*=')).Count) { $kept += @($defaults -cmatch ('^' + $key + ' =')) } }; $kept += 'golden_era_settings = 2'; $changed=$true }; if (-not @($kept -cmatch '^[ \t]*debug_log_level[ \t]*=').Count) { $kept += 'debug_log_level = info'; $changed=$true }; if ($changed) { $temp=$path + '.new'; [IO.File]::WriteAllLines($temp, [string[]]$kept); [IO.File]::Copy($temp, $path, $true); [IO.File]::Delete($temp) } } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }"
if errorlevel 1 goto failed
if not exist "%GE_DATA%\worlds\playtest\world.mt" (
  >"%GE_DATA%\worlds\playtest\world.mt" echo gameid = golden_era_playtest
  >>"%GE_DATA%\worlds\playtest\world.mt" echo backend = sqlite3
  >>"%GE_DATA%\worlds\playtest\world.mt" echo player_backend = sqlite3
  >>"%GE_DATA%\worlds\playtest\world.mt" echo auth_backend = sqlite3
  >>"%GE_DATA%\worlds\playtest\world.mt" echo mod_storage_backend = sqlite3
)
if not exist "%GE_DATA%\engine-5.17.0\bin\luanti.exe" (
  echo Downloading the official Luanti engine once, about 18 MB...
  powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $spec=(Get-Content -LiteralPath (Join-Path $env:GE_ROOT 'engine-downloads.json') -Raw | ConvertFrom-Json).windows_x86_64; $stage=Join-Path $env:GE_DATA ('download-' + [Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $stage | Out-Null; try { $zip=Join-Path $stage 'engine.zip'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $spec.url -OutFile $zip; if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $spec.sha256) { throw 'Engine download checksum mismatch; nothing will be launched.' }; Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $stage 'extracted'); $engine=Join-Path (Join-Path $stage 'extracted') $spec.archive_root; if (-not (Test-Path -LiteralPath (Join-Path $engine 'bin\luanti.exe'))) { throw 'Expected engine executable is missing.' }; $target=Join-Path $env:GE_DATA 'engine-5.17.0'; $executable=Join-Path $target 'bin\luanti.exe'; if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $executable)) { $backup=Join-Path $env:GE_DATA ('engine-5.17.0-incomplete-' + [Guid]::NewGuid().ToString('N')); [IO.Directory]::Move($target,$backup) }; if (-not (Test-Path -LiteralPath $executable)) { try { [IO.Directory]::Move($engine,$target) } catch { if (-not (Test-Path -LiteralPath $executable)) { throw } } } } finally { Remove-Item -LiteralPath $stage -Recurse -Force }"
  if errorlevel 1 goto failed
)
rem The portable engine lists menu worlds beside itself and ignores LUANTI_USER_PATH.
rem Link that folder to the save folder; rmdir only removes an empty folder.
if not exist "%GE_DATA%\engine-5.17.0\worlds\playtest\world.mt" (
  rmdir "%GE_DATA%\engine-5.17.0\worlds" 2>nul
  mklink /J "%GE_DATA%\engine-5.17.0\worlds" "%GE_DATA%\worlds" >nul 2>nul
)
set "LUANTI_GAME_PATH=%GE_ROOT%games"
rem Non-portable engines use this as their user folder, which holds the same worlds.
set "LUANTI_USER_PATH=%GE_DATA%"
rem Show loading progress from the new part of the log in this window. The game runs
rem the same without it; the reader stops when the launcher writes launcher.stop.
set "GE_LOG_START="
for %%F in ("%GE_DATA%\logs\client.log") do set "GE_LOG_START=%%~zF"
if not defined GE_LOG_START set "GE_LOG_START=0"
del "%GE_DATA%\logs\launcher.stop" 2>nul
echo Golden Era is starting. Loading progress appears here.
start "" /b powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; try { $log=Join-Path $env:GE_DATA 'logs\client.log'; $stop=Join-Path $env:GE_DATA 'logs\launcher.stop'; $pos=[int64]$env:GE_LOG_START; $rest=''; $stage=''; $start=Get-Date; $done=0; $width=[Math]::Max(20,[Math]::Min(100,[Console]::BufferWidth)-1); function Show($text,$keep) { $text=$text.PadRight($width).Substring(0,$width); if ($keep) { [Console]::WriteLine([char]13 + $text) } else { [Console]::Write([char]13 + $text) } }; function Stage($text) { $script:stage=$text; $script:start=Get-Date }; while ($true) { $finished=Test-Path -LiteralPath $stop; if (Test-Path -LiteralPath $log) { $stream=[IO.File]::Open($log,'Open','Read','ReadWrite,Delete'); try { if ($stream.Length -lt $pos) { $pos=0 }; $stream.Position=$pos; $reader=New-Object IO.StreamReader($stream); $text=$rest + $reader.ReadToEnd(); $pos=$stream.Length } finally { $stream.Dispose() }; $parts=$text -split [char]10; $rest=$parts[-1]; for ($i=0; $i -lt $parts.Count-1; $i++) { $line=$parts[$i]; if ($line -cmatch 'Server: Loading mods:') { $done=0; Show 'Starting the world...' $true; Stage 'Loading mods' } elseif ($line -cmatch 'Mod \x22([^\x22]+)\x22 loaded after') { $done++; $script:stage='Loading mods: {0} done, now {1}' -f $done,$matches[1] } elseif ($line -cmatch 'All mods loaded after (\d+) ms') { Show ('All {0} mods loaded in {1} seconds.' -f $done,[Math]::Round([int64]$matches[1]/1000)) $true; Stage 'Checking textures and sounds' } elseif ($line -cmatch 'Server: (\d+) media files collected') { Show ('Found {0} textures and sounds.' -f $matches[1]) $true; Stage 'Starting the world' } elseif ($line -cmatch 'Preparing stronghold placement') { Stage 'Placing strongholds' } elseif ($line -cmatch 'Connecting to server at') { Stage 'Connecting to the world' } elseif ($line -cmatch 'Received media announcement') { Stage 'Loading textures and sounds' } elseif ($line -cmatch 'afterContentReceived\(\) started') { Stage 'Preparing blocks and items' } elseif ($line -cmatch 'afterContentReceived\(\) done') { Show 'Ready: the world is open. Have fun! This window can stay in the background.' $true; $stage='' } elseif ($line -cmatch 'Server: Shutting down') { Show 'Saving and closing the world...' $true; $stage='' } elseif ($line -cmatch 'ERROR\[[^\]]*\]: (.*)') { Show ('Problem: ' + $matches[1]) $true } } }; if ($finished) { if ($stage) { Show '' $false; [Console]::Write([char]13) }; [IO.File]::Delete($stop); break }; if ($stage) { Show ('{0}... {1}s' -f $stage,[int]((Get-Date)-$start).TotalSeconds) $false }; Start-Sleep -Milliseconds 250 } } catch { exit 0 }"
rem No arguments opens the main menu; arguments such as --go or --server use the playtest world.
if "%~1"=="" (
  "%GE_DATA%\engine-5.17.0\bin\luanti.exe" --config "%GE_DATA%\settings.conf" --logfile "%GE_DATA%\logs\client.log"
) else (
  "%GE_DATA%\engine-5.17.0\bin\luanti.exe" --gameid golden_era_playtest --world "%GE_DATA%\worlds\playtest" --config "%GE_DATA%\settings.conf" --logfile "%GE_DATA%\logs\client.log" %*
)
set "GE_EXIT=%errorlevel%"
>"%GE_DATA%\logs\launcher.stop" echo done
if not "%GE_EXIT%"=="0" goto failed
exit /b 0
:worldfailed
echo.
echo Golden Era did not open this save. See the message above.
pause
exit /b 1
:failed
echo.
echo Golden Era could not start. See START-HERE.txt and the log at:
echo "%GE_DATA%\logs\client.log"
pause
exit /b 1
