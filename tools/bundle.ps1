# Bundle TroyHub src into one executor inject file.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Root "src"
$Out = Join-Path $Root "TroyHub.lua"
$Inject = Join-Path $env:USERPROFILE "Desktop\Learning Luau Example.lua.txt"

$modules = @(
    "core/utils",
    "core/logger",
    "config/data",
    "core/constants",
    "core/state",
    "core/theme",
    "core/cleanup",
    "core/tasks",
    "core/scheduler",
    "core/lifecycle",
    "core/featureManager",
    "core/hotkeys",
    "features/movement",
    "features/utility",
    "features/esp",
    "features/combat",
    "features/farming",
    "ui/app",
    "config/config",
    "ui/gui"
)

function Get-ModuleSource([string]$rel) {
    $path = Join-Path $Src ($rel + ".lua")
    $text = [System.IO.File]::ReadAllText($path)
    $text = $text -replace '(?m)^--!strict\s*\r?\n', ''
    return $text.TrimEnd()
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("--!strict")
[void]$sb.AppendLine("-- TroyHub 2.0.7 bundled from src/. Edit modules and re-run tools/bundle.ps1.")
[void]$sb.AppendLine("local function __troyDefPack()")
[void]$sb.AppendLine("    local pack = {}")
[void]$sb.AppendLine("    local function def(name, factory)")
[void]$sb.AppendLine("        pack[name] = factory")
[void]$sb.AppendLine("    end")
[void]$sb.AppendLine("    local function import(name)")
[void]$sb.AppendLine("        local factory = pack[name]")
[void]$sb.AppendLine("        if type(factory) ~= `"function`" then")
[void]$sb.AppendLine("            error(`"TroyHub missing module `" .. tostring(name))")
[void]$sb.AppendLine("        end")
[void]$sb.AppendLine("        return factory()")
[void]$sb.AppendLine("    end")
[void]$sb.AppendLine("")

foreach ($name in $modules) {
    $body = Get-ModuleSource $name
    [void]$sb.AppendLine("    def(`"$name`", function()")
    [void]$sb.AppendLine($body)
    [void]$sb.AppendLine("    end)")
    [void]$sb.AppendLine("")
}

$init = Get-ModuleSource "init"
[void]$sb.AppendLine("    local boot = (function()")
[void]$sb.AppendLine($init)
[void]$sb.AppendLine("    end)()")
[void]$sb.AppendLine("    boot(import)")
[void]$sb.AppendLine("end")
[void]$sb.AppendLine("__troyDefPack()")

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($Out, $sb.ToString(), $utf8)
[System.IO.File]::WriteAllText($Inject, $sb.ToString(), $utf8)

Write-Host "Bundled $Out"
Write-Host "Copied  $Inject"
Write-Host ("Bytes   " + (Get-Item $Out).Length)
