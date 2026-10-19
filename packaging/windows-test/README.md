Windows bootstrap regression uses the exact inline `powershell.exe -Command`
script extracted from `packaging/playtest/templates/start.bat`. It does not
rewrite its paths or replace PowerShell commands with Python approximations.

    python3 tests/windows/run.py --fetch-tool
    python3 tests/windows/run.py

`--fetch-tool` explicitly restores the official PowerShell Linux archive pinned
by release URL, SHA256 and size in `powershell.lock.json`. The compiler/runtime
is extracted under ignored repository tools; nothing is installed system-wide
or redistributed in the game. PowerShell's XDG/.NET cache paths stay inside the
repository, and developer-tool telemetry is disabled for these test runs.

A loopback HTTP server provides harmless ZIP fixtures with correct or incorrect
hashes and expected or missing executable entries. The fake `luanti.exe` is text
and is never executed. Tests cover direct fresh promotion, incomplete-cache
quarantine, checksum failure, missing executable, concurrent fresh promotion,
cleanup, special characters in paths, and preservation of tester save/settings
bytes. The current inline script's SHA256 is recorded in the evidence.

This verifies real PowerShell 7/.NET filesystem and archive operations on Linux.
It does not execute `cmd.exe`, Windows PowerShell 5.1, the NSIS installer or the
actual Windows Luanti executable. Windows shell quoting, file locking, desktop
integration and native game startup still need Windows testing. The tool's
original license/source references remain in its ignored official archive.
