#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include %A_ScriptDir%\..\Explorer_v2.ahk
#Include %A_ScriptDir%\TestSupport.ahk

Main()

Main() {
    try {
        TestCore()
        if A_Args.Length && A_Args[1] = "--integration"
            TestIntegration()
        else if A_Args.Length
            throw ValueError("Usage: Explorer.Tests.ahk [--integration]")
        else
            TestLog("SKIP: Explorer GUI tests (pass --integration to opt in)")
        TestLog("PASS: Explorer tests; AHK " A_AhkVersion ", " (A_PtrSize * 8) "-bit")
    } catch as err {
        TestLog("FAIL: " err.Message "`n" err.Stack)
        ExitApp 1
    }
}

TestCore() {
    TestAssert(Explorer.Version = "1.0.0", "Expected first-release version")
    first := Explorer.Context(123, true)
    second := Explorer.Context(456, false)
    first.SelectedPaths.Push("not-a-real-path")
    first.Diagnostics.Push("test")
    TestAssert(second.SelectedPaths.Length = 0 && second.Diagnostics.Length = 0, "Result arrays must not be shared")
    TestAssert(second.SelectionStatus = "not-requested", "Folder-only result skips selection")
    Explorer._Invalidate(first, "test invalidation")
    TestAssert(first.FolderStatus = "stale-context" && first.SelectedPaths.Length = 0, "Invalidation clears paths")
    Explorer._Invalidate(second, "test invalidation")
    TestAssert(second.SelectionStatus = "not-requested", "Invalidation preserves not-requested")
    unsupported := Explorer._Unsupported(Explorer.Context(0, true))
    TestAssert(unsupported.FolderStatus = "unsupported-window" && unsupported.SelectionStatus = "unsupported-window", "Unsupported-window statuses")
    invalid := Explorer.GetContext(-1)
    TestAssert(invalid.FolderStatus != "ok" && invalid.SelectedPaths.Length = 0, "Invalid HWND fails safely")
    TestAssert(Explorer._AbsolutePath("C:\") && Explorer._AbsolutePath("\\server\share\folder"), "Absolute path forms")
    TestAssert(!Explorer._AbsolutePath("relative\folder") && !Explorer._AbsolutePath("C:relative"), "Relative paths rejected")

    expected := Explorer.Context(0, true)
    Explorer._Diagnostic(expected, "test", Explorer.ReadError("unresolved", "expected"))
    TestAssert(expected.Diagnostics.Length = 1, "Expected failures become diagnostics")
    propagated := false
    try Explorer._Diagnostic(expected, "test", TypeError("intentional programming error"))
    catch TypeError
        propagated := true
    TestAssert(propagated, "Programming errors are not swallowed")

    fixture := TestFixture("core")
    try {
        one := fixture.Directory "\report.txt"
        two := fixture.Directory "\report.md"
        FileAppend "fixture", one, "UTF-8"
        FileAppend "fixture", two, "UTF-8"
        folder := FakeFolder([
            {Name: "report.txt", Display: "report", Path: one, IsFileSystem: true},
            {Name: "report.md", Display: "report", Path: two, IsFileSystem: true}
        ])
        paths := Explorer._ResolveNames(["report.txt", "report.md"], folder)
        TestAssert(paths.Length = 2 && paths[1] = one && paths[2] = two, "Exact names resolve")
        ExpectReadError(() => Explorer._ResolveNames(["report"], folder), "unresolved", "Hidden-extension alias collision")
        ExpectReadError(() => Explorer._ResolveNames(["report.txt", "missing"], folder), "unresolved", "Partial resolution is rejected")
        ExpectReadError(() => Explorer._ResolveNames(["report.txt", "report.txt"], folder), "unresolved", "Duplicate selections rejected")
        virtual := FakeFolder([{Name: "Virtual", Display: "Virtual", Path: "::{virtual}", IsFileSystem: false}])
        ExpectReadError(() => Explorer._ResolveNames(["Virtual"], virtual), "not-filesystem", "Virtual selection rejected")
        FileDelete two
        ExpectReadError(() => Explorer._ResolveNames(["report.md"], folder), "unresolved", "Missing filesystem item rejected")
    } finally
        fixture.Cleanup()
    TestLog("PASS: core statuses, isolation, invalid HWND, paths, aliases, ambiguity, partial/duplicate/virtual/missing selections")
}

ExpectReadError(callback, status, label) {
    matched := false
    try callback.Call()
    catch Explorer.ReadError as err
        matched := err.Status = status
    TestAssert(matched, label)
}

class FakeItems extends Array {
    Filter(flags, pattern) {
        ; Fake collections expose the same call shape without using shell COM.
    }
}

class FakeFolder {
    __New(items) => this.Items := FakeItems(items*)
    GetDetailsOf(item, column) => item.Display
}

TestIntegration() {
    fixture := TestFixture("integration")
    try {
        fixture.Populate()
        fixture.Open()
        fixture.Select(["item-002.txt", "item-250.txt", fixture.UnicodeName])
        primary := Explorer.GetContext(fixture.Hwnd)
        AssertContext(primary, fixture.Directory, 3, "shell")
        folderOnly := Explorer.GetContext(fixture.Hwnd, false)
        TestAssert(folderOnly.FolderStatus = "ok" && folderOnly.FolderPath = fixture.Directory, "Folder-only lookup")
        TestAssert(folderOnly.SelectionStatus = "not-requested", "Folder-only lookup must not read selection")
        recovered := ForcedUIA.GetContext(fixture.Hwnd)
        AssertContext(recovered, fixture.Directory, 3, "uia")
        AssertSamePaths(primary.SelectedPaths, recovered.SelectedPaths)
        TestAssert(fixture.Window.Document.SelectedItems.Count = 3, "Recovery must not change selection")

        fullTree := FullWindowUIA.GetContext(fixture.Hwnd)
        AssertContext(fullTree, fixture.Directory, 3, "uia")
        AssertSamePaths(primary.SelectedPaths, fullTree.SelectedPaths)
        TestLog("PASS: shell/UIA/full-window parity, Unicode and offscreen multi-selection")

        fixture.Select(["item-002.txt"])
        AssertContext(Explorer.GetContext(fixture.Hwnd), fixture.Directory, 1, "shell")
        AssertContext(ForcedUIA.GetContext(fixture.Hwnd), fixture.Directory, 1, "uia")
        fixture.Deselect()
        AssertContext(Explorer.GetContext(fixture.Hwnd), fixture.Directory, 0, "shell")
        AssertContext(ForcedUIA.GetContext(fixture.Hwnd), fixture.Directory, 0, "uia")
        TestLog("PASS: single and empty selections; empty success does not invoke fallback")

        hiddenPath := fixture.Directory "\hidden selected.txt"
        FileAppend "fixture", hiddenPath, "UTF-8"
        FileSetAttrib "+H", hiddenPath
        detached := fixture.Shell.NameSpace(fixture.Directory)
        hiddenName := detached.GetDetailsOf(detached.ParseName("hidden selected.txt"), 0)
        paths := Explorer._ResolveNames([hiddenName], detached)
        TestAssert(paths.Length = 1 && paths[1] = hiddenPath, "Hidden-item name resolution")
        TestFolderEnumeration(fixture)
        TestTabs(fixture)
    } finally
        fixture.Cleanup()
}

AssertContext(result, folderPath, count, source) {
    if result.FolderStatus != "ok" || result.SelectionStatus != "ok" {
        for diagnostic in result.Diagnostics
            TestLog("  " diagnostic)
    }
    TestAssert(result.FolderStatus = "ok" && result.FolderPath = folderPath, "Folder identity")
    TestAssert(result.SelectionStatus = "ok" && result.SelectedPaths.Length = count, "Selection completeness")
    TestAssert(result.FolderSource = source && result.SelectionSource = source, "Expected backend: " source)
}

AssertSamePaths(expected, actual) {
    TestAssert(expected.Length = actual.Length, "Selection lengths match")
    identities := Map()
    identities.CaseSense := false
    for path in expected
        identities[path] := true
    for path in actual
        TestAssert(identities.Has(path), "Selected identity matches")
}

class ForcedUIA extends Explorer {
    static _ShellWindow(shell, hwnd, tab) {
        throw this.ReadError("unavailable", "Intentional test-only missing-registration simulation")
    }
}

class FullWindowUIA extends ForcedUIA {
    static _UIRoot(uia, hwnd) {
        if WinGetClass("ahk_id " hwnd) = "Microsoft.UI.Content.DesktopChildSiteBridge"
            throw this.ReadError("unavailable", "Intentional inaccessible toolbar-host simulation")
        return super._UIRoot(uia, hwnd)
    }
}

TestFolderEnumeration(fixture) {
    ordinary := fixture.Directory "\ordinary folder"
    hidden := fixture.Directory "\hidden folder"
    systemFolder := fixture.Directory "\system folder"
    for directory in [ordinary, hidden, systemFolder]
        DirCreate directory
    FileSetAttrib "+H", hidden
    FileSetAttrib "+S", systemFolder
    FileCreateShortcut ordinary, fixture.Directory "\folder shortcut.lnk"
    endRecord := Buffer(22, 0)
    NumPut "UInt", 0x06054B50, endRecord
    zip := FileOpen(fixture.Directory "\archive.zip", "w")
    zip.RawWrite(endRecord)
    zip.Close()
    for folder in [fixture.Shell.NameSpace(fixture.Directory), fixture.Shell.NameSpace(0), fixture.Shell.NameSpace(17)] {
        names := Map()
        for item in EnumerationReference.Items(folder) {
            if item.IsFolder {
                names[item.Name] := true
                names[folder.GetDetailsOf(item, 0)] := true
            }
        }
        names["__nonexistent_folder__"] := true
        for name in names {
            expected := Map(), actual := Map()
            for item in EnumerationReference.FoldersNamed(folder, name)
                expected[item.Path] := true
            for item in Explorer._FoldersNamed(folder, name)
                actual[item.Path] := true
            TestAssert(actual.Count = expected.Count, "Folder-filter count parity")
            for itemPath in expected
                TestAssert(actual.Has(itemPath), "Folder-filter identity parity")
        }
    }
    TestLog("PASS: hidden/system/ZIP/shortcut and desktop/drives enumeration parity")
}

; Reference behavior predating the folder-only enumeration optimization.
class EnumerationReference {
    static Items(folder) {
        items := folder.Items
        items.Filter(0x100E0, "*")
        return items
    }
    static FoldersNamed(folder, name) {
        matches := []
        for item in this.Items(folder) {
            if item.IsFolder && (item.Name = name || folder.GetDetailsOf(item, 0) = name)
                matches.Push(item)
        }
        return matches
    }
}

TestTabs(fixture) {
    uia := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
    root := Explorer._UIRoot(uia, fixture.Hwnd)
    buttons := Explorer._UIFind(uia, root, 30011, "AddButton")
    if !buttons.Length {
        TestLog("SKIP: tab controls not available on this Explorer version")
        return
    }
    TestAssert(buttons.Length = 1, "Unique add-tab control")
    originalTab := Explorer._ActiveTab(fixture.Hwnd)
    newFolder := fixture.Directory "\Second tab"
    DirCreate newFolder
    ComCall(3, Explorer._UIPattern(buttons[1], 10000)) ; Invoke only in our owned frame.
    newWindow := 0
    deadline := A_TickCount + 5000
    while !newWindow && A_TickCount < deadline {
        try {
            currentTab := Explorer._ActiveTab(fixture.Hwnd)
            if currentTab && currentTab != originalTab
                newWindow := Explorer._ShellWindow(fixture.Shell, fixture.Hwnd, currentTab)
        } catch Explorer.ReadError {
            ; Wait for this new tab's shell registration, without changing any registration.
        } catch OSError {
        }
        if !newWindow
            Sleep 50
    }
    TestAssert(IsObject(newWindow), "Distinct registered new tab")
    newWindow.Navigate2(newFolder)
    deadline := A_TickCount + 5000
    ready := false
    while !ready && A_TickCount < deadline {
        try ready := newWindow.Document.Folder.Self.Path = newFolder && !newWindow.Busy
        catch OSError {
        }
        if !ready
            Sleep 50
    }
    TestAssert(ready, "New tab navigation completed")
    AssertContext(Explorer.GetContext(fixture.Hwnd), newFolder, 0, "shell")
    AssertContext(ForcedUIA.GetContext(fixture.Hwnd), newFolder, 0, "uia")
    lists := Explorer._UIFind(uia, root, 30011, "TabListView")
    TestAssert(lists.Length = 1, "Unique tab strip")
    tabs := Explorer._UIFind(uia, lists[1], 30003, 50019)
    TestAssert(tabs.Length = 2, "Only the two test-owned tabs exist")
    ComCall(3, Explorer._UIPattern(tabs[1], 10010)) ; Select original test tab.
    Sleep 100
    AssertContext(Explorer.GetContext(fixture.Hwnd), fixture.Directory, 0, "shell")
    AssertContext(ForcedUIA.GetContext(fixture.Hwnd), fixture.Directory, 0, "uia")
    TestLog("PASS: active-tab identity in both directions, shell and forced UIA")
}
