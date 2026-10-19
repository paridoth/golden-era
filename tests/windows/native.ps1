# SPDX-License-Identifier: GPL-3.0-or-later
# Developer fixture: execute the current launcher under native Windows cmd.exe.
param(
    [string]$RepoRoot,
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    throw 'This regression requires native Windows. Parser/helper checks on Linux do not establish a native Windows result.'
}
if (-not $RepoRoot) {
    if (-not $PSScriptRoot) { throw 'Supply -RepoRoot when executing the script text interactively.' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$templateRoot = Join-Path $RepoRoot 'packaging\playtest\templates'
$batchSource = Join-Path $templateRoot 'start.bat'
if (-not (Test-Path -LiteralPath $batchSource -PathType Leaf)) { throw 'RepoRoot does not contain the launcher template.' }
$testBase = Join-Path $RepoRoot 'runtime\tests'
[IO.Directory]::CreateDirectory($testBase) | Out-Null
$testWork = Join-Path $testBase ('wn-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
[IO.Directory]::CreateDirectory($testWork) | Out-Null
$compileTemp = Join-Path $testWork 'compiler-temp'
[IO.Directory]::CreateDirectory($compileTemp) | Out-Null
$previousTemp = [Environment]::GetEnvironmentVariable('TEMP', 'Process')
$previousTmp = [Environment]::GetEnvironmentVariable('TMP', 'Process')
[Environment]::SetEnvironmentVariable('TEMP', $compileTemp, 'Process')
[Environment]::SetEnvironmentVariable('TMP', $compileTemp, 'Process')
$utf8 = New-Object Text.UTF8Encoding($false)
$report = New-Object 'Collections.Generic.List[string]'
$report.Add('Native Windows launcher regression using harmless local fixtures')
$report.Add('PowerShell: ' + $PSVersionTable.PSVersion + '; edition: ' + $PSVersionTable.PSEdition)
$report.Add('Launcher SHA256: ' + (Get-FileHash -LiteralPath $batchSource -Algorithm SHA256).Hash.ToLowerInvariant())
$fixtureServer = $null
$testPassed = $false

function Assert-NativeTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-TestSnapshot([string]$Directory) {
    $items = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Directory)) { return 'ABSENT' }
    Get-ChildItem -LiteralPath $Directory -Force -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($Directory.Length).TrimStart('\')
        if ($_.PSIsContainer) { $items[$relative] = 'directory' }
        else { $items[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
    return ($items | ConvertTo-Json -Compress)
}

try {
    # .NET Framework/C# syntax deliberately stays compatible with PowerShell 5.1.
    $stubCode = @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
public static class GoldenEraNativeFixture {
    static string Encode(string value) {
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(value ?? ""));
    }
    public static int Main(string[] args) {
        var records = new List<string>();
        records.Add("GAME " + Encode(Environment.GetEnvironmentVariable("LUANTI_GAME_PATH")));
        records.Add("USER " + Encode(Environment.GetEnvironmentVariable("LUANTI_USER_PATH")));
        foreach (string value in args) records.Add("ARG " + Encode(value));
        File.WriteAllLines(Environment.GetEnvironmentVariable("GE_NATIVE_CAPTURE"), records.ToArray(), new UTF8Encoding(false));
        return 0;
    }
}
'@
    $stubExe = Join-Path $testWork 'fixture-luanti.exe'
    Add-Type -TypeDefinition $stubCode -OutputAssembly $stubExe -OutputType ConsoleApplication

    $serverCode = @'
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
public sealed class GoldenEraNativeZipServer : IDisposable {
    readonly TcpListener listener;
    readonly Thread worker;
    readonly byte[] payload;
    volatile bool running = true;
    int requests;
    public int Port { get; private set; }
    public int Requests { get { return Interlocked.CompareExchange(ref requests, 0, 0); } }
    public string Failure { get; private set; }
    public GoldenEraNativeZipServer(byte[] archive) {
        payload = archive;
        listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        Port = ((IPEndPoint)listener.LocalEndpoint).Port;
        worker = new Thread(Serve);
        worker.IsBackground = true;
        worker.Start();
    }
    void Serve() {
        while (running) {
            try {
                using (TcpClient client = listener.AcceptTcpClient()) {
                    client.ReceiveTimeout = 5000;
                    client.SendTimeout = 5000;
                    using (NetworkStream stream = client.GetStream()) {
                        var reader = new StreamReader(stream, Encoding.ASCII, false, 1024, true);
                        string request = reader.ReadLine();
                        string header;
                        while (!String.IsNullOrEmpty(header = reader.ReadLine())) { }
                        Interlocked.Increment(ref requests);
                        bool found = request != null && request.StartsWith("GET /engine.zip ", StringComparison.Ordinal);
                        byte[] body = found ? payload : Encoding.ASCII.GetBytes("Unknown fixture");
                        string status = found ? "200 OK" : "404 Not Found";
                        byte[] response = Encoding.ASCII.GetBytes("HTTP/1.1 " + status + "\r\nContent-Type: application/zip\r\nContent-Length: " + body.Length + "\r\nConnection: close\r\n\r\n");
                        stream.Write(response, 0, response.Length);
                        stream.Write(body, 0, body.Length);
                        stream.Flush();
                        reader.Dispose();
                    }
                }
            } catch (SocketException error) {
                if (running) Failure = error.Message;
                break;
            } catch (Exception error) {
                if (running) Failure = error.Message;
            }
        }
    }
    public void Dispose() {
        running = false;
        listener.Stop();
        worker.Join(6500);
    }
}
'@
    Add-Type -TypeDefinition $serverCode
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipSource = Join-Path $testWork 'zip-source'
    $zipBin = Join-Path $zipSource 'luanti-fixture\bin'
    [IO.Directory]::CreateDirectory($zipBin) | Out-Null
    Copy-Item -LiteralPath $stubExe -Destination (Join-Path $zipBin 'luanti.exe')
    $zipFile = Join-Path $testWork 'engine-fixture.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($zipSource, $zipFile)
    $fixtureHash = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $fixtureServer = New-Object GoldenEraNativeZipServer -ArgumentList (,[IO.File]::ReadAllBytes($zipFile))
    $engineVersion = (([IO.File]::ReadAllText((Join-Path $templateRoot 'engine-downloads.json')) | ConvertFrom-Json).windows_x86_64.version)
    $engineFolder = 'engine-' + $engineVersion

    function New-NativeCase([string]$Name, [string]$Metadata, [switch]$Populated, [switch]$WrongHash) {
        $caseRoot = Join-Path $testWork $Name
        $bundle = Join-Path $caseRoot "game with spaces [qa] ' ! &"
        $defaults = Join-Path $bundle 'defaults'
        [IO.Directory]::CreateDirectory($defaults) | Out-Null
        Copy-Item -LiteralPath $batchSource -Destination (Join-Path $bundle 'start.bat')
        Copy-Item -LiteralPath (Join-Path $templateRoot 'defaults\playtest.conf') -Destination (Join-Path $defaults 'playtest.conf')
        $download = @{ windows_x86_64 = @{ version = $engineVersion; url = ('http://127.0.0.1:' + $fixtureServer.Port + '/engine.zip');
                      sha256 = $fixtureHash; archive_root = 'luanti-fixture' } }
        if ($WrongHash) { $download.windows_x86_64.sha256 = ('0' * 64) }
        [IO.File]::WriteAllText((Join-Path $bundle 'engine-downloads.json'), ($download | ConvertTo-Json -Depth 4), $utf8)
        $data = Join-Path $caseRoot "tester saves [qa] ' ! &"
        if ($Populated) {
            $world = Join-Path $data 'worlds\playtest'
            [IO.Directory]::CreateDirectory($world) | Out-Null
            [IO.Directory]::CreateDirectory((Join-Path $data 'logs')) | Out-Null
            [IO.File]::WriteAllText((Join-Path $world 'world.mt'), $Metadata, $utf8)
            [IO.File]::WriteAllText((Join-Path $world 'map.sqlite'), 'saved database fixture; never opened by a real game', $utf8)
            [IO.File]::WriteAllText((Join-Path $data 'settings.conf'), "# developer preference`r`nviewing_range = 44`r`n", $utf8)
        }
        return @{ Root = $caseRoot; Bundle = $bundle; Data = $data; Capture = (Join-Path $caseRoot 'launch-argv.txt') }
    }

    function Invoke-NativeLauncher($Case) {
        if (Test-Path -LiteralPath $Case.Capture) { Remove-Item -LiteralPath $Case.Capture }
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $env:ComSpec
        $startInfo.Arguments = '/d /s /c ""' + (Join-Path $Case.Bundle 'start.bat') + '" <nul"'
        $startInfo.WorkingDirectory = $Case.Root
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.EnvironmentVariables['GOLDEN_ERA_DATA_DIR'] = $Case.Data
        $startInfo.EnvironmentVariables['GE_NATIVE_CAPTURE'] = $Case.Capture
        $startInfo.EnvironmentVariables['LUANTI_GAME_PATH'] = 'C:\nonexistent-developer-game'
        $testProcess = New-Object Diagnostics.Process
        $testProcess.StartInfo = $startInfo
        [void]$testProcess.Start()
        $stdout = $testProcess.StandardOutput.ReadToEndAsync()
        $stderr = $testProcess.StandardError.ReadToEndAsync()
        if (-not $testProcess.WaitForExit(45000)) {
            & taskkill.exe /PID $testProcess.Id /T /F | Out-Null
            throw 'Launcher fixture exceeded 45 seconds; its process tree was stopped.'
        }
        $output = $stdout.Result + $stderr.Result
        [IO.File]::WriteAllText((Join-Path $Case.Root 'cmd-output.txt'), $output, $utf8)
        return @{ ExitCode = $testProcess.ExitCode; Output = $output }
    }

    function Assert-NativeCapture($Case) {
        Assert-NativeTest (Test-Path -LiteralPath $Case.Capture) 'Fixture engine was not launched.'
        $actualArguments = New-Object 'Collections.Generic.List[string]'
        $capturedGame = $null
        $capturedUser = $null
        foreach ($line in [IO.File]::ReadAllLines($Case.Capture)) {
            $split = $line.IndexOf(' ')
            $kind = $line.Substring(0, $split)
            $value = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($line.Substring($split + 1)))
            if ($kind -eq 'ARG') { $actualArguments.Add($value) }
            elseif ($kind -eq 'GAME') { $capturedGame = $value }
            elseif ($kind -eq 'USER') { $capturedUser = $value }
        }
        $expected = @('--go', '--gameid', 'golden_era_playtest', '--world', (Join-Path $Case.Data 'worlds\playtest'),
                      '--config', (Join-Path $Case.Data 'settings.conf'), '--logfile', (Join-Path $Case.Data 'logs\client.log'), '--name', 'Tester')
        Assert-NativeTest (($actualArguments.ToArray() | ConvertTo-Json -Compress) -ceq ($expected | ConvertTo-Json -Compress)) 'Native cmd.exe changed launcher argument quoting or order.'
        Assert-NativeTest ($capturedGame -ieq (Join-Path $Case.Bundle 'games')) 'Launcher did not override the developer game path.'
        Assert-NativeTest ($capturedUser -ieq (Join-Path $Case.Data 'engine-user')) 'Launcher did not isolate the engine user path.'
    }

    $fresh = New-NativeCase 'fresh bootstrap'
    $result = Invoke-NativeLauncher $fresh
    Assert-NativeTest ($result.ExitCode -eq 0) ('Fresh launcher failed: ' + $result.Output)
    Assert-NativeCapture $fresh
    $worldFile = Join-Path $fresh.Data 'worlds\playtest\world.mt'
    $worldSettings = @{}
    foreach ($line in [IO.File]::ReadAllLines($worldFile)) {
        if ($line -cmatch '^\s*([^=]+?)\s*=\s*(.*?)\s*$') { $worldSettings[$matches[1]] = $matches[2] }
    }
    Assert-NativeTest ($worldSettings.Count -eq 5) 'Expected five world metadata entries.'
    Assert-NativeTest ($worldSettings['gameid'] -ceq 'golden_era_playtest') 'Fresh world has the wrong game ID.'
    foreach ($key in @('backend', 'player_backend', 'auth_backend', 'mod_storage_backend')) {
        Assert-NativeTest ($worldSettings[$key] -ceq 'sqlite3') ('Fresh world has the wrong backend: ' + $key)
    }
    Assert-NativeTest ((Get-FileHash -LiteralPath (Join-Path $fresh.Data 'settings.conf')).Hash -eq
                      (Get-FileHash -LiteralPath (Join-Path $fresh.Bundle 'defaults\playtest.conf')).Hash) 'Fresh launch changed the packaged default settings.'
    Assert-NativeTest (@(Get-ChildItem -LiteralPath $fresh.Data -Directory | Where-Object Name -Like 'download-*').Count -eq 0) 'Fresh launch left download staging behind.'
    $report.Add('PASS: native cmd.exe first launch downloads the loopback ZIP, promotes cache and passes exact quoted argv/env to the fixture executable')
    $report.Add('PASS: fresh metadata contains gameid plus four sqlite3 backend entries; default settings copied')

    [IO.File]::WriteAllText((Join-Path $fresh.Data 'settings.conf'), "# tester preferences`r`nviewing_range = 44`r`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $fresh.Data 'worlds\playtest\map.sqlite'), 'preserved world database fixture', $utf8)
    $before = Get-TestSnapshot $fresh.Data
    $requestsBefore = $fixtureServer.Requests
    $result = Invoke-NativeLauncher $fresh
    Assert-NativeTest ($result.ExitCode -eq 0) ('Relaunch failed: ' + $result.Output)
    Assert-NativeCapture $fresh
    Assert-NativeTest ((Get-TestSnapshot $fresh.Data) -ceq $before) 'Cached relaunch changed existing save/config/cache files.'
    Assert-NativeTest ($fixtureServer.Requests -eq $requestsBefore) 'Cached relaunch downloaded an engine again.'
    $report.Add('PASS: cached relaunch preserves saved preferences, world metadata and map bytes without another download')

    $validMetadata = "gameid = golden_era_playtest`r`nbackend = sqlite3`r`n"
    $partial = New-NativeCase 'partial cache' -Populated -Metadata $validMetadata
    $partialEngine = Join-Path $partial.Data $engineFolder
    [IO.Directory]::CreateDirectory((Join-Path $partialEngine 'bin')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $partialEngine 'keep-me.txt'), 'preserve incomplete cache contents', $utf8)
    $settingsBefore = (Get-FileHash -LiteralPath (Join-Path $partial.Data 'settings.conf')).Hash
    $mapBefore = (Get-FileHash -LiteralPath (Join-Path $partial.Data 'worlds\playtest\map.sqlite')).Hash
    $metadataBefore = (Get-FileHash -LiteralPath (Join-Path $partial.Data 'worlds\playtest\world.mt')).Hash
    $result = Invoke-NativeLauncher $partial
    Assert-NativeTest ($result.ExitCode -eq 0) ('Partial cache repair failed: ' + $result.Output)
    Assert-NativeCapture $partial
    $backups = @(Get-ChildItem -LiteralPath $partial.Data -Directory | Where-Object Name -Like ($engineFolder + '-incomplete-*'))
    Assert-NativeTest ($backups.Count -eq 1) 'Incomplete cache was not preserved in one backup.'
    Assert-NativeTest ([IO.File]::ReadAllText((Join-Path $backups[0].FullName 'keep-me.txt')) -ceq 'preserve incomplete cache contents') 'Incomplete cache backup lost its contents.'
    Assert-NativeTest (-not (Test-Path -LiteralPath (Join-Path $partialEngine 'luanti-fixture'))) 'Engine promotion nested its archive directory.'
    Assert-NativeTest ((Get-FileHash -LiteralPath (Join-Path $partial.Data 'settings.conf')).Hash -eq $settingsBefore) 'Partial cache repair changed settings.'
    Assert-NativeTest ((Get-FileHash -LiteralPath (Join-Path $partial.Data 'worlds\playtest\map.sqlite')).Hash -eq $mapBefore) 'Partial cache repair changed saved map data.'
    Assert-NativeTest ((Get-FileHash -LiteralPath (Join-Path $partial.Data 'worlds\playtest\world.mt')).Hash -eq $metadataBefore) 'Partial cache repair changed world metadata.'
    Assert-NativeTest (@(Get-ChildItem -LiteralPath $partial.Data -Directory | Where-Object Name -Like 'download-*').Count -eq 0) 'Partial cache repair left download staging behind.'
    $report.Add('PASS: incomplete engine cache is preserved and replaced without nesting or save/config changes')

    $badHash = New-NativeCase 'wrong checksum' -Populated -Metadata $validMetadata -WrongHash
    [IO.Directory]::CreateDirectory((Join-Path $badHash.Data $engineFolder)) | Out-Null
    [IO.File]::WriteAllText((Join-Path (Join-Path $badHash.Data $engineFolder) 'keep-me.txt'), 'old incomplete cache', $utf8)
    $before = Get-TestSnapshot $badHash.Data
    $result = Invoke-NativeLauncher $badHash
    Assert-NativeTest ($result.ExitCode -ne 0 -and $result.Output -match 'checksum mismatch') 'Bad checksum did not fail safely.'
    Assert-NativeTest (-not (Test-Path -LiteralPath $badHash.Capture)) 'Bad checksum launched an engine.'
    Assert-NativeTest ((Get-TestSnapshot $badHash.Data) -ceq $before) 'Bad checksum changed existing save/config/cache files or left staging.'
    $report.Add('PASS: checksum failure refuses launch and leaves original files/cache unchanged')

    $foreign = New-NativeCase 'foreign world' -Populated -Metadata "gameid = another_game`r`n"
    Remove-Item -LiteralPath (Join-Path $foreign.Data 'logs')
    $before = Get-TestSnapshot $foreign.Data
    $requestsBefore = $fixtureServer.Requests
    $result = Invoke-NativeLauncher $foreign
    Assert-NativeTest ($result.ExitCode -ne 0) 'Foreign world was accepted.'
    Assert-NativeTest (-not (Test-Path -LiteralPath $foreign.Capture)) 'Foreign world reached the fixture engine.'
    Assert-NativeTest ((Get-TestSnapshot $foreign.Data) -ceq $before) 'Foreign-world refusal wrote files or directories.'
    Assert-NativeTest ($fixtureServer.Requests -eq $requestsBefore) 'Foreign-world refusal downloaded an engine.'
    $orphan = New-NativeCase 'orphaned world' -Populated -Metadata $validMetadata
    Remove-Item -LiteralPath (Join-Path $orphan.Data 'worlds\playtest\world.mt')
    Remove-Item -LiteralPath (Join-Path $orphan.Data 'logs')
    $before = Get-TestSnapshot $orphan.Data
    $result = Invoke-NativeLauncher $orphan
    Assert-NativeTest ($result.ExitCode -ne 0 -and $result.Output -match 'no world.mt') 'Orphaned database was accepted.'
    Assert-NativeTest ((Get-TestSnapshot $orphan.Data) -ceq $before) 'Orphaned-world refusal wrote files or directories.'
    Assert-NativeTest (-not (Test-Path -LiteralPath $orphan.Capture)) 'Orphaned database reached the fixture engine.'
    Assert-NativeTest ([string]::IsNullOrEmpty($fixtureServer.Failure)) ('Loopback fixture server failed: ' + $fixtureServer.Failure)
    $report.Add('PASS: foreign and orphaned worlds are refused before file creation, downloads or native engine launch')
    $testPassed = $true
    $report.Add('NATIVE WINDOWS LAUNCHER REGRESSION PASS')
} catch {
    $report.Add('FAIL: ' + $_.Exception.Message)
    throw
} finally {
    if ($null -ne $fixtureServer) { $fixtureServer.Dispose() }
    [Environment]::SetEnvironmentVariable('TEMP', $previousTemp, 'Process')
    [Environment]::SetEnvironmentVariable('TMP', $previousTmp, 'Process')
    if ($testPassed -and -not $KeepWork) {
        try { Remove-Item -LiteralPath $testWork -Recurse -Force }
        catch { $report.Add('Fixture cleanup could not remove all files: ' + $testWork + '; ' + $_.Exception.Message) }
    } else { $report.Add('Fixture files retained: ' + $testWork) }
    $evidence = Join-Path $testBase 'windows-native-regression.txt'
    [IO.File]::WriteAllLines($evidence, $report.ToArray(), $utf8)
    $report | ForEach-Object { Write-Output $_ }
    Write-Output ('Evidence: ' + $evidence)
}
