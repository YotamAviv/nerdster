# Flutter Test Environment — SDKs & the native-assets cache trap

## Symptom

`bin/run_all_tests.sh` (or a bare `flutter test`) fails during the **Flutter** sections —
before any test runs — with:

```
build.dart returned with exit code: 253.
Can't load Kernel binary: Invalid kernel binary format version (expected 130, found 127).
```

The failure is inside a transitive dependency's native-assets build hook (e.g.
`objective_c`), not in our code. Backend (node) tests are unaffected and still pass. This is
**not a code regression** — it's a stale build cache after a Flutter/Dart SDK change.

## Root cause: more than one Flutter on this machine

There are (at least) two Flutter installs, and bare `flutter` resolves by PATH:

| Install | Version | Dart | Kernel format |
|---|---|---|---|
| `/snap/bin/flutter` (snap) | 3.41.4 | 3.11.1 | 127 |
| `~/bin/flutter/bin/flutter` (git) | 3.44.6 | 3.12.2 | 130 |

`run_all_tests.sh` calls bare `flutter` (e.g. lines 34, 43), so which SDK it uses depends on
the shell's PATH. An interactive login shell here picks `~/bin/flutter` (3.44.6); other
contexts (a snap-first PATH, some tool shells) pick the 3.41.4 snap.

When the two SDKs are mixed against the **same** checkout, whichever ran last leaves
`.dart_tool/hooks_runner/**` native-assets artifacts compiled for *its* Dart. The next run
under the other SDK tries to load them and rejects the kernel format — hence
"expected 130, found 127".

Note: as of the `chore: Flutter 3.44.6 compatibility` bump (commit `3291d08`), there is no
commit or doc establishing that the Flutter suites had passed under 3.44.6 with a fresh
cache. They do — verified 2026-07-15 after clearing the cache (see below) — but a stale cache
had been masking that.

## Fix

Clear the stale native-assets cache, then run with the **intended** SDK explicitly:

```bash
rm -rf .dart_tool/hooks_runner
~/bin/flutter/bin/flutter test
```

If that isn't enough (e.g. deeper `.dart_tool` drift), the fuller reset:

```bash
~/bin/flutter/bin/flutter clean
~/bin/flutter/bin/flutter pub get
~/bin/flutter/bin/flutter test
```

Deleting `hooks_runner` / `.dart_tool` is safe — it's all regenerable build cache, no source.

## Prevention

- **Pick one SDK and invoke it explicitly.** This project targets `~/bin/flutter` (3.44.6).
  Prefer `~/bin/flutter/bin/flutter ...` over bare `flutter` when the PATH is uncertain, and
  don't run `analyze`/`test`/`pub get` against this checkout with the 3.41.4 snap in between —
  that's what plants the incompatible cache.
- Consider removing or de-prioritising the snap Flutter on PATH so bare `flutter` can't
  silently resolve to the wrong version. (Snap Flutter has caused other grief here — see
  `reference_snap_curl_blocks_bin` in auto-memory.)
- If `run_all_tests.sh` should hard-pin the SDK, point its `flutter` calls at an absolute
  path or a `FLUTTER=${FLUTTER:-$HOME/bin/flutter/bin/flutter}` variable.

## Related

- `doc/flutter_upgrade_3.32_to_3.41.md` — the previous upgrade (no 3.44.6 doc otherwise).
- `CLAUDE.md` — `bin/run_all_tests.sh` is the canonical "run all tests" entry point.
