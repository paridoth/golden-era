#!/usr/bin/env python3
"""Parse the native Windows test and exercise its C# helpers without running cmd.exe."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("windows_fixture_tools", ROOT / "tests/windows/run.py")
tooling = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tooling)

COMMAND = r'''
$tokens=$null; $errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($env:GE_SCRIPT,[ref]$tokens,[ref]$errors)
if ($errors.Count) { $errors | Format-List | Out-String | Write-Output; exit 1 }
'PowerShell parser: PASS'
$utf8=New-Object Text.UTF8Encoding($false)
$list=New-Object 'Collections.Generic.List[string]'
$helpers=Get-Content -LiteralPath $env:GE_HELPERS -Raw | ConvertFrom-Json
Add-Type -TypeDefinition $helpers.stubCode
Add-Type -TypeDefinition $helpers.serverCode
'Both distinct C# helpers compile: PASS'
$server=New-Object GoldenEraNativeZipServer -ArgumentList (,[byte[]](10,20,30))
try {
    $client=New-Object Net.WebClient
    $bytes=$client.DownloadData(('http://127.0.0.1:'+$server.Port+'/engine.zip'))
    if (($bytes -join ',') -ne '10,20,30' -or $server.Requests -ne 1) { throw 'Loopback payload mismatch' }
    $client.Dispose()
    'Loopback TCP fixture download: PASS'
} finally { $server.Dispose() }
[void][GoldenEraNativeFixture]::Main([string[]]@('--world',"path with spaces [qa] ' ! &"))
$lines=[IO.File]::ReadAllLines($env:GE_NATIVE_CAPTURE)
if ($lines.Count -ne 4) { throw 'Capture line count mismatch' }
$decoded=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($lines[3].Substring(4)))
if ($decoded -cne "path with spaces [qa] ' ! &") { throw 'Fixture argument encoding mismatch' }
'CLR fixture capture encoding: PASS'
'NATIVE WINDOWS EXECUTION: NOT RUN BY THIS CHECK'
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch-tool", action="store_true", help="Explicitly restore the hash-pinned PowerShell developer tool")
    args = parser.parse_args()
    tool, lock = tooling.powershell(args.fetch_tool)
    script = ROOT / "tests/windows/native.ps1"
    source = script.read_text()
    helpers = dict(re.findall(r"\$(stubCode|serverCode) = @'\n(.*?)\n'@", source, re.S))
    assert "class GoldenEraNativeFixture" in helpers["stubCode"]
    assert "class GoldenEraNativeZipServer" in helpers["serverCode"]
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="windows-native-helper-", dir=base) as temporary:
        work = Path(temporary)
        (work / "temp").mkdir()
        (work / "helpers.json").write_text(json.dumps(helpers))
        env = os.environ.copy()
        env.update(XDG_DATA_HOME=str(work / "data"), XDG_CACHE_HOME=str(work / "cache"),
                   XDG_CONFIG_HOME=str(work / "config"), DOTNET_CLI_HOME=str(work / "dotnet"),
                   POWERSHELL_TELEMETRY_OPTOUT="1", DOTNET_CLI_TELEMETRY_OPTOUT="1", TMPDIR=str(work / "temp"),
                   GE_SCRIPT=str(script), GE_HELPERS=str(work / "helpers.json"), GE_NATIVE_CAPTURE=str(work / "capture.txt"),
                   LUANTI_GAME_PATH="fixture game path ! &", LUANTI_USER_PATH="fixture user path [qa]")
        result = subprocess.run([str(tool), "-NoProfile", "-NonInteractive", "-Command", COMMAND], env=env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    report = ("Native Windows regression helper-only validation; PowerShell " + lock["version"] + ".\n"
              "Script SHA256: " + hashlib.sha256(script.read_bytes()).hexdigest() + "\n" + result.stdout +
              "Exit: " + str(result.returncode) + "\n")
    (base / "windows-native-helper-validation.txt").write_text(report)
    print(report)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
