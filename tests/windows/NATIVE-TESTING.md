Run the native launcher regression from the repository root in Windows:

```powershell
powershell.exe -NoProfile -File .\tests\windows\native.ps1
```

This uses Windows PowerShell 5.1 and the real `cmd.exe`. It copies the current
launcher and defaults into a disposable folder under `runtime/tests`, builds a
small harmless C# console executable using the installed .NET compiler, and
serves its ZIP through a temporary loopback TCP listener. It does not launch
Luanti, install tools, change execution policy, contact external servers, or
modify shell profiles. Compiler temporary files stay inside the fixture folder.

An explicit interactive invocation of the same checked-out source is:

```powershell
powershell.exe -NoProfile -Command "& ([ScriptBlock]::Create([IO.File]::ReadAllText('tests\windows\native.ps1'))) -RepoRoot (Get-Location).Path"
```

The test checks native command-line quoting with spaces, brackets, apostrophes,
`!` and `&`; initial cache installation; exact game/user paths; five fresh world
metadata entries (the game ID and four SQLite backend settings); saved settings
and map preservation; cached relaunch; incomplete-cache quarantine; checksum
failure; and refusal of foreign or orphaned worlds before any file creation.
The launcher receives closed stdin so error-path `pause` cannot block. Each
launcher invocation is bounded to 45 seconds; a timeout stops its fixture
process tree. The listener binds only to `127.0.0.1` on an automatically selected
port and is stopped at the end.

Successful temporary fixtures are removed. Use `-KeepWork` to retain them;
failure fixtures are retained for diagnosis. Results are written to
`runtime/tests/windows-native-regression.txt`.

Native Windows execution is pending. Linux parser/C# helper validation is
separate evidence and does not establish a Windows PowerShell 5.1 test pass.
Reproduce that developer helper check with `python3 tests/windows/validate_native.py`
(or add `--fetch-tool` to restore the hash-pinned portable PowerShell tool).
