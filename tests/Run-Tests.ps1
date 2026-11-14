[CmdletBinding()]
param(
    [string[]]$AutoHotkeyPath,
    [switch]$Integration,
    [switch]$Desktop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not $AutoHotkeyPath) {
    $AutoHotkeyPath = @(
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey32.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
}
if (-not $AutoHotkeyPath) {
    throw 'No AutoHotkey v2 interpreter found. Pass -AutoHotkeyPath explicitly.'
}

function Invoke-Ahk {
    param([string]$Executable, [string[]]$Arguments)
    Write-Host ('RUN: "{0}" {1}' -f $Executable, ($Arguments -join ' '))
    # Piping waits for the GUI-subsystem executable before reading its exit code.
    $output = @(& $Executable /ErrorStdOut=UTF-8 @Arguments 2>&1 | ForEach-Object { $_ })
    $output | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "AutoHotkey returned exit code $LASTEXITCODE"
    }
    if ($Arguments[0] -eq '/Validate' -and $output.Count -gt 0) {
        throw 'Unexpected validator output: resolve warnings as well as errors.'
    }
}

# Explicit project paths keep local/untracked reference material out of discovery.
$scripts = @(
    Get-Item -LiteralPath (Join-Path $root 'Explorer_v2.ahk')
    Get-ChildItem -LiteralPath (Join-Path $root 'examples'), $PSScriptRoot -Filter '*.ahk' -Recurse -File
)
foreach ($exe in $AutoHotkeyPath) {
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "Interpreter does not exist: $exe"
    }
    foreach ($script in $scripts) {
        Invoke-Ahk -Executable $exe -Arguments @('/Validate', $script.FullName)
    }
    $arguments = @((Join-Path $PSScriptRoot 'Explorer.Tests.ahk'))
    if ($Integration) { $arguments += '--integration' }
    Invoke-Ahk -Executable $exe -Arguments $arguments
    if ($Desktop) {
        Invoke-Ahk -Executable $exe -Arguments @((Join-Path $PSScriptRoot 'DesktopSelection.Tests.ahk'))
    }
}
Write-Host 'PASS: requested checks completed. The demo was validated, not launched.'
