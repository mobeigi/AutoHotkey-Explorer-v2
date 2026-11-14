#Requires AutoHotkey v2.0
#Warn All, StdOut
#Include %A_ScriptDir%\..\Explorer_v2.ahk

Main()

Main() {
    try {
        hwnd := FindDesktop()
        context := Explorer.GetContext(hwnd)
        FileAppend "Live Desktop: folder=" context.FolderStatus " selection=" context.SelectionStatus " count=" context.SelectedPaths.Length "`n", "*"
        for diagnostic in context.Diagnostics
            FileAppend "  " diagnostic "`n", "*"
        Assert(context.FolderStatus = "ok" && context.FolderPath = A_Desktop, "Desktop directory")
        Assert(context.SelectionStatus = "ok" || context.SelectionStatus = "not-filesystem"
            || context.SelectionStatus = "unresolved", "Desktop selection is accessible")
        TestIsolatedSelection(hwnd)
        FileAppend "PASS: desktop tests; AHK " A_AhkVersion ", " (A_PtrSize * 8) "-bit`n", "*"
    } catch as err {
        FileAppend "FAIL: " err.Message "`n" err.Stack "`n", "*"
        ExitApp 1
    }
    ExitApp 0
}

FindDesktop() {
    for windowClass in ["Progman", "WorkerW"] {
        for hwnd in WinGetList("ahk_class " windowClass " ahk_exe explorer.exe") {
            if Explorer._ViewHwnd(hwnd)
                return hwnd
        }
    }
    throw Error("No visible native Desktop view found")
}

TestIsolatedSelection(desktopHwnd) {
    shell := ComObject("Shell.Application")
    folder := shell.NameSpace(0)
    chosen := [], candidates := [], virtualName := "", common := 0, ordinaryFile := 0, ordinaryFolder := 0
    for item in Explorer._Items(folder) {
        name := folder.GetDetailsOf(item, 0)
        if !item.IsFileSystem {
            if virtualName = "" && name != ""
                virtualName := name
            continue
        }
        path := item.Path
        SplitPath path, , &parent
        if parent != A_Desktop && parent != A_DesktopCommon
            continue
        try paths := Explorer._ResolveNames([name], folder)
        catch Explorer.ReadError
            continue
        if paths.Length != 1 || paths[1] != path
            continue
        candidate := {Name: name, Path: path}
        candidates.Push(candidate)
        if parent = A_DesktopCommon && !IsObject(common)
            common := candidate
        if item.IsFolder && !IsObject(ordinaryFolder)
            ordinaryFolder := candidate
        else if !item.IsFolder && !IsObject(ordinaryFile)
            ordinaryFile := candidate
    }
    for candidate in [ordinaryFile, ordinaryFolder, common] {
        if !IsObject(candidate)
            continue
        duplicate := false
        for existing in chosen
            duplicate := duplicate || existing.Path = candidate.Path
        if !duplicate
            chosen.Push(candidate)
    }
    ; Fill the minimum even when available icons all belong to the same category.
    for candidate in candidates {
        if chosen.Length >= 2
            break
        duplicate := false
        for existing in chosen
            duplicate := duplicate || existing.Path = candidate.Path
        if !duplicate
            chosen.Push(candidate)
    }
    Assert(chosen.Length >= 2, "Need two unambiguous existing filesystem Desktop icons for read-only mapping checks")
    if !IsObject(ordinaryFile)
        FileAppend "SKIP: no unambiguous filesystem Desktop file available`n", "*"
    if !IsObject(ordinaryFolder)
        FileAppend "SKIP: no unambiguous filesystem Desktop folder available`n", "*"
    if !IsObject(common)
        FileAppend "SKIP: no unambiguous Public Desktop item available`n", "*"
    if virtualName = ""
        FileAppend "SKIP: no virtual Desktop icon available`n", "*"

    ; This fixture only displays names. It never selects, changes or opens an
    ; actual Desktop icon. UIA queries the same native list-control type.
    fixture := Gui("+ToolWindow", "Desktop selection regression fixture")
    list := fixture.AddListView("Icon w520 h220", ["Name"])
    for candidate in chosen
        list.Add(, candidate.Name)
    if virtualName != ""
        list.Add(, virtualName)
    fixture.Show("NA")
    try {
        Assert(Explorer._DesktopListHwnd(fixture.Hwnd) = list.Hwnd, "Native list discovery")
        Assert(Explorer.GetContext(fixture.Hwnd).FolderStatus = "unsupported-window", "Non-Explorer native lists are not recognized as Desktop")
        FixtureDesktop.ListHwnd := list.Hwnd
        result := FixtureDesktop.GetContext(desktopHwnd)
        Assert(result.SelectionStatus = "ok" && result.SelectedPaths.Length = 0, "Empty Desktop selection")
        for index, candidate in chosen {
            list.Modify(0, "-Select")
            list.Modify(index, "Select Focus")
            result := FixtureDesktop.GetContext(desktopHwnd)
            Assert(result.SelectionStatus = "ok" && result.SelectedPaths.Length = 1 && result.SelectedPaths[1] = candidate.Path, "Single file/folder/common Desktop identity")
        }
        list.Modify(0, "-Select")
        Loop chosen.Length
            list.Modify(A_Index, "Select")
        result := FixtureDesktop.GetContext(desktopHwnd)
        Assert(result.SelectionStatus = "ok" && result.SelectedPaths.Length = chosen.Length, "Multiple Desktop selections")
        for path in result.SelectedPaths {
            found := false
            for candidate in chosen
                found := found || candidate.Path = path
            Assert(found, "Resolved selection identity")
        }
        if virtualName != "" {
            list.Modify(0, "-Select")
            list.Modify(chosen.Length + 1, "Select")
            result := FixtureDesktop.GetContext(desktopHwnd)
            Assert(result.SelectionStatus = "not-filesystem" || result.SelectionStatus = "unresolved", "Virtual Desktop icons fail closed")
            Assert(result.SelectedPaths.Length = 0, "Virtual selection has no guessed paths")
        }
        FileAppend "PASS: isolated empty/single/multiple Desktop selection identities`n", "*"
    } finally {
        FixtureDesktop.ListHwnd := 0
        fixture.Destroy()
    }
}

class FixtureDesktop extends Explorer {
    static ListHwnd := 0
    static _DesktopListHwnd(view) => this.ListHwnd
}

Assert(condition, message) {
    if !condition
        throw Error(message)
}
