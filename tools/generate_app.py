# Generate src/app.lua from the v1.9.7 monolith, wrapping it as a Hub factory.
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "_source.lua.txt"
OUT = ROOT / "src" / "app.lua"

# 1-indexed inclusive ranges to drop (replaced by modules).
SKIP = [
    (422, 473),  # FarmStats table — lives in data.lua
    (584, 679),  # Unload pipeline / globals / kill switch — lives in cleanup.lua
]

HEADER = r'''--!strict
-- Runtime body: GUI, features, farm, ESP, combat. Framework services come from Hub.
return function(Hub: any)
    local Flags = Hub.Flags
    local State = Hub.State
    local Theme = Hub.Theme
    local Scheduler = Hub.Scheduler
    local player = Hub.player
    local playerGui = Hub.playerGui
    local clampNum = Hub.clampNum
    local log = Hub.log
    local new = Hub.new
    local corner = Hub.corner
    local stroke = Hub.stroke
    local pad = Hub.pad
    local gradient = Hub.gradient
    local tween = Hub.tween
    local isPointerBegin = Hub.isPointerBegin
    local isPointerMove = Hub.isPointerMove
    local isKeyDown = Hub.isKeyDown
    local inputMatches = Hub.inputMatches
    local FrameRate = Hub.FrameRate
    local getPingMs = Hub.getPingMs
    local track = Hub.track
    local trackPage = Hub.trackPage
    local holdDebris = Hub.holdDebris
    local clearPageScope = Hub.clearPageScope
    local disconnectAll = Hub.disconnectAll
    local Unload = Hub.Unload
    local EnvDefaults = Hub.EnvDefaults
    local FarmStats = Hub.FarmStats
    local RESOURCE_NAMES = Hub.RESOURCE_NAMES
    local RESOURCE_LIST = Hub.RESOURCE_LIST
    local SELL_STYLES = Hub.SELL_STYLES
    local fireSell = Hub.fireSell
    local isHubInstance = Hub.isHubInstance
    local Players = Hub.Services.Players
    local UserInputService = Hub.Services.UserInputService
    local RunService = Hub.Services.RunService
    local TweenService = Hub.Services.TweenService
    local ReplicatedStorage = Hub.Services.ReplicatedStorage
    local Lighting = Hub.Services.Lighting
    local TeleportService = Hub.Services.TeleportService
    local Stats = Hub.Services.Stats
    local HttpService = Hub.Services.HttpService
    local GuiService = Hub.Services.GuiService
    local ProximityPromptService = Hub.Services.ProximityPromptService

    local cancelMoveTween
    local unlockMovement
    local clearNodeOffsets
    local flightCleanup
    local noclipCleanup
    local infJumpCleanup
    local fullbrightCleanup
    local xrayCleanup
    local aimbotCleanup
    local fovCircleGui, fovCircle

'''

FOOTER = r'''
    Hub.Features = Features
    Hub.FEATURE_SETTERS = FEATURE_SETTERS
    Hub.toggleSync = toggleSync
    Hub.setFeature = setFeature
    Hub.Config = Config
    Hub.Stealth = Stealth
    Hub.ScreenGui = ScreenGui
    Hub.Notifications = Notifications
    Hub.applyWalkSettings = applyWalkSettings
    Hub.applyAccents = applyAccents
    Hub.applyUiScale = applyUiScale
    Hub.ResourceScanner = ResourceScanner
    Hub.ServerTools = ServerTools
    -- Closures over the runtime locals, so later assignments are visible to Unload.
    Hub.hooks.cancelMoveTween = function()
        if cancelMoveTween then cancelMoveTween() end
    end
    Hub.hooks.unlockMovement = function()
        if unlockMovement then unlockMovement() end
    end
    Hub.hooks.clearNodeOffsets = function()
        if clearNodeOffsets then clearNodeOffsets() end
    end
    Hub.hooks.flightCleanup = function()
        if flightCleanup then flightCleanup() end
    end
    Hub.hooks.noclipCleanup = function()
        if noclipCleanup then noclipCleanup() end
    end
    Hub.hooks.infJumpCleanup = function()
        if infJumpCleanup then infJumpCleanup() end
    end
    Hub.hooks.fullbrightCleanup = function()
        if fullbrightCleanup then fullbrightCleanup() end
    end
    Hub.hooks.xrayCleanup = function()
        if xrayCleanup then xrayCleanup() end
    end
    Hub.hooks.aimbotCleanup = function()
        if aimbotCleanup then aimbotCleanup() end
    end
    Hub.hooks.destroyFov = function()
        if fovCircleGui then pcall(function() fovCircleGui:Destroy() end) end
    end
    return Hub
end
'''


def skipped(n: int) -> bool:
    for a, b in SKIP:
        if a <= n <= b:
            return True
    return False


def main() -> None:
    raw = SOURCE.read_text(encoding="utf-8-sig")
    lines = raw.splitlines()
    kept: list[str] = []
    for i, line in enumerate(lines, start=1):
        if i < 422:
            continue
        if skipped(i):
            continue
        kept.append(line)
    body = "\n".join(kept)
    body = re.sub(r"(?<!Flags\.)\bUnloading\b", "Flags.Unloading", body)
    body = body.replace("v1.9.7", "2.0.0")
    OUT.write_text(HEADER + body + FOOTER, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({len(kept)} lines from source)")


if __name__ == "__main__":
    main()
