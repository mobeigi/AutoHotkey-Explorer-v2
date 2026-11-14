#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
#Include %A_ScriptDir%\..\Explorer_v2.ahk

; Activate an Explorer window, then press Ctrl+Alt+E to inspect its context.
; Exit this demo from its AutoHotkey tray icon when finished.
^!e:: {
    ; Capture before showing a message box, which would change the foreground.
    context := Explorer.GetContext()
    message := "Window HWND: " context.WindowHwnd
    message .= "`n`nFolder status: " context.FolderStatus
    message .= "`nFolder source: " (context.FolderSource != "" ? context.FolderSource : "(none)")
    if context.FolderStatus = "ok"
        message .= "`nFolder: " context.FolderPath

    message .= "`n`nSelection status: " context.SelectionStatus
    message .= "`nSelection source: " (context.SelectionSource != "" ? context.SelectionSource : "(none)")
    if context.SelectionStatus = "ok" {
        if !context.SelectedPaths.Length
            message .= "`nNothing selected."
        else {
            message .= "`nSelected paths:"
            for path in context.SelectedPaths
                message .= "`n" path
        }
    } else
        message .= "`nSelection could not be read; this does not mean nothing is selected."

    for diagnostic in context.Diagnostics
        message .= "`n`nDiagnostic: " diagnostic
    MsgBox message, "Explorer context demo"
}
