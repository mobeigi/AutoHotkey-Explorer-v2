#Requires AutoHotkey v2.0

TestAssert(condition, message) {
    if !condition
        throw Error(message)
}

TestLog(message) => FileAppend(message "`n", "*", "UTF-8")

class TestFixture {
    __New(label := "fixture") {
        baseDirectory := A_Temp "\ExplorerTests"
        DirCreate baseDirectory
        this.Directory := baseDirectory "\" label "-" DllCall("GetCurrentProcessId", "UInt") "-" A_TickCount "-" Random(100000, 999999)
        TestAssert(!FileExist(this.Directory), "Fixture destination must be new")
        DirCreate this.Directory
        this.Shell := 0
        this.Window := 0
        this.Hwnd := 0
        this.KeepFiles := false
    }

    Populate(count := 260) {
        Loop count
            FileAppend "fixture", this.Directory "\item-" Format("{:03}", A_Index) ".txt", "UTF-8"
        this.UnicodeName := Chr(0x03A9) " unicode name.txt"
        FileAppend "fixture", this.Directory "\" this.UnicodeName, "UTF-8"
    }

    Open() {
        this.Shell := ComObject("Shell.Application")
        existing := Map()
        for window in this.Shell.Windows
            existing[window.HWND] := true
        this.Shell.Explore(this.Directory)
        deadline := A_TickCount + 10000
        while !this.Window && A_TickCount < deadline {
            for window in this.Shell.Windows {
                try {
                    if existing.Has(window.HWND)
                        continue
                    document := window.Document
                    if !IsObject(document)
                        continue
                    folder := document.Folder
                    if IsObject(folder) && folder.Self.Path = this.Directory {
                        this.Window := window
                        this.Hwnd := window.HWND
                        break
                    }
                } catch OSError {
                    ; A newly created shell entry can be transiently unavailable.
                }
            }
            if !this.Window
                Sleep 50
        }
        if !this.Window {
            this.KeepFiles := true
            throw Error("No isolated test-owned Explorer window appeared. Check desktop/session settings; retained " this.Directory)
        }
        Sleep 200
    }

    Select(names) {
        document := this.Window.Document
        folder := document.Folder
        first := true
        for name in names {
            item := folder.ParseName(name)
            TestAssert(IsObject(item), "Fixture item exists: " name)
            document.SelectItem(item, first ? 5 : 1) ; SELECT | DESELECTOTHERS, then SELECT.
            first := false
        }
        Sleep 100
        TestAssert(document.SelectedItems.Count = names.Length, "Fixture selection count")
    }

    Deselect() {
        this.Window.Document.SelectItem(this.Window.Document.Folder.ParseName("item-002.txt"), 4)
        Sleep 100
        TestAssert(this.Window.Document.SelectedItems.Count = 0, "Fixture selection cleared")
    }

    Cleanup() {
        if this.Hwnd && WinExist("ahk_id " this.Hwnd) {
            try {
                ; Some Explorer builds interpret WM_CLOSE as closing only the
                ; active tab. Re-check ownership before each bounded close.
                attempts := this._OwnedTabCount() + 1
                Loop attempts {
                    if !WinExist("ahk_id " this.Hwnd)
                        break
                    TestAssert(this._OwnedTabCount() > 0, "Cannot safely identify every remaining test tab")
                    WinClose("ahk_id " this.Hwnd, , 0.5)
                }
                if WinExist("ahk_id " this.Hwnd)
                    this.KeepFiles := true
            } catch as err {
                this.KeepFiles := true
                TestLog("WARNING: test-window cleanup: " err.Message)
            }
        }
        if this.KeepFiles {
            TestLog("WARNING: retained fixture for safe/manual cleanup: " this.Directory)
            return
        }
        ; Only this newly created, uniquely named fixture is ever removed.
        if DirExist(this.Directory)
            DirDelete this.Directory, true
    }

    _OwnedTabCount() {
        if WinGetProcessName("ahk_id " this.Hwnd) != "explorer.exe"
            return 0
        count := 0
        for window in this.Shell.Windows {
            if window.HWND != this.Hwnd
                continue
            path := window.Document.Folder.Self.Path
            if path != this.Directory && InStr(path, this.Directory "\") != 1
                return 0
            count += 1
        }
        return count
    }
}
