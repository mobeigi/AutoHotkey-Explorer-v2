# Testing

## Requirements

- Windows and AutoHotkey v2.0.
- An unlocked desktop for GUI tests.
- Visible Desktop icons and at least two unambiguous filesystem icons for Desktop tests.

## Running tests

Open PowerShell in the repository root:

```powershell
# Syntax and core tests.
.\tests\Run-Tests.ps1

# Explorer integration tests.
.\tests\Run-Tests.ps1 -Integration

# Desktop selection tests.
.\tests\Run-Tests.ps1 -Desktop

# All tests, run sequentially.
.\tests\Run-Tests.ps1 -Integration -Desktop

# Explicit interpreter path.
.\tests\Run-Tests.ps1 -AutoHotkeyPath 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
```

The runner finds 32-bit and 64-bit interpreters under `Program Files\AutoHotkey\v2`
and runs each one available. Validation warnings, errors, and failed assertions
fail the run. The demo is validated but never launched.

## Test suites

| Suite | Coverage |
|---|---|
| Core | Result isolation, statuses, invalid window handles, paths, name resolution, and error handling. |
| Explorer integration | Shell/UIA parity, Unicode, offscreen selections, empty/single/multiple selections, hidden/system items, and tab switching where available. |
| Desktop | Live Desktop access and isolated native-list selection mapping, including filesystem identities and virtual-icon rejection. |

Desktop tests use existing icon names without creating Desktop files or changing
the real Desktop selection. File, folder, Public Desktop, and virtual-icon cases
are skipped when suitable items aren't available. A skip isn't a pass.

GitHub Actions runs syntax and core checks for both interpreter bitnesses on pull
requests and pushes to `main`. GUI tests run locally.

## GUI test safety

- Don't run GUI suites concurrently or interact with their windows during a run.
- Tests may take focus and open temporary windows, tabs, and files.
- Cleanup closes only verified test-owned windows. If ownership is uncertain,
  fixtures are retained with a warning for manual inspection.
- Recovery tests force the backend safely; never crash, restart, or kill Explorer
  to reproduce missing shell registration.
- Run as a normal user. Use a disposable environment when changing Explorer preferences.

## Manual checks

Use [Demo.ahk](../examples/Demo.ahk) to inspect results: run it, focus Explorer or
the desktop, and press **Ctrl+Alt+E**. Exit through its AutoHotkey tray icon.

- Check empty, single, and large offscreen selections; compare actual path identities,
  not just counts. An empty selection is valid only with `SelectionStatus = "ok"`.
- Try Unicode names, spaces, hidden/system items, hidden extensions, duplicate
  displayed names, and shortcuts. Ambiguous names must not produce guessed paths.
- Check different view modes, same-named folders in separate windows, and tab
  switching in both directions.
- Check an untouched address bar, an uncommitted edit, and navigation during lookup.
- Try user and Public Desktop items together, including virtual icons.
- Test available UNC shares, disconnected shares, long paths, junctions, symlinks,
  deleted items, and inaccessible folders.
- In search, Libraries, ZIP contents, Home, and This PC, check folder and selection
  independently; selected real files may work without a filesystem folder.
- Check different Windows/Explorer versions, locales, and elevation levels.
- Confirm lookup doesn't navigate, scroll, change selection, or alter the clipboard.
  A non-Explorer application should report `unsupported-window`, not stale paths.

When reporting results, include Windows build, AHK version/bitness, relevant setup,
expected and actual paths, and statuses. Mark cases as passed, failed, or not tested.
