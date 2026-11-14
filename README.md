<p align="center">
<img src="https://i.imgur.com/UtCWeqB.png" height="110px" width="auto" alt="AutoHotkey Explorer v2" />
</p>
<h3 align="center">AutoHotkey Explorer v2</h3>
<p align="center">Reliable Explorer folder and selection access library for AutoHotkey v2</p>
<h2></h2>
<br />

<p align="center">
<a href="../../releases"><img src="https://img.shields.io/github/release/mobeigi/AutoHotkey-Explorer-v2.svg?style=flat-square" alt="Release" /></a>
<a href="../../actions/workflows/tests.yml"><img src="https://img.shields.io/github/actions/workflow/status/mobeigi/AutoHotkey-Explorer-v2/tests.yml?branch=main&amp;style=flat-square" alt="Tests" /></a>
<a href="../../issues"><img src="https://img.shields.io/github/issues/mobeigi/AutoHotkey-Explorer-v2.svg?style=flat-square" alt="Issues" /></a>
<a href="../../pulls"><img src="https://img.shields.io/github/issues-pr/mobeigi/AutoHotkey-Explorer-v2.svg?style=flat-square" alt="Pull requests" /></a>
<a href="LICENSE"><img src="https://img.shields.io/github/license/mobeigi/AutoHotkey-Explorer-v2.svg?style=flat-square" alt="Licence" /></a>
</p>

## Description

Get the current folder and selected files from Windows Explorer or the desktop.
Supports Windows 11 tabs and falls back to UI Automation when shell lookup fails.

A single file with no dependencies. It doesn't navigate, send keystrokes, or touch
the clipboard.

## Requirements

- Windows
- [AutoHotkey v2.0](https://www.autohotkey.com/)

## Instructions

### Installation

Download [Explorer_v2.ahk](Explorer_v2.ahk), place it next to your script, and include it:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Explorer_v2.ahk
```

Or place it in an AutoHotkey `Lib` folder and use `#Include <Explorer_v2>`.

### Quick start

Run this script, focus an Explorer window, and press **Ctrl+Alt+E**:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Explorer_v2.ahk

^!e:: {
    context := Explorer.GetContext() ; Capture before showing any UI.
    if context.FolderStatus = "ok"
        MsgBox context.FolderPath, "Explorer folder"
    else
        MsgBox "Folder unavailable: " context.FolderStatus, "Explorer folder"
}
```

[Demo.ahk](examples/Demo.ahk) also displays selected paths and statuses. It uses the
same hotkey, so run only one example at a time.

## API

```ahk
context := Explorer.GetContext()          ; Foreground folder and selection.
context := Explorer.GetContext(hwnd)      ; Specific Explorer window.
context := Explorer.GetContext(0, false)  ; Foreground folder only.
```

Omit `hwnd` or pass `0` for the foreground window. Set `readSelection` to `false`
to skip selection lookup. `Explorer.Version` returns the library version.

### Result fields

| Field | Meaning |
|---|---|
| `WindowHwnd` | Captured window handle. |
| `FolderPath` | Folder path when `FolderStatus = "ok"`. |
| `SelectedPaths` | Array of full paths when `SelectionStatus = "ok"`; order may vary. |
| `FolderStatus`, `SelectionStatus` | Status of each lookup. |
| `FolderSource`, `SelectionSource` | `"shell"`, `"uia"`, or empty. |
| `Diagnostics` | Array of diagnostic messages; use statuses, not message text, in your logic. |

Check folder and selection statuses separately; either can succeed on its own.
**An empty selection means “nothing selected” only when `SelectionStatus = "ok"`.**

### Statuses

| Status | Meaning |
|---|---|
| `ok` | Lookup succeeded. |
| `unavailable` | Required view information couldn't be read. |
| `unsupported-window` | Not a supported Explorer window or desktop. |
| `not-filesystem` | The location or selected item isn't a filesystem object. |
| `unresolved` | A path is missing, inaccessible, or ambiguous. |
| `stale-context` | The view changed or couldn't be verified during lookup. |
| `not-requested` | Selection lookup was skipped. |

Diagnostics can contain an earlier error even if recovery succeeds. Unexpected
programming errors may throw exceptions.

## Testing

From PowerShell in the repository root:

```powershell
# Syntax and core tests.
.\tests\Run-Tests.ps1

# Explorer integration tests (opens test windows).
.\tests\Run-Tests.ps1 -Integration

# Desktop selection tests.
.\tests\Run-Tests.ps1 -Desktop

# Explicit interpreter path.
.\tests\Run-Tests.ps1 -AutoHotkeyPath 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
```

The runner checks both installed AHK bitnesses. GitHub Actions runs syntax and core
tests; GUI tests run locally on an unlocked desktop. Don't run GUI suites concurrently.

Desktop tests need visible icons and at least two unambiguous filesystem icons.
They don't change the real Desktop selection. See [the testing guide](tests/TESTING.md)
for setup and compatibility checks.

## Troubleshooting

- **Wrong window:** call `GetContext()` before showing a message box or other UI.
- **Lookup failed:** check the relevant status and `Diagnostics`.
- **Updated library not taking effect:** reload scripts that include it.
- **AHK not found by the test runner:** pass `-AutoHotkeyPath`.

## Limitations

- File dialogs and third-party file managers aren't supported.
- Virtual locations such as Home, Libraries, search results, and ZIP contents have
  limited support. Selected real files may still be returned without a folder path.
- Explorer updates may affect compatibility.
- Lookups are synchronous, have no hard timeout, and aren't atomic during navigation
  or selection changes. Ambiguous or incomplete selections are rejected.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for notable changes.

## Contributions

Contributions are always welcome!
Just make a [pull request](../../pulls).

## Acknowledgments

Inspired by Joshua A. Kinnison's original Explorer helper.

## Licence

[GNU General Public License v3.0](LICENSE).
