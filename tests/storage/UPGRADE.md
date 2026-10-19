# Bounded 0.1.2 → 0.1.3 storage save check

```sh
python3 tests/storage/test_upgrade.py
python3 tests/storage/upgrade.py
```

This historical regression requires the exact local 0.1.2 and 0.1.3 game ZIPs and
their external manifests/checksum files in `dist`. Each input must also match its
frozen `docs/releases/<version>.json` game ZIP record in repository path, byte size
and SHA256. It verifies every archived payload, extracts each unchanged game into
ignored `runtime/tests`, and runs the
repository-local native Luanti 5.17 server on port **30218**. No assembly helper,
release build or source restoration is involved.

The existing storage fixture first reaches its baseline CHECKPOINT under the
actual 0.1.2 game. Its one expected missing-`default` warning is required; all
other warnings/errors fail. After that process closes, every existing world
SQLite database passes a read-only integrity check. The next process uses the
exact 0.1.3 game against that **same world directory and SQLite databases**.

A copied test observer asserts the following before any resumed deposit:

- Four iron ingots and eleven copper ingots retain their identities and counts.
- The native four-compartment drawer still contains its one redstone item.
- The old controller left placed by the caught baseline blast failure still owns
  one iron pick with wear 3210 and its full metadata string.

The repaired fixture rejects the stale disconnected cache, reconnects native
trim, and adds three offered iron. COMPLETE requires exactly seven iron, eleven
copper and unchanged redstone/tool payloads, clean engine diagnostics and valid
closed SQLite files. Both ZIPs and all six ZIP/manifest/checksum files must keep
their original hashes. Output is `runtime/tests/storage-upgrade-0.1.2-to-0.1.3.log`.

This proves continuity for the specific saved storage/node/mod state in the
fixture. It does not restore baseline overflow already lost under 0.1.2, rewrite
player data or establish whole-world, GUI, native Windows, performance or every
machine migration coverage. The observer adds assertions to a copied worldmod;
all Lua and source files extracted from the release games remain untouched.
