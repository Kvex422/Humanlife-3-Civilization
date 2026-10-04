--!strict
-- GUI, farm, ESP, combat pages. Core services come from Hub.
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
    local applyGatherPower
    local restoreGatherPower
    local farmActive
    local aimbotCleanup
    local fovCircleGui, fovCircle


-- Only accrues while a farm mode is actually on, so nodes/min reflects
-- farming time rather than how long the hub has been injected.
Scheduler.add("farmclock", "logic", 1, function()
    if Flags.Unloading then return end
    if State.AutoGather or State.TeleportGather or State.GatherAround or State.LegitMode then
        FarmStats.runSeconds += 1
    end
end)

    local applyWalkSettings = Hub.applyWalkSettings
    if not applyWalkSettings then
        applyWalkSettings = function(hum: Humanoid)
            hum.UseJumpPower = true
            hum.JumpPower = clampNum(State.JumpPower, 0, 500, 50)
            if not State.EnableWalkSpeed then
                hum.WalkSpeed = 16
                return
            end
            local method = State.WalkSpeedMethod
            if method == "Rigid" then
                hum.WalkSpeed = 0
            elseif method == "Boost" then
                hum.WalkSpeed = 16
            else
                hum.WalkSpeed = clampNum(State.WalkSpeed, 0, 500, 40)
            end
        end
        Hub.applyWalkSettings = applyWalkSettings
    end

-- ============================================================
--  ROOT GUI
-- ============================================================
local ScreenGui = new("ScreenGui", {
    Name = "TroyHub", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    DisplayOrder = 999, Parent = playerGui,
})

-- Hub clicks must not keep keyboard focus, or hold-to-interact dies.
local promptVisible = 0
local function isOurGui(inst: Instance): boolean
    local root = inst
    while root.Parent and root.Parent ~= playerGui do
        root = root.Parent
    end
    return isHubInstance(root.Name)
end
local function releaseGuiFocus()
    if UserInputService:GetFocusedTextBox() then return end
    local sel = GuiService.SelectedObject
    if sel and isOurGui(sel) then
        GuiService.SelectedObject = nil
    end
end
Scheduler.add("guifocus", "logic", 0.1, releaseGuiFocus)
pcall(function()
    track(ProximityPromptService.PromptShown:Connect(function()
        promptVisible += 1
        releaseGuiFocus()
    end))
    track(ProximityPromptService.PromptHidden:Connect(function()
        promptVisible = math.max(0, promptVisible - 1)
    end))
end)

local Main = new("Frame", {
    Name = "Main", Size = UDim2.fromOffset(880, 580),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Parent = ScreenGui,
})
corner(16, Main)
stroke(Theme.Stroke, 1, Main)

local Header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Theme.Glass,
    BorderSizePixel = 0, Active = true, Parent = Main,
})
corner(16, Header)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = Theme.Glass, BorderSizePixel = 0, Parent = Header,
})
local HeaderStrip = new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = Header,
})

local Logo = new("Frame", {
    Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(16, 13),
    BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = Header,
})
corner(8, Logo)
new("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Font = Theme.FontBlack, Text = "T", TextColor3 = Theme.Bg,
    TextSize = 16, Parent = Logo,
})

new("TextLabel", {
    Size = UDim2.fromOffset(360, 20), Position = UDim2.fromOffset(58, 10),
    BackgroundTransparency = 1, Font = Theme.FontBold, Text = "Troy",
    TextColor3 = Theme.Text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Header,
})
new("TextLabel", {
    Size = UDim2.fromOffset(400, 16), Position = UDim2.fromOffset(58, 30),
    BackgroundTransparency = 1, Font = Theme.Font,
    Text = "Humanlife 3: Civilization   ·   2.0.6",
    TextColor3 = Theme.TextFaint, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = Header,
})


local function later(seconds: number, fn: () -> ())
    if Hub.Tasks then
        return Hub.Tasks.delay(seconds, fn)
    end
    return task.delay(seconds, fn)
end

local function CloseAndUnload()
    if Flags.Unloading or Flags.Closing then return end
    Flags.Closing = true
    tween(Main, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.18,
        Enum.EasingStyle.Back, Enum.EasingDirection.In)
    later(0.2, Unload)
end

local function makeWinBtn(text, x, hoverColor, onClick)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, x, 0, 11),
        BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
        Font = Theme.FontBold, Text = text, TextColor3 = Theme.TextDim,
        TextSize = 14, AutoButtonColor = false, Parent = Header,
    })
    corner(8, b)
    track(b.MouseEnter:Connect(function()
        tween(b, { BackgroundColor3 = hoverColor, TextColor3 = Color3.new(1,1,1) }, 0.12)
    end))
    track(b.MouseLeave:Connect(function()
        tween(b, { BackgroundColor3 = Theme.GlassHi, TextColor3 = Theme.TextDim }, 0.12)
    end))
    if onClick then track(b.MouseButton1Click:Connect(onClick)) end
    return b
end

makeWinBtn("✕", -44, Theme.Danger, CloseAndUnload)
makeWinBtn("–", -78, Theme.Accent, function() ScreenGui.Enabled = false end)

local Sidebar = new("Frame", {
    Size = UDim2.new(0, 204, 1, -58), Position = UDim2.fromOffset(0, 58),
    BackgroundColor3 = Theme.Glass, BorderSizePixel = 0, Parent = Main,
})
corner(0, Sidebar)
new("Frame", {
    Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0),
    BackgroundColor3 = Theme.Glass, BorderSizePixel = 0, Parent = Sidebar,
})

local Content = new("ScrollingFrame", {
    Name = "Content", Size = UDim2.new(1, -220, 1, -74),
    Position = UDim2.fromOffset(212, 66), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Accent, ScrollBarImageTransparency = 0.4,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Main,
})

-- ============================================================
--  UI SCALING
--  Phone screens and 4K ultrawides both need help: the window is a fixed
--  860x560, which overflows a small viewport and looks like a postage stamp on
--  a large one. One UIScale on Main handles both without touching layout math.
-- ============================================================
local applyUiScale
do
    local scaler = new("UIScale", { Scale = 1, Parent = Main })

    local function autoScaleFor(viewport: Vector2): number
        local fit = math.min((viewport.X - 24) / 880, (viewport.Y - 24) / 580)
        if fit < 1 then
            -- Small screen: shrink just enough to fit, never below legibility.
            return math.max(fit, 0.5)
        end
        -- Large screen: grow gently so the hub stays a panel, not a wallpaper.
        return math.clamp(1 + (fit - 1) * 0.35, 1, 1.6)
    end

    applyUiScale = function()
        local cam = workspace.CurrentCamera
        local viewport = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local scale = if State.AutoUIScale then autoScaleFor(viewport) else 1
        scale *= clampNum(State.UIScale, 0.5, 2, 1)
        scaler.Scale = math.clamp(scale, 0.4, 2.5)
    end
end

applyUiScale()
pcall(function()
    local cam = workspace.CurrentCamera
    if cam then
        track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            pcall(applyUiScale)
        end))
    end
end)

-- ============================================================
--  THEME RECOLOUR
--  Widgets bake Theme colours in at build time, so changing the accent has to
--  rewrite what is already on screen. Matching on the exact old colour means
--  unrelated greys and whites are left alone.
-- ============================================================
local applyAccents
do
    applyAccents = function(accent: Color3, accent2: Color3)
        if Hub.applyAccents then
            Hub.applyAccents(accent, accent2)
        else
            Theme.Accent = accent
            Theme.Accent2 = accent2
            State.ThemeAccent = accent
            State.ThemeAccent2 = accent2
        end
    end
end

-- ============================================================
--  NOTIFICATIONS
-- ============================================================
local Notifications = {}
do
    local container = new("Frame", {
        Name = "Notifications", Size = UDim2.new(0, 300, 1, -40),
        Position = UDim2.new(1, -320, 0, 20), BackgroundTransparency = 1, Parent = ScreenGui,
    })
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top, Parent = container,
    })

    local COLORS = { info = Theme.Accent, success = Theme.Success, warn = Theme.Warn, error = Theme.Danger }
    local count = 0

    local function push(title, message, kind, duration)
        kind = kind or "info"; duration = duration or 3
        count += 1
        local accent = COLORS[kind] or Theme.Accent

        local toast = new("Frame", {
            Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Theme.Glass,
            BackgroundTransparency = 1, BorderSizePixel = 0,
            LayoutOrder = count, Parent = container,
        })
        corner(10, toast)
        local toastStroke = stroke(Theme.StrokeHi, 1, toast)
        toastStroke.Transparency = 1
        new("Frame", {
            Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8),
            BackgroundColor3 = accent, BorderSizePixel = 0, Parent = toast,
        })
        new("TextLabel", {
            Size = UDim2.new(1, -30, 0, 18), Position = UDim2.fromOffset(20, 10),
            BackgroundTransparency = 1, Font = Theme.FontBold, Text = title,
            TextColor3 = Theme.Text, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = toast,
        })
        new("TextLabel", {
            Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(20, 28),
            BackgroundTransparency = 1, Font = Theme.Font, Text = message,
            TextColor3 = Theme.TextDim, TextSize = 11, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = toast,
        })
        local progressTrack = new("Frame", {
            Size = UDim2.new(1, -20, 0, 2), Position = UDim2.new(0, 10, 1, -6),
            BackgroundColor3 = Theme.TrackOff, BorderSizePixel = 0, Parent = toast,
        })
        local progressFill = new("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent,
            BorderSizePixel = 0, Parent = progressTrack,
        })
        TweenService:Create(toast, TweenInfo.new(0.22), { BackgroundTransparency = 0 }):Play()
        TweenService:Create(toastStroke, TweenInfo.new(0.22), { Transparency = 0 }):Play()
        TweenService:Create(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            Size = UDim2.fromScale(0, 1),
        }):Play()
        later(duration, function()
            if Flags.Unloading or not toast.Parent then return end
            TweenService:Create(toast, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(toastStroke, TweenInfo.new(0.22), { Transparency = 1 }):Play()
            for _, c in toast:GetDescendants() do
                if c:IsA("TextLabel") then
                    TweenService:Create(c, TweenInfo.new(0.22), { TextTransparency = 1 }):Play()
                end
            end
            later(0.25, function()
                if toast.Parent then toast:Destroy() end
            end)
        end)
    end

    function Notifications.info(t, m, d)    push(t, m, "info", d) end
    function Notifications.success(t, m, d) push(t, m, "success", d) end
    function Notifications.warn(t, m, d)    push(t, m, "warn", d) end
    function Notifications.error(t, m, d)   push(t, m, "error", d) end
end

-- ============================================================
--  FEATURE TOGGLES (Registry is the only door)
-- ============================================================
local toggleSync = {}
Hub.toggleSync = toggleSync
local keybindCapturing = false

local function setFeature(name: string, on: boolean, notify: boolean?)
    if not Hub.Registry then
        return
    end
    if on then
        Hub.Registry.enable(name, notify)
    else
        Hub.Registry.disable(name, notify)
    end
end

local rerenderCurrentPage: (() -> ())? = nil

-- ============================================================
--  STEALTH PROFILES
--  Each profile is a bundle of the movement settings that trade throughput for
--  how obvious the client looks. Fast is what the hub did before this existed.
-- ============================================================
local Stealth = {}
Stealth.order = { "Fast", "Balanced", "Safe" }
Stealth.presets = {
    Fast = {
        SoftTeleport = false, TravelHops = false, UsePin = true, PinMax = 600,
        LandingJitter = false, VelocityClamp = false, HitGap = 0.08,
        GatherSpeed = 100, SoftTeleportSpeed = 600, HopDistance = 400,
        MaxVelocity = 400, LandSpread = 0, FireFloor = 0.02,
        SkipSeconds = 6, ClusterRadius = 70, ClusterSeconds = 45,
        Overpower = true, HitsPerSwing = 4, PowerScale = 3,
    },
    Balanced = {
        SoftTeleport = false, TravelHops = true, UsePin = true, PinMax = 8,
        LandingJitter = true, VelocityClamp = false, HitGap = 0.12,
        GatherSpeed = 80, SoftTeleportSpeed = 300, HopDistance = 180,
        MaxVelocity = 220, LandSpread = 1.4, FireFloor = 0.03,
        SkipSeconds = 8, ClusterRadius = 90, ClusterSeconds = 60,
        Overpower = true, HitsPerSwing = 3, PowerScale = 2,
    },
    Safe = {
        SoftTeleport = true, TravelHops = true, UsePin = false, PinMax = 0,
        LandingJitter = true, VelocityClamp = true, HitGap = 0.22,
        GatherSpeed = 45, SoftTeleportSpeed = 140, HopDistance = 90,
        MaxVelocity = 120, LandSpread = 2.6, FireFloor = 0.06,
        SkipSeconds = 12, ClusterRadius = 120, ClusterSeconds = 90,
        Overpower = true, HitsPerSwing = 2, PowerScale = 1,
    },
}

Stealth.notes = {
    Fast = "Hard teleports, permanent pin. Highest yield, most obvious.",
    Balanced = "Hopped travel, pin rationed to 8s, jittered landings.",
    Safe = "Glided travel, no anchor, clamped velocity. Slowest.",
}

function Stealth.apply(name: string, notify: boolean?)
    local preset = Stealth.presets[name]
    if not preset then return end
    State.StealthProfile = name
    for key, value in preset do
        State[key] = value
    end
    if notify then
        Notifications.info("Stealth: " .. name, Stealth.notes[name] or "")
    end
end

-- ============================================================
--  SERVER TOOLS
--  Shared by the Server page buttons and by auto-rejoin, so hop logic exists
--  in one place instead of being duplicated per button.
-- ============================================================
local ServerTools = {}
do
    local lastTeleportAt = 0

    local function canTeleport(): boolean
        -- Roblox rate-limits teleports; firing again inside the window just
        -- burns the attempt and leaves the user sitting in the same server.
        if os.clock() - lastTeleportAt < 12 then
            Notifications.warn("Server", "Teleport already in progress")
            return false
        end
        lastTeleportAt = os.clock()
        return true
    end

    function ServerTools.fetchServers(): { any }?
        local ok, payload = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId ..
                "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and type(payload) == "table" and type(payload.data) == "table" then
            return payload.data
        end
        return nil
    end

    function ServerTools.joinJob(jobId: string): boolean
        if type(jobId) ~= "string" or #jobId < 8 then
            Notifications.warn("Server", "That does not look like a JobId")
            return false
        end
        if jobId == game.JobId then
            Notifications.warn("Server", "That is the server you are already in")
            return false
        end
        if not canTeleport() then return false end
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
        end)
        if not ok then
            Notifications.error("Server", "Teleport was rejected")
        end
        return ok
    end

    function ServerTools.rejoin(): boolean
        if not canTeleport() then return false end
        local ok = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        if not ok then Notifications.error("Rejoin", "Teleport was rejected") end
        return ok
    end

    -- smallest = pick the emptiest server; otherwise the first one with room.
    function ServerTools.hop(smallest: boolean?): boolean
        Notifications.info("Server", "Looking for another server…")
        local servers = ServerTools.fetchServers()
        if not servers then
            Notifications.error("Server Hop", "Could not read the server list")
            return false
        end
        local pick = nil
        for _, s in servers do
            if s.id ~= game.JobId and type(s.playing) == "number" and type(s.maxPlayers) == "number" then
                if smallest then
                    if not pick or s.playing < pick.playing then pick = s end
                elseif s.playing < s.maxPlayers then
                    pick = s
                    break
                end
            end
        end
        if not pick then
            Notifications.error("Server Hop", "No other servers available")
            return false
        end
        if not canTeleport() then return false end
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, player)
        end)
        if not ok then Notifications.error("Server Hop", "Teleport was rejected") end
        return ok
    end
end

-- ============================================================
--  AUTO REJOIN
--  Watches for the disconnect / kick dialog and teleports straight back in.
--  CoreGui is not always reachable from an executor, so every step is guarded
--  and a failure just means the feature quietly does nothing.
-- ============================================================
do
    local rejoined = false

    local function looksLikeDisconnect(inst: Instance): boolean
        local name = string.lower(inst.Name)
        if string.find(name, "errorprompt", 1, true) then return true end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") then
            local text = string.lower(inst.Text)
            if string.find(text, "disconnect", 1, true)
                or string.find(text, "lost connection", 1, true)
                or string.find(text, "kicked", 1, true)
                or string.find(text, "shut down", 1, true) then
                return true
            end
        end
        return false
    end

    local function attemptRejoin(reason: string)
        if rejoined or Flags.Unloading then return end
        rejoined = true
        log("auto-rejoin: " .. reason)
        later(1.5, function()
            pcall(function()
                TeleportService:Teleport(game.PlaceId, player)
            end)
        end)
    end

    pcall(function()
        local core = game:GetService("CoreGui")
        track(core.DescendantAdded:Connect(function(inst)
            if not State.AutoRejoin or rejoined then return end
            if looksLikeDisconnect(inst) then
                attemptRejoin("error dialog appeared")
            end
        end))
    end)

    -- A graceful shutdown fires this instead of showing an error dialog.
    pcall(function()
        track(TeleportService.TeleportInitFailed:Connect(function(_, result)
            if State.AutoRejoin and result ~= Enum.TeleportResult.Success then
                rejoined = false
                attemptRejoin("teleport failed: " .. tostring(result))
            end
        end))
    end)
end

-- ============================================================
--  SETTINGS INDEX
--  Every labelled widget registers itself as it is built, which is how the
--  search box knows what exists and which page owns it. Recording at build
--  time means the index cannot drift out of sync with the actual UI.
-- ============================================================
local Search = {
    map = {} :: { [string]: string },
    building = nil :: string?,
    ready = false,
}

local function indexSetting(label: any)
    if type(label) ~= "string" or #label < 2 then return end
    local page = Search.building
    if not page then return end
    if not Search.map[label] then Search.map[label] = page end
end

-- ============================================================
--  WIDGETS
-- ============================================================
local function sectionTitle(text, y, textSize)
    local holder = new("Frame", {
        Size = UDim2.new(1, -8, 0, 28), Position = UDim2.fromOffset(0, y),
        BackgroundTransparency = 1, Parent = Content,
    })
    local tick = new("Frame", {
        Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(0, 6),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = holder,
    })
    corner(1, tick)
    new("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Font = Theme.FontBold, Text = text,
        TextColor3 = Theme.Text, TextSize = textSize or 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    return holder
end

local function card(y, height)
    local frame = new("Frame", {
        Size = UDim2.new(1, -8, 0, height), Position = UDim2.fromOffset(0, y),
        BackgroundColor3 = Theme.Glass, BorderSizePixel = 0, Parent = Content,
    })
    corner(10, frame)
    local s = stroke(Theme.Stroke, 1, frame)
    trackPage(frame.MouseEnter:Connect(function() tween(s, { Color = Theme.StrokeHi }, 0.15) end))
    trackPage(frame.MouseLeave:Connect(function() tween(s, { Color = Theme.Stroke }, 0.15) end))
    return frame
end

local function toggleRow(parent, labelText, y, default, onChanged)
    indexSetting(labelText)
    local row = new("TextButton", {
        Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, y),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = parent,
    })
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0), BackgroundTransparency = 1,
        Font = Theme.Font, Text = labelText, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local state = default and true or false
    local trackF = new("Frame", {
        Size = UDim2.fromOffset(42, 24), Position = UDim2.new(1, -42, 0.5, -12),
        BackgroundColor3 = state and Theme.Accent or Theme.TrackOff,
        BorderSizePixel = 0, Parent = row,
    })
    corner(12, trackF)
    local trackStroke = stroke(Theme.Stroke, 1, trackF)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Parent = trackF,
    })
    corner(9, knob)

    local function apply()
        local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(trackF, ti, { BackgroundColor3 = state and Theme.Accent or Theme.TrackOff }):Play()
        TweenService:Create(knob, ti, { Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3) }):Play()
        TweenService:Create(trackStroke, ti, { Color = state and Theme.Accent2 or Theme.Stroke }):Play()
    end

    trackPage(row.MouseButton1Click:Connect(function()
        state = not state
        apply()
        if onChanged then onChanged(state) end
    end))
    trackPage(row.MouseEnter:Connect(function() tween(lbl, { TextColor3 = Color3.new(1,1,1) }, 0.12) end))
    trackPage(row.MouseLeave:Connect(function() tween(lbl, { TextColor3 = Theme.Text }, 0.12) end))

    local function setVisual(on)
        state = on and true or false
        apply()
    end
    return row, setVisual
end

local function sliderRow(parent, labelText, y, min, max, default, suffix, onChanged, steppers)
    indexSetting(labelText)
    local row = new("Frame", {
        Size = UDim2.new(1, -32, 0, 54), Position = UDim2.fromOffset(16, y),
        BackgroundTransparency = 1, Parent = parent,
    })
    new("TextLabel", {
        Size = UDim2.new(1, -80, 0, 18), BackgroundTransparency = 1,
        Font = Theme.Font, Text = labelText, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local valueLabel = new("TextLabel", {
        Size = UDim2.fromOffset(80, 18), Position = UDim2.new(1, -80, 0, 0),
        BackgroundTransparency = 1, Font = Theme.FontBold,
        Text = tostring(default) .. (suffix or ""), TextColor3 = Theme.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    local trackF = new("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 40),
        BackgroundColor3 = Theme.TrackOff, BorderSizePixel = 0, Parent = row,
    })
    corner(3, trackF)
    local fill = new("Frame", {
        Size = UDim2.fromScale((default - min) / (max - min), 1),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = trackF,
    })
    corner(3, fill)
    gradient(Theme.Accent, Theme.Accent2, 0, fill)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Parent = trackF,
    })
    corner(8, knob)

    local value = default
    local dragging = false

    local function display()
        local rounded = math.round(value)
        if math.abs(value - rounded) < 0.001 then return tostring(rounded) end
        return string.format("%.2f", value)
    end

    local function apply()
        fill.Size = UDim2.fromScale((value - min) / (max - min), 1)
        knob.Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0)
        valueLabel.Text = display() .. (suffix or "")
        if onChanged then onChanged(value) end
    end

    local function updateFromX(mouseX)
        local absPos = trackF.AbsolutePosition.X
        local absSize = trackF.AbsoluteSize.X
        if absSize <= 0 then return end
        local alpha = math.clamp((mouseX - absPos) / absSize, 0, 1)
        value = math.floor((min + (max - min) * alpha) * 100 + 0.5) / 100
        apply()
    end

    local hitbox = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 30),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row,
    })
    trackPage(hitbox.InputBegan:Connect(function(input)
        if isPointerBegin(input) then
            dragging = true
            updateFromX(input.Position.X)
        end
    end))
    trackPage(UserInputService.InputChanged:Connect(function(input)
        if dragging and isPointerMove(input) and trackF.Parent then updateFromX(input.Position.X) end
    end))
    trackPage(UserInputService.InputEnded:Connect(function(input)
        if isPointerBegin(input) and dragging then dragging = false end
    end))

    if steppers then
        local step = (max - min) >= 200 and 10 or ((max - min) >= 50 and 5 or 1)
        local minus = new("TextButton", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 26),
            BackgroundTransparency = 1, Font = Theme.FontBold, Text = "−",
            TextColor3 = Theme.TextDim, TextSize = 16, AutoButtonColor = false, Parent = row,
        })
        local plus = new("TextButton", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -18, 0, 26),
            BackgroundTransparency = 1, Font = Theme.FontBold, Text = "+",
            TextColor3 = Theme.TextDim, TextSize = 16, AutoButtonColor = false, Parent = row,
        })
        trackPage(minus.MouseButton1Click:Connect(function()
            value = math.clamp(value - step, min, max); apply()
        end))
        trackPage(plus.MouseButton1Click:Connect(function()
            value = math.clamp(value + step, min, max); apply()
        end))
    end

    return row
end

local function actionButton(parent, text, y, onClick)
    indexSetting(text)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(16, y),
        BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
        Font = Theme.FontBold, Text = text, TextColor3 = Theme.Text,
        TextSize = 12, AutoButtonColor = false, Parent = parent,
    })
    corner(8, btn)
    stroke(Theme.Stroke, 1, btn)
    trackPage(btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.Glass }, 0.1) end))
    trackPage(btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.GlassHi }, 0.1) end))
    trackPage(btn.MouseButton1Click:Connect(onClick))
    return btn
end

local function textboxRow(parent, labelText, y, placeholder, onSubmit)
    indexSetting(labelText)
    local row = new("Frame", {
        Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, y),
        BackgroundTransparency = 1, Parent = parent,
    })
    new("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1,
        Font = Theme.Font, Text = labelText, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local box = new("TextBox", {
        Size = UDim2.new(0.6, 0, 0, 28), Position = UDim2.new(0.4, 0, 0.5, -14),
        BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
        Font = Theme.Font, Text = "", PlaceholderText = placeholder,
        PlaceholderColor3 = Theme.TextFaint, TextColor3 = Theme.Text,
        TextSize = 12, ClearTextOnFocus = false, Parent = row,
    })
    corner(7, box)
    stroke(Theme.Stroke, 1, box)
    pad(6, box)
    if onSubmit then
        track(box.FocusLost:Connect(function() onSubmit(box.Text) end))
    end
    return row, box
end

local function cycleRow(parent, labelText, y, options, getIndex, setIndex)
    indexSetting(labelText)
    local row = new("Frame", {
        Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, y),
        BackgroundTransparency = 1, Parent = parent,
    })
    new("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1,
        Font = Theme.Font, Text = labelText, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local valueBtn = new("TextButton", {
        Size = UDim2.new(0.5, 0, 0, 28), Position = UDim2.new(0.5, 0, 0.5, -14),
        BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
        Font = Theme.Font, Text = "", TextColor3 = Theme.Text,
        TextSize = 12, AutoButtonColor = false, Parent = row,
    })
    corner(7, valueBtn)
    stroke(Theme.Stroke, 1, valueBtn)
    local function refresh()
        local i = getIndex()
        valueBtn.Text = options[math.clamp(i, 1, #options)] .. "  ▾"
    end
    refresh()
    trackPage(valueBtn.MouseButton1Click:Connect(function()
        local i = getIndex() + 1
        if i > #options then i = 1 end
        setIndex(i)
        refresh()
    end))
    return row
end

local function keybindRow(parent, labelText, y, getKey, setKey)
    indexSetting(labelText)
    local row = new("Frame", {
        Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, y),
        BackgroundTransparency = 1, Parent = parent,
    })
    new("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1,
        Font = Theme.Font, Text = labelText, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local btn = new("TextButton", {
        Size = UDim2.new(0.5, 0, 0, 28), Position = UDim2.new(0.5, 0, 0.5, -14),
        BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
        Font = Theme.Font, Text = "", TextColor3 = Theme.Text,
        TextSize = 12, AutoButtonColor = false, Parent = row,
    })
    corner(7, btn)
    stroke(Theme.Stroke, 1, btn)

    local capturing = false
    local function refresh()
        btn.Text = capturing and "..." or (tostring(getKey()):gsub("^Enum%.%a+%.", ""))
    end
    refresh()

    -- The click that opened capture must not immediately bind MouseButton1.
    local openedAt = 0
    trackPage(btn.MouseButton1Click:Connect(function()
        if capturing then return end
        capturing = true
        keybindCapturing = true
        openedAt = os.clock()
        refresh()
    end))
    trackPage(UserInputService.InputBegan:Connect(function(input, gpe)
        if not capturing then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            capturing = false
            keybindCapturing = false
            refresh()
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if gpe then return end
            setKey(input.KeyCode)
            capturing = false
            keybindCapturing = false
            refresh()
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            if os.clock() - openedAt < 0.2 then return end
            setKey(input.UserInputType)
            capturing = false
            keybindCapturing = false
            refresh()
        end
    end))
    return row
end

local function dropdownRow(parent, labelText, y, options, getSelected, setSelected, single)
    indexSetting(labelText)
    local row = new("Frame", {
        Size = UDim2.new(1, -32, 0, 44), Position = UDim2.fromOffset(16, y),
        BackgroundTransparency = 1, Parent = parent,
    })
    new("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1,
        Font = Theme.Font, Text = labelText, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local button = new("TextButton", {
        Size = UDim2.new(0.5, 0, 0, 32), Position = UDim2.new(0.5, 0, 0.5, -16),
        BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
        Font = Theme.Font, Text = "", AutoButtonColor = false, Parent = row,
    })
    corner(8, button)
    stroke(Theme.Stroke, 1, button)
    local buttonLabel = new("TextLabel", {
        Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Font = Theme.Font, Text = "",
        TextColor3 = Theme.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = button,
    })
    new("TextLabel", {
        Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -26, 0.5, -10),
        BackgroundTransparency = 1, Font = Theme.FontBold, Text = "▾",
        TextColor3 = Theme.TextDim, TextSize = 14, Parent = button,
    })

    local rowStep = 28
    local popupH = math.min(#options, 8) * rowStep + 12
    local popup = new("ScrollingFrame", {
        Size = UDim2.fromOffset(220, popupH),
        CanvasSize = UDim2.fromOffset(0, #options * rowStep + 12),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Accent,
        Visible = false, ZIndex = 50, Parent = ScreenGui,
    })
    holdDebris(popup)
    corner(10, popup)
    stroke(Theme.StrokeHi, 1, popup)

    local optChecks = {}

    local function refreshLabel()
        if single then
            buttonLabel.Text = tostring(getSelected())
        else
            local sel = {}
            for k, v in getSelected() do if v then table.insert(sel, k) end end
            table.sort(sel)
            buttonLabel.Text = #sel > 0 and table.concat(sel, ", ") or "None"
        end
        for opt, chk in optChecks do
            local on = if single then getSelected() == opt else getSelected()[opt] and true or false
            chk.Text = on and "✓" or ""
        end
    end

    for i, opt in options do
        local optRow = new("TextButton", {
            Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 6 + (i - 1) * rowStep),
            BackgroundColor3 = Theme.Glass, BackgroundTransparency = 0.3,
            BorderSizePixel = 0, Font = Theme.Font, Text = opt,
            TextColor3 = Theme.Text, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false, ZIndex = 51, Parent = popup,
        })
        corner(6, optRow)
        pad(6, optRow)
        local check = new("TextLabel", {
            Size = UDim2.fromOffset(20, 26), Position = UDim2.new(1, -26, 0, 0),
            BackgroundTransparency = 1, Font = Theme.FontBold,
            Text = "", TextColor3 = Theme.Success,
            TextSize = 14, ZIndex = 52, Parent = optRow,
        })
        optChecks[opt] = check
        trackPage(optRow.MouseEnter:Connect(function()
            tween(optRow, { BackgroundColor3 = Theme.GlassHi, BackgroundTransparency = 0 }, 0.1)
        end))
        trackPage(optRow.MouseLeave:Connect(function()
            tween(optRow, { BackgroundColor3 = Theme.Glass, BackgroundTransparency = 0.3 }, 0.1)
        end))
        trackPage(optRow.MouseButton1Click:Connect(function()
            if single then
                setSelected(opt)
                popup.Visible = false
            else
                local sel = getSelected()
                sel[opt] = not sel[opt]
                setSelected(sel)
            end
            refreshLabel()
        end))
    end

    trackPage(button.MouseButton1Click:Connect(function()
        if popup.Visible then popup.Visible = false; return end
        local absPos = button.AbsolutePosition
        local absSize = button.AbsoluteSize
        local py = absPos.Y + absSize.Y + 4
        local cam = workspace.CurrentCamera
        local viewH = cam and cam.ViewportSize.Y or (py + popupH)
        if py + popupH > viewH - 8 then
            py = math.max(8, absPos.Y - popupH - 4)
        end
        popup.Position = UDim2.fromOffset(absPos.X, py)
        popup.CanvasPosition = Vector2.zero
        popup.Visible = true
    end))

    trackPage(UserInputService.InputBegan:Connect(function(input)
        if not popup.Parent or not popup.Visible then return end
        if not isPointerBegin(input) then return end
        local mx, my = input.Position.X, input.Position.Y
        local pp, ps = popup.AbsolutePosition, popup.AbsoluteSize
        local bp, bs = button.AbsolutePosition, button.AbsoluteSize
        local insidePopup  = mx >= pp.X and mx <= pp.X + ps.X and my >= pp.Y and my <= pp.Y + ps.Y
        local insideButton = mx >= bp.X and mx <= bp.X + bs.X and my >= bp.Y and my <= bp.Y + bs.Y
        if not insidePopup and not insideButton then popup.Visible = false end
    end))

    refreshLabel()
    return row
end

-- ============================================================
--  RESOURCE SCANNER
-- ============================================================
local ResourceScanner = {}

function ResourceScanner.folder()
    return workspace:FindFirstChild("Resources")
end

function ResourceScanner.resolve(obj: Instance): (Instance?, string?)
    local folder = ResourceScanner.folder()
    local cur: Instance? = obj
    local hops = 0
    -- Innermost named node, not a type-folder that would collapse every
    -- Copper/Rock in a vein into one ESP/farm target.
    while cur and hops < 8 do
        if folder and cur == folder then break end
        if RESOURCE_NAMES[cur.Name] and (cur:IsA("BasePart") or cur:IsA("Model")) then
            return cur, cur.Name
        end
        cur = cur.Parent
        hops += 1
    end
    return nil, nil
end

function ResourceScanner.typeOf(obj)
    local _, kind = ResourceScanner.resolve(obj)
    return kind
end

local function scanPos(obj: Instance): Vector3?
    if obj:IsA("BasePart") then
        return Vector3.new(obj.Position.X, obj.Position.Y - obj.Size.Y * 0.5, obj.Position.Z)
    end
    if obj:IsA("Model") then
        local ok, cf, size = pcall(function()
            return obj:GetBoundingBox()
        end)
        if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
            return Vector3.new(cf.Position.X, cf.Position.Y - size.Y * 0.5, cf.Position.Z)
        end
        local part = obj:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return Vector3.new(part.Position.X, part.Position.Y - part.Size.Y * 0.5, part.Position.Z)
        end
    end
    return nil
end

-- One-time / incremental index. Scanning 10k Resources every tick is what
-- froze the game while Auto Gather was on.
local farmStore = {
    items = {} :: { { inst: Instance, kind: string, pos: Vector3, dead: boolean?, cell: number? } },
    byInst = {} :: { [Instance]: any },
    -- Flat spatial hash: cell key -> list of records. Lets a radius query touch
    -- a handful of buckets instead of all 10k nodes, which is what the ESP and
    -- the farm both do several times a second.
    grid = {} :: { [number]: { any } },
    built = false,
    building = false,
    sweepAt = 1,
    lastSnap = 0,
    snap = {} :: { Instance },
    lastDiscover = 0,
    lastCompact = 0,
}

-- Cell size trades query precision against bucket count; 64 studs is roughly
-- one tree cluster. Bias/span pack a 2D cell coordinate into one integer key.
local Grid = { CELL = 64, BIAS = 4096, SPAN = 8192 }

function Grid.key(cx: number, cz: number): number
    return (cx + Grid.BIAS) * Grid.SPAN + (cz + Grid.BIAS)
end

function Grid.cellOf(pos: Vector3): number
    return Grid.key(math.floor(pos.X / Grid.CELL), math.floor(pos.Z / Grid.CELL))
end

function Grid.insert(rec: any)
    local key = Grid.cellOf(rec.pos)
    rec.cell = key
    local bucket = farmStore.grid[key]
    if not bucket then
        bucket = {}
        farmStore.grid[key] = bucket
    end
    table.insert(bucket, rec)
end

function Grid.remove(rec: any)
    local key = rec.cell
    if not key then return end
    local bucket = farmStore.grid[key]
    if not bucket then return end
    for i = #bucket, 1, -1 do
        if bucket[i] == rec then
            table.remove(bucket, i)
            break
        end
    end
    if #bucket == 0 then farmStore.grid[key] = nil end
    rec.cell = nil
end

function ResourceScanner.consider(obj: Instance)
    local inst, kind = ResourceScanner.resolve(obj)
    if not inst or not kind then return end
    local pos = scanPos(inst)
    if not pos then return end
    local rec = farmStore.byInst[inst]
    if rec then
        rec.pos = pos
        rec.kind = kind
        rec.dead = nil
        -- Nodes rarely move, so only re-bucket when they actually cross a cell.
        if rec.cell ~= Grid.cellOf(pos) then
            Grid.remove(rec)
            Grid.insert(rec)
        end
        return
    end
    rec = { inst = inst, kind = kind, pos = pos }
    farmStore.byInst[inst] = rec
    table.insert(farmStore.items, rec)
    Grid.insert(rec)
end

function ResourceScanner.drop(obj: Instance)
    local rec = farmStore.byInst[obj]
    if not rec then return end
    farmStore.byInst[obj] = nil
    rec.dead = true
    Grid.remove(rec)
end

function ResourceScanner.cached(): any
    return farmStore.items
end

function ResourceScanner.count(): number
    return #farmStore.items
end

-- The only sanctioned way to move a record. Writing rec.pos directly would
-- leave it filed under its old cell, where no query would ever find it again.
function ResourceScanner.reposition(rec: any, pos: Vector3)
    rec.pos = pos
    if rec.cell ~= Grid.cellOf(pos) then
        Grid.remove(rec)
        Grid.insert(rec)
    end
end

-- Visits every record whose cell overlaps the circle. Callers still range-check
-- precisely; this only narrows the candidate set.
function ResourceScanner.queryRadius(pos: Vector3, radius: number, visit: (any) -> ())
    local r = math.max(radius, 1)
    local minX = math.floor((pos.X - r) / Grid.CELL)
    local maxX = math.floor((pos.X + r) / Grid.CELL)
    local minZ = math.floor((pos.Z - r) / Grid.CELL)
    local maxZ = math.floor((pos.Z + r) / Grid.CELL)
    local cells = (maxX - minX + 1) * (maxZ - minZ + 1)
    -- Past a few thousand cells the bucket walk costs more than the flat list.
    if cells > 3000 then
        for _, e in farmStore.items do
            if e and not e.dead then visit(e) end
        end
        return
    end
    local grid = farmStore.grid
    for cx = minX, maxX do
        for cz = minZ, maxZ do
            local bucket = grid[Grid.key(cx, cz)]
            if bucket then
                for i = #bucket, 1, -1 do
                    local e = bucket[i]
                    if e and not e.dead then visit(e) end
                end
            end
        end
    end
end

function ResourceScanner.compact()
    local items = farmStore.items
    local w = 1
    for i = 1, #items do
        local e = items[i]
        if e and not e.dead and e.inst.Parent then
            items[w] = e
            w += 1
        elseif e then
            farmStore.byInst[e.inst] = nil
            Grid.remove(e)
        end
    end
    for i = w, #items do
        items[i] = nil
    end
end

function ResourceScanner.reset()
    table.clear(farmStore.items)
    table.clear(farmStore.byInst)
    table.clear(farmStore.snap)
    table.clear(farmStore.grid)
    farmStore.built = false
    farmStore.building = false
    farmStore.sweepAt = 1
    farmStore.lastSnap = 0
end

function ResourceScanner.ingest(pos: Vector3, radius: number)
    local folder = ResourceScanner.folder()
    if not folder then return end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { folder }
    params.MaxParts = 300
    local ok, parts = pcall(function()
        return workspace:GetPartBoundsInRadius(pos, radius, params)
    end)
    if not ok or not parts then return end
    for _, p in parts do
        ResourceScanner.consider(p)
    end
end

function ResourceScanner.pulse(budget: number)
    local folder = ResourceScanner.folder()
    if not folder then return end
    local now = os.clock()
    if now - farmStore.lastSnap > 1.25 or #farmStore.snap == 0 then
        farmStore.snap = folder:GetChildren()
        farmStore.lastSnap = now
        if farmStore.sweepAt > #farmStore.snap then
            farmStore.sweepAt = 1
        end
    end
    local children = farmStore.snap
    local n = #children
    if n == 0 then return end
    local steps = math.min(budget, n)
    for _ = 1, steps do
        if farmStore.sweepAt > n then farmStore.sweepAt = 1 end
        local obj = children[farmStore.sweepAt]
        farmStore.sweepAt += 1
        if obj then
            ResourceScanner.consider(obj)
            if not RESOURCE_NAMES[obj.Name] then
                local kids = obj:GetChildren()
                for i = 1, math.min(#kids, 6) do
                    ResourceScanner.consider(kids[i])
                end
            end
        end
    end
end

function ResourceScanner.discover()
    if Flags.Unloading then return end
    local now = os.clock()
    if now - farmStore.lastDiscover < 0.2 then return end
    farmStore.lastDiscover = now
    ResourceScanner.pulse(220)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        ResourceScanner.ingest(root.Position, 420)
    end
    if now - farmStore.lastCompact > 4 then
        farmStore.lastCompact = now
        ResourceScanner.compact()
    end
end

function ResourceScanner.buildCache(folder: Instance)
    if farmStore.building then return end
    farmStore.building = true
    task.spawn(function()
        local children = folder:GetChildren()
        for i, obj in children do
            if Flags.Unloading then return end
            if ResourceScanner.typeOf(obj) then
                ResourceScanner.consider(obj)
            else
                for _, child in obj:GetChildren() do
                    ResourceScanner.consider(child)
                end
            end
            if i % 350 == 0 then task.wait() end
        end
        farmStore.built = true
        farmStore.building = false
        log("Resource cache ready (" .. #farmStore.items .. " nodes)")
    end)
end

function ResourceScanner.list(folder: Instance?)
    local list = {}
    if not folder then return list end
    local function consider(obj: Instance)
        local t = ResourceScanner.typeOf(obj)
        if t then table.insert(list, { inst = obj, kind = t }) end
    end
    for _, obj in folder:GetChildren() do
        if ResourceScanner.typeOf(obj) then
            consider(obj)
        else
            for _, child in obj:GetChildren() do
                consider(child)
            end
        end
    end
    return list
end

function ResourceScanner.scan()
    local buckets = {}
    if #farmStore.items > 0 then
        for _, entry in farmStore.items do
            if entry.dead or not entry.inst.Parent then continue end
            if not buckets[entry.kind] then buckets[entry.kind] = {} end
            table.insert(buckets[entry.kind], entry.inst)
        end
        return buckets
    end
    for _, entry in ResourceScanner.list(ResourceScanner.folder()) do
        if not buckets[entry.kind] then buckets[entry.kind] = {} end
        table.insert(buckets[entry.kind], entry.inst)
    end
    return buckets
end

function ResourceScanner.watch(callback)
    local conns = {}
    local function bind(folder)
        local queued = false
        local function ping()
            if queued then return end
            queued = true
            later(0.4, function()
                queued = false
                if not Flags.Unloading then callback() end
            end)
        end
        table.insert(conns, folder.DescendantAdded:Connect(function(obj)
            ResourceScanner.consider(obj)
            ping()
        end))
        table.insert(conns, folder.DescendantRemoving:Connect(function(obj)
            if farmStore.byInst[obj] then
                ResourceScanner.drop(obj)
                ping()
            end
        end))
    end
    local folder = ResourceScanner.folder()
    if folder then
        bind(folder)
    else
        local watchConn
        watchConn = workspace.ChildAdded:Connect(function(child)
            if child.Name ~= "Resources" then return end
            if watchConn then watchConn:Disconnect(); watchConn = nil end
            bind(child)
            callback()
        end)
        table.insert(conns, watchConn)
    end
    return function()
        for _, c in conns do pcall(function() c:Disconnect() end) end
        table.clear(conns)
    end
end

    Scheduler.add("discover", "logic", 0.2, function()
        if Flags.Unloading then return end
        if State.ResourceESP or State.AutoGather or State.TeleportGather
            or State.GatherAround or State.LegitMode then
            ResourceScanner.discover()
        end
    end)

-- ============================================================
--  PAGES
-- ============================================================
local navButtons = {}
local currentPage = nil
local Pages = {}
local resourceWatcherDisconnect = nil
local resourcesPageSerial = 0

local function clearContent()
    clearPageScope()
    keybindCapturing = false
    table.clear(toggleSync)
    State._statusLabel = nil
    State._statusDot = nil
    State._debugLabel = nil
    for _, c in Content:GetChildren() do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    Content.CanvasPosition = Vector2.new(0, 0)
end

local function selectNav(name)
    if resourceWatcherDisconnect then
        resourceWatcherDisconnect()
        resourceWatcherDisconnect = nil
    end
    for n, btn in navButtons do
        local active = (n == name)
        tween(btn, {
            BackgroundTransparency = active and 0 or 1,
            BackgroundColor3 = active and Theme.GlassHi or Theme.Glass,
            TextColor3 = active and Theme.Text or Theme.TextDim,
        }, 0.15)
        if btn:FindFirstChild("AccentBar") then btn.AccentBar.Visible = active end
    end
    currentPage = name
end

local function navigateTo(name: string)
    if not Pages[name] then return end
    local prev = currentPage
    local scope = Hub.Pages
    if prev and prev ~= name and scope and scope.close then
        pcall(function() scope.close(prev) end)
    end
    selectNav(name)
    Hub.Flags.ActivePage = name
    if scope and scope.open then
        pcall(function() scope.open(name) end)
    end
    Search.building = name
    local ok, err = pcall(Pages[name])
    Search.building = nil
    if not ok then log("page '" .. name .. "' failed: " .. tostring(err)) end
end

-- Lets Config.applyTable refresh every widget on screen after it rewrites
-- State, instead of leaving stale toggle and slider positions behind.
rerenderCurrentPage = function()
    local name = currentPage
    if not name then return end
    local scroll = Content.CanvasPosition
    navigateTo(name)
    Content.CanvasPosition = scroll
end
Hub.rerenderCurrentPage = function()
    if rerenderCurrentPage then
        rerenderCurrentPage()
    end
end

-- Builds the search index by rendering every page once into the same Content
-- frame, then returning to where the user was. Runs shortly after injection so
-- the first page the user sees is not blocked by it.
local function buildSettingsIndex()
    if Search.ready or Flags.Unloading then return end
    Search.ready = true
    local restore = currentPage
    for name in Pages do
        if name ~= restore then
            selectNav(name)
            Search.building = name
            pcall(Pages[name])
            Search.building = nil
        end
    end
    if restore then navigateTo(restore) end
end

-- === Page: Auto Gather ===
Pages["Auto Gather"] = function()
    clearContent()
    local y = 0

    sectionTitle("Modes", y); y += 34
    local c1 = card(y, 282); y += 292
    local _, syncGather = toggleRow(c1, "Auto Gather  (teleport to each listed node and mine)", 14, State.AutoGather, function(v)
        setFeature("AutoGather", v, true)
    end)
    toggleSync.AutoGather = syncGather
    toggleRow(c1, "Teleport Gather  (snap to each, mine all in range)", 52, State.TeleportGather, function(v)
        setFeature("TeleportGather", v, true)
    end)
    toggleRow(c1, "Gather Around  (mine nearby while you walk)", 90, State.GatherAround, function(v)
        setFeature("GatherAround", v, true)
    end)
    toggleRow(c1, "Legit Gather  (walk up and farm like a player)", 128, State.LegitMode, function(v)
        setFeature("LegitMode", v, true)
    end)
    sliderRow(c1, "Hit Delay", 166, 0.05, 3, State.HitGap, "s", function(v)
        State.HitGap = v
        State.LegitHitDelay = math.clamp(v, 0.4, 5)
    end)
    keybindRow(c1, "Auto Gather Keybind", 224, function() return State.GatherKey end, function(k) State.GatherKey = k end)

    sectionTitle("Selection", y); y += 34
    local c2 = card(y, 100); y += 110
    dropdownRow(c2, "Resources to Collect", 8, RESOURCE_LIST,
        function() return State.ResourcesToCollect end,
        function(sel) State.ResourcesToCollect = sel end)
    actionButton(c2, "Select All Types", 56, function()
        for _, name in RESOURCE_LIST do State.ResourcesToCollect[name] = true end
        Notifications.success("Selection", "All resource types on")
        Pages["Auto Gather"]()
    end)

    sectionTitle("Tuning", y); y += 34
    local cT = card(y, 220); y += 230
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 28), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Hit Delay is the pause between swings. Overpower stacks extra hits on the same tick after that pause — it does not spam faster than the delay.",
        TextColor3 = Theme.TextFaint, TextSize = 11, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cT,
    })
    sliderRow(cT, "Gather Around / Mass Range", 40, 10, 120, State.HitRange, " studs", function(v) State.HitRange = v end)
    sliderRow(cT, "Legit Reach", 98, 4, 20, State.LegitReach, " studs", function(v) State.LegitReach = v end)
    sliderRow(cT, "Hit Delay (same as Modes)", 156, 0.05, 3, State.HitGap, "s", function(v)
        State.HitGap = v
        State.LegitHitDelay = math.clamp(v, 0.4, 5)
    end)

    sectionTitle("Overpower", y); y += 34
    local cO = card(y, 258); y += 268
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Spoof Best Tool sends a shop catalog pick or axe you do not own (Flint, Bronze, Iron…). Trees get an axe, rocks get a pick. One unique payload set per swing.",
        TextColor3 = Theme.TextFaint, TextSize = 11, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cO,
    })
    toggleRow(cO, "Overpower  (same-tick extra hits + power spoof)", 44, State.Overpower, function(v)
        State.Overpower = v
        if not v then
            restoreGatherPower()
        elseif farmActive() then
            applyGatherPower()
        end
    end)
    toggleRow(cO, "Spoof Best Tool  (catalog Flint/Bronze/Iron, no purchase)", 82, State.SpoofPickaxe, function(v)
        State.SpoofPickaxe = v
    end)
    sliderRow(cO, "Hits per swing", 120, 1, 8, State.HitsPerSwing, "", function(v)
        State.HitsPerSwing = math.floor(v + 0.5)
    end)
    sliderRow(cO, "Power Scale", 178, 1, 10, State.PowerScale, "x", function(v)
        State.PowerScale = v
        if State.Overpower and farmActive() then
            applyGatherPower()
        end
    end)

    sectionTitle("Stealth Profile", y); y += 34
    local cS = card(y, 514); y += 524
    local profileNote = new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = Stealth.notes[State.StealthProfile] or "",
        TextColor3 = Theme.TextFaint, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cS,
    })
    cycleRow(cS, "Profile", 44, Stealth.order, function()
        for i, name in Stealth.order do
            if name == State.StealthProfile then return i end
        end
        return 2
    end, function(i)
        local name = Stealth.order[i]
        Stealth.apply(name, true)
        profileNote.Text = Stealth.notes[name] or ""
        -- The preset rewrites half the sliders below, so redraw them.
        task.defer(function() navigateTo("Auto Gather") end)
    end)
    -- Individual overrides. Touching one of these leaves the profile label as
    -- it was, which is honest: the profile is a starting point, not a lock.
    toggleRow(cS, "Glide instead of teleport", 82, State.SoftTeleport, function(v)
        State.SoftTeleport = v
    end)
    toggleRow(cS, "Hop long distances in stages", 120, State.TravelHops, function(v)
        State.TravelHops = v
    end)
    toggleRow(cS, "Anchor to node while mining", 158, State.UsePin, function(v)
        State.UsePin = v
        if not v then
            Notifications.warn("Pin off", "Position is re-asserted each swing instead")
        end
    end)
    toggleRow(cS, "Randomise landing spot", 196, State.LandingJitter, function(v)
        State.LandingJitter = v
    end)
    toggleRow(cS, "Clamp velocity", 234, State.VelocityClamp, function(v)
        State.VelocityClamp = v
    end)
    sliderRow(cS, "Max anchor hold", 272, 0, 60, State.PinMax, "s", function(v) State.PinMax = v end)
    sliderRow(cS, "Glide Speed", 330, 40, 800, State.SoftTeleportSpeed, " studs/s", function(v)
        State.SoftTeleportSpeed = v
    end)
    sliderRow(cS, "Hop Distance", 388, 40, 600, State.HopDistance, " studs", function(v)
        State.HopDistance = v
    end)
    sliderRow(cS, "Velocity Cap", 446, 16, 500, State.MaxVelocity, " studs/s", function(v)
        State.MaxVelocity = v
    end)

    sectionTitle("Resource Priority", y); y += 34
    local cP = card(y, 12 + #RESOURCE_LIST * 58 + 62)
    y += 12 + #RESOURCE_LIST * 58 + 72
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Higher priority buys a longer detour. At the weight below, one point is worth that many studs of travel.",
        TextColor3 = Theme.TextFaint, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cP,
    })
    sliderRow(cP, "Priority Weight", 44, 0, 200, State.PriorityWeight, " studs/pt", function(v)
        State.PriorityWeight = v
    end)
    for i, name in RESOURCE_LIST do
        local current = State.ResourcePriority[name]
        if type(current) ~= "number" then
            current = 0
            State.ResourcePriority[name] = 0
        end
        sliderRow(cP, name, 102 + (i - 1) * 58, 0, 10, current, "", function(v)
            State.ResourcePriority[name] = v
        end)
    end

    sectionTitle("Market (Auto-Sell)", y); y += 34
    local cMK = card(y, 260); y += 270
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "The gold counter is driven by the Market remote. Sell All fires each argument shape at 0.7s and shows which one moves gold — lock it in when you see it.",
        TextColor3 = Theme.TextDim, TextSize = 11, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cMK,
    })

    toggleRow(cMK, "Auto Sell After Gather", 46, State.AutoSell, function(v)
        State.AutoSell = v
        Notifications.info("Auto Sell", v and "Enabled" or "Disabled")
    end)

    cycleRow(cMK, "Sell Arg Style", 84, SELL_STYLES, function()
        for i, name in SELL_STYLES do
            if name == State.SellArgStyle then return i end
        end
        return 1
    end, function(i)
        State.SellArgStyle = SELL_STYLES[i]
        Notifications.info("Sell Style", State.SellArgStyle)
    end)

    actionButton(cMK, "Sell All Resources Now", 122, function()
        local folder = ReplicatedStorage:FindFirstChild("Remotes")
        local market = folder and folder:FindFirstChild("Market")
        if not market or not market:IsA("RemoteEvent") then
            Notifications.error("Market", "Market remote not found")
            return
        end
        task.spawn(function()
            local ls = player:FindFirstChild("leaderstats")
            local function snapshot()
                local snap = {}
                if ls then
                    for _, s in ls:GetChildren() do
                        snap[s.Name] = s.Value
                    end
                end
                return snap
            end
            local before = snapshot()
            for i, style in SELL_STYLES do
                if Flags.Unloading then return end
                log(string.format("Sell test [%d] style=%s", i, style))
                pcall(function()
                    local ok = fireSell(market, style, "Tree")
                    if not ok then
                        log(string.format("  [%d] no args to send", i))
                    end
                end)
                task.wait(0.7)
                local after = snapshot()
                local deltas = {}
                for name, val in after do
                    if before[name] ~= val then
                        table.insert(deltas, string.format("%s: %s → %s", name, tostring(before[name]), tostring(val)))
                    end
                end
                if #deltas > 0 then
                    State.SellArgStyle = style
                    log(string.format("  HIT: %s", table.concat(deltas, ", ")))
                    Notifications.success("Market", style .. " → " .. table.concat(deltas, ", "))
                    return
                else
                    log(string.format("  [%d] no change", i))
                end
                before = after
            end
            Notifications.warn("Market", "No shape moved gold — see debug log")
        end)
    end)

    actionButton(cMK, "Print Leaderstats", 160, function()
        local ls = player:FindFirstChild("leaderstats")
        if not ls then
            log("Leaderstats: (none)")
            Notifications.warn("Leaderstats", "No leaderstats on player")
            return
        end
        local parts = {}
        for _, s in ls:GetChildren() do
            table.insert(parts, string.format("%s=%s", s.Name, tostring(s.Value)))
        end
        log("Leaderstats: " .. table.concat(parts, ", "))
        Notifications.info("Leaderstats", table.concat(parts, ", "))
    end)
    cMK.Size = UDim2.new(1, -8, 0, 12 + 4 * 38 + 40)

    sectionTitle("Status", y); y += 34
    local c5 = card(y, 110)
    toggleRow(c5, "Status Panel", 10, State.StatusEnabled, function(v) State.StatusEnabled = v end)
    local dot = new("Frame", {
        Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(24, 56),
        BackgroundColor3 = Theme.Danger, BorderSizePixel = 0, Parent = c5,
    })
    corner(5, dot)
    State._statusDot = dot
    local statusLabel = new("TextLabel", {
        Size = UDim2.new(1, -60, 0, 40), Position = UDim2.fromOffset(44, 50),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Idle\nTarget —  ·  Distance —", TextColor3 = Theme.TextDim,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = c5,
    })
    State._statusLabel = statusLabel
    y += 120

    sectionTitle("Debug Log", y); y += 34
    local c6 = card(y, 140); y += 150
    local debugLabel = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, -24), Position = UDim2.fromOffset(16, 12),
        BackgroundTransparency = 1, Font = Enum.Font.Code,
        Text = "(no activity yet)", TextColor3 = Theme.TextDim,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = c6,
    })
    State._debugLabel = debugLabel
    if #State._debugLog > 0 then debugLabel.Text = table.concat(State._debugLog, "\n") end

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)
end

-- === Page: Visuals ===
Pages["Visuals"] = function()
    clearContent()
    local y = 0

    sectionTitle("Player ESP", y); y += 30
    local c1 = card(y, 536); y += 546
    toggleRow(c1, "Player ESP", 12, State.PlayerESP, function(v)
        setFeature("PlayerESP", v, true)
    end)
    toggleRow(c1, "Box", 50, State.PlayerBox, function(v) State.PlayerBox = v end)
    toggleRow(c1, "Skeleton", 88, State.PlayerSkeleton, function(v) State.PlayerSkeleton = v end)
    toggleRow(c1, "Chams", 126, State.PlayerChams, function(v) State.PlayerChams = v end)
    toggleRow(c1, "Name", 164, State.PlayerName, function(v) State.PlayerName = v end)
    toggleRow(c1, "Distance", 202, State.PlayerDistance, function(v) State.PlayerDistance = v end)
    toggleRow(c1, "Health Bar", 240, State.PlayerHealth, function(v) State.PlayerHealth = v end)
    toggleRow(c1, "Health Text", 278, State.PlayerHealthText, function(v) State.PlayerHealthText = v end)
    toggleRow(c1, "Deaths", 316, State.PlayerDeaths, function(v) State.PlayerDeaths = v end)
    toggleRow(c1, "Gold", 354, State.PlayerGold, function(v) State.PlayerGold = v end)
    toggleRow(c1, "Job", 392, State.PlayerJob, function(v) State.PlayerJob = v end)
    toggleRow(c1, "Age", 430, State.PlayerAge, function(v) State.PlayerAge = v end)
    sliderRow(c1, "ESP Max Distance", 468, 50, 2000, State.PlayerMaxDist, " studs", function(v) State.PlayerMaxDist = v end)

    sectionTitle("Resource ESP", y); y += 30
    local c2 = card(y, 430); y += 440
    toggleRow(c2, "Resource ESP", 12, State.ResourceESP, function(v)
        setFeature("ResourceESP", v, true)
    end)
    toggleRow(c2, "Box", 50, State.ResourceBox, function(v) State.ResourceBox = v end)
    toggleRow(c2, "Name", 88, State.ResourceName, function(v) State.ResourceName = v end)
    toggleRow(c2, "Distance", 126, State.ResourceDistance, function(v) State.ResourceDistance = v end)
    toggleRow(c2, "Health Bar", 164, State.ResourceHealth, function(v) State.ResourceHealth = v end)
    toggleRow(c2, "Health Text", 202, State.ResourceHealthText, function(v) State.ResourceHealthText = v end)
    dropdownRow(c2, "Resources", 240, RESOURCE_LIST,
        function() return State.ResourceTypeFilter end,
        function(sel) State.ResourceTypeFilter = sel end)
    sliderRow(c2, "Max Distance", 298, 25, 1000, State.ResourceMaxDist, " studs", function(v) State.ResourceMaxDist = v end)
    sliderRow(c2, "Max Tracked At Once", 356, 5, 200, State.ResourceLimit, "", function(v) State.ResourceLimit = v end)

    sectionTitle("Lighting", y); y += 30
    local c3 = card(y, 130); y += 140
    local _, syncFB = toggleRow(c3, "Fullbright", 14, State.Fullbright, function(v)
        setFeature("Fullbright", v)
        Notifications.info("Fullbright", v and "Enabled" or "Disabled")
    end)
    toggleSync.Fullbright = syncFB
    toggleRow(c3, "No Shadows", 52, State.NoShadows, function(v)
        setFeature("NoShadows", v)
    end)

    local _, syncXRay = toggleRow(c3, "X-Ray (transparent world)", 90, State.XRay, function(v)
        setFeature("XRay", v)
    end)
    toggleSync.XRay = syncXRay

    sectionTitle("Camera", y); y += 30
    local c4 = card(y, 130); y += 140
    sliderRow(c4, "Field Of View", 8, 30, 120, State.FOV, "°", function(v)
        State.FOV = v
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = v end
    end, true)
    sliderRow(c4, "Camera Zoom", 66, 10, 500, State.CamZoom, " studs", function(v)
        State.CamZoom = v
        player.CameraMaxZoomDistance = v
    end, true)

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)
end

-- === Page: Local Player ===
Pages["Local Player"] = function()
    clearContent()
    local y = 0

    sectionTitle("General", y); y += 30
    local c1 = card(y, 344); y += 354
    toggleRow(c1, "Anti AFK", 12, State.AntiAFK, function(v) setFeature("AntiAFK", v) end)

    local _, syncInfJump = toggleRow(c1, "Infinite Jump", 50, State.InfiniteJump, function(v)
        setFeature("InfiniteJump", v)
    end)
    toggleSync.InfiniteJump = syncInfJump
    keybindRow(c1, "Inf Jump Keybind", 88, function() return State.InfJumpKey end, function(k) State.InfJumpKey = k end)

    local _, syncFly = toggleRow(c1, "Fly", 126, State.Fly, function(v)
        setFeature("Fly", v)
    end)
    toggleSync.Fly = syncFly
    keybindRow(c1, "Fly Keybind", 164, function() return State.FlyKey end, function(k) State.FlyKey = k end)
    sliderRow(c1, "Fly Speed", 202, 10, 300, State.FlySpeed, "", function(v) State.FlySpeed = v end)

    local _, syncNoclip = toggleRow(c1, "Noclip", 260, State.Noclip, function(v)
        setFeature("Noclip", v)
    end)
    toggleSync.Noclip = syncNoclip
    keybindRow(c1, "Noclip Keybind", 298, function() return State.NoclipKey end, function(k) State.NoclipKey = k end)

    sectionTitle("Movement", y); y += 30
    local c2 = card(y, 12 + 5 * 58 + 12); y += 12 + 5 * 58 + 20
    toggleRow(c2, "Enable WalkSpeed", 12, State.EnableWalkSpeed, function(v)
        setFeature("WalkSpeed", v)
    end)
    cycleRow(c2, "WalkSpeed Method", 50, { "Normal", "Boost", "Rigid" },
        function()
            local i = 1
            for idx, name in { "Normal", "Boost", "Rigid" } do
                if name == State.WalkSpeedMethod then i = idx end
            end
            return i
        end,
        function(i)
            State.WalkSpeedMethod = ({ "Normal", "Boost", "Rigid" })[i]
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum:IsA("Humanoid") then applyWalkSettings(hum) end
        end)
    sliderRow(c2, "WalkSpeed Value", 88, 1, 500, State.WalkSpeed, "", function(v)
        State.WalkSpeed = v
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum:IsA("Humanoid") then applyWalkSettings(hum) end
    end)
    sliderRow(c2, "JumpPower", 146, 20, 500, State.JumpPower, "", function(v)
        State.JumpPower = v
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum:IsA("Humanoid") then applyWalkSettings(hum) end
    end)
    sliderRow(c2, "Gravity", 204, 20, 500, State.Gravity, "", function(v)
        State.Gravity = v
        workspace.Gravity = v
    end)

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)
end

-- === Page: Combat ===
Pages["Combat"] = function()
    clearContent()
    local y = 0

    sectionTitle("AimboT", y); y += 30
    local c1 = card(y, 326); y += 336
    toggleRow(c1, "Enable AimboT", 12, State.AimboT, function(v)
        setFeature("AimboT", v, true)
    end)
    cycleRow(c1, "Aim Key", 50, { "Hold", "Toggle", "Always" },
        function()
            local i = 1
            for idx, name in { "Hold", "Toggle", "Always" } do
                if name == State.AimKey then i = idx end
            end
            return i
        end,
        function(i) State.AimKey = ({ "Hold", "Toggle", "Always" })[i] end)
    keybindRow(c1, "Aim Bind", 88, function() return State.AimKeyCode end, function(k) State.AimKeyCode = k end)
    dropdownRow(c1, "Aim Part", 126, { "Head", "HumanoidRootPart", "UpperTorso", "Torso" },
        function() return State.AimPart end,
        function(v) State.AimPart = v end, true)
    sliderRow(c1, "Smoothness", 184, 0, 20, State.Smoothness, "", function(v) State.Smoothness = v end)
    sliderRow(c1, "Max Distance", 242, 10, 2000, State.AimMaxDist, " studs", function(v) State.AimMaxDist = v end)

    sectionTitle("Tracking Feel", y); y += 30
    local cTrack = card(y, 186); y += 196
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 30), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Smoothness above sets the overall speed. The curve shapes how that speed is spent across the turn.",
        TextColor3 = Theme.TextFaint, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cTrack,
    })
    cycleRow(cTrack, "Smoothing Curve", 42, { "Linear", "Ease", "Human" },
        function()
            for i, name in { "Linear", "Ease", "Human" } do
                if name == State.AimCurve then return i end
            end
            return 2
        end,
        function(i) State.AimCurve = ({ "Linear", "Ease", "Human" })[i] end)
    toggleRow(cTrack, "Predict target movement", 80, State.AimPrediction, function(v)
        State.AimPrediction = v
    end)
    sliderRow(cTrack, "Prediction Lead", 118, 0, 60, State.AimPredictStrength, " cs", function(v)
        State.AimPredictStrength = v
    end)

    sectionTitle("Checks", y); y += 30
    local c2 = card(y, 268); y += 278
    toggleRow(c2, "FOV Check", 12, State.FOVCheck, function(v) State.FOVCheck = v end)
    sliderRow(c2, "FOV (radius)", 50, 20, 800, State.FOVRadius, "px", function(v) State.FOVRadius = v end)
    toggleRow(c2, "Wall Check", 108, State.WallCheck, function(v) State.WallCheck = v end)
    toggleRow(c2, "Alive Check", 146, State.AliveCheck, function(v) State.AliveCheck = v end)
    toggleRow(c2, "Team Check", 184, State.TeamCheck, function(v) State.TeamCheck = v end)
    toggleRow(c2, "Friend Check", 222, State.FriendCheck, function(v) State.FriendCheck = v end)

    sectionTitle("Visuals", y); y += 30
    local c3 = card(y, 134); y += 144
    toggleRow(c3, "Show FOV Circle", 12, State.ShowFOVCircle, function(v) State.ShowFOVCircle = v end)
    toggleRow(c3, "FOV Follow Mouse", 50, State.FOVFollowMouse, function(v) State.FOVFollowMouse = v end)
    toggleRow(c3, "Target Indicator", 88, State.TargetIndicator, function(v) State.TargetIndicator = v end)

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)
end

-- === Page: Resources ===
Pages["Resources"] = function()
    resourcesPageSerial += 1
    local serial = resourcesPageSerial
    clearContent()
    if resourceWatcherDisconnect then
        resourceWatcherDisconnect()
        resourceWatcherDisconnect = nil
    end
    local y = 0

    sectionTitle("Resource Scanner", y); y += 34
    local statsRow = new("Frame", {
        Size = UDim2.new(1, -8, 0, 70), Position = UDim2.fromOffset(0, y),
        BackgroundTransparency = 1, Parent = Content,
    })
    y += 82

    local function miniStat(parent, xScale, xOff, label)
        local box = new("Frame", {
            Size = UDim2.new(0.33, xOff, 1, 0), Position = UDim2.new(xScale, 0, 0, 0),
            BackgroundColor3 = Theme.Glass, BorderSizePixel = 0, Parent = parent,
        })
        corner(10, box)
        stroke(Theme.Stroke, 1, box)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 10),
            BackgroundTransparency = 1, Font = Theme.Font, Text = label:upper(),
            TextColor3 = Theme.TextFaint, TextSize = 10, Parent = box,
        })
        return new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 26),
            BackgroundTransparency = 1, Font = Theme.FontBlack, Text = "—",
            TextColor3 = Theme.Text, TextSize = 22, Parent = box,
        })
    end

    local totalVal    = miniStat(statsRow, 0.00,  -6, "Total Resources")
    local typesVal    = miniStat(statsRow, 0.335, -6, "Types Found")
    typesVal.TextColor3 = Theme.Accent2
    local selectedVal = miniStat(statsRow, 0.67,  -6, "Selected")
    selectedVal.TextColor3 = Theme.Success

    local badges = {}
    local renderedKey = ""

    local function applyStats(buckets)
        local total, types, selected = 0, 0, 0
        for name, list in buckets do
            total += #list
            types += 1
            if State.ResourcesToCollect[name] then selected += #list end
            local badge = badges[name]
            if badge and badge.Parent then badge.Text = tostring(#list) end
        end
        if totalVal.Parent then
            totalVal.Text = tostring(total)
            typesVal.Text = tostring(types)
            selectedVal.Text = tostring(selected)
        end
        return buckets
    end

    sectionTitle("Toggle By Type", y); y += 34
    local buckets = applyStats(ResourceScanner.scan())
    local typeNames = {}
    for name in buckets do table.insert(typeNames, name) end
    table.sort(typeNames)

    if #typeNames == 0 then
        local c = card(y, 70)
        new("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Font = Theme.Font, Text = "No resources found in workspace.Resources.",
            TextColor3 = Theme.TextFaint, TextSize = 12, TextWrapped = true, Parent = c,
        })
        y += 80
    else
        local rowH = 42
        local c = card(y, 12 + #typeNames * rowH + 12)
        y += 12 + #typeNames * rowH + 20
        for i, tname in typeNames do
            local list = buckets[tname]
            local rowY = 8 + (i - 1) * rowH
            local row = new("Frame", {
                Size = UDim2.new(1, -32, 0, rowH - 4), Position = UDim2.fromOffset(16, rowY),
                BackgroundTransparency = 1, Parent = c,
            })
            local dot = new("Frame", {
                Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(0, rowH/2 - 9),
                BackgroundColor3 = Theme.Accent2, BorderSizePixel = 0, Parent = row,
            })
            corner(5, dot)
            gradient(Theme.Accent, Theme.Accent2, 0, dot)
            new("TextLabel", {
                Size = UDim2.new(0.5, -20, 1, 0), Position = UDim2.fromOffset(20, 0),
                BackgroundTransparency = 1, Font = Theme.Font, Text = tname,
                TextColor3 = Theme.Text, TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
            })
            local badge = new("Frame", {
                Size = UDim2.fromOffset(46, 20), Position = UDim2.new(1, -130, 0.5, -10),
                BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0, Parent = row,
            })
            corner(10, badge)
            stroke(Theme.Stroke, 1, badge)
            local countLabel = new("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Font = Theme.FontBold, Text = tostring(#list),
                TextColor3 = Theme.TextDim, TextSize = 11, Parent = badge,
            })
            badges[tname] = countLabel
            if State.ResourcesToCollect[tname] == nil then State.ResourcesToCollect[tname] = false end
            toggleRow(row, "", 0, State.ResourcesToCollect[tname], function(v)
                State.ResourcesToCollect[tname] = v
                applyStats(ResourceScanner.scan())
            end)
        end
    end

    sectionTitle("Refresh", y); y += 34
    local cR = card(y, 60); y += 70
    local refreshBtn = new("TextButton", {
        Size = UDim2.fromOffset(140, 34), Position = UDim2.fromOffset(16, 13),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
        Font = Theme.FontBold, Text = "Rescan Now",
        TextColor3 = Color3.new(1,1,1), TextSize = 13,
        AutoButtonColor = false, Parent = cR,
    })
    corner(8, refreshBtn)
    gradient(Theme.Accent, Theme.Accent2, 0, refreshBtn)
    track(refreshBtn.MouseButton1Click:Connect(function()
        Pages["Resources"]()
        Notifications.info("Scanner", "Rescanned workspace.Resources")
    end))

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)
    renderedKey = table.concat(typeNames, "\0")

    resourceWatcherDisconnect = ResourceScanner.watch(function()
        if State._rescanScheduled then return end
        State._rescanScheduled = true
        later(1, function()
            State._rescanScheduled = false
            if Flags.Unloading or serial ~= resourcesPageSerial or currentPage ~= "Resources" then return end
            local nextBuckets = ResourceScanner.scan()
            local names = {}
            for name in nextBuckets do table.insert(names, name) end
            table.sort(names)
            if table.concat(names, "\0") ~= renderedKey then
                Pages["Resources"]()
            else
                applyStats(nextBuckets)
            end
        end)
    end)
end

-- ============================================================
--  PROBE TOOL
-- ============================================================
local ProbeTool = {}
do
    local bus = Instance.new("BindableFunction")
    bus.Name = "TroyHubProbeBus"

    local candidates = {
        "QCAddResources", "Market", "Civilization", "Upgrade",
        "Inventory", "Storage", "Gathering", "Craft", "Building",
    }

    local function safeValuesFor(name)
        if name == "QCAddResources" then
            return { { "Tree", 1 }, { 1 }, { "Tree", 1, player } }
        elseif name == "Upgrade" then
            return { { 1 }, { "Tree" } }
        elseif name == "Market" or name == "Craft" or name == "Building" then
            return { { "Tree", 1 } }
        else
            return { { } }
        end
    end

    function ProbeTool.run(remoteName: string, logFn)
        local folder = ReplicatedStorage:FindFirstChild("Remotes")
        if not folder then
            logFn("Probe: Remotes folder missing")
            return false, "no-remotes"
        end
        local remote = folder:FindFirstChild(remoteName)
        if not remote or not remote:IsA("RemoteEvent") then
            logFn("Probe: " .. remoteName .. " not found")
            return false, "not-found"
        end

        local before = {}
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            for _, stat in ls:GetChildren() do
                before[stat.Name] = stat.Value
            end
        end

        local values = safeValuesFor(remoteName)
        logFn(string.format("Probe: testing %s with %d arg-shapes", remoteName, #values))

        for i, args in values do
            if Flags.Unloading then return false, "unloading" end
            local packed = table.pack(table.unpack(args))
            local ok, err = pcall(function()
                remote:FireServer(table.unpack(packed, 1, packed.n))
            end)
            if not ok then
                logFn(string.format("  [%d] error: %s", i, tostring(err)))
            else
                logFn(string.format("  [%d] fired with %s", i, tostring(packed.n) .. " arg(s)"))
            end
            task.wait(0.6)
        end

        task.wait(0.5)
        local changed = {}
        if ls then
            for _, stat in ls:GetChildren() do
                local old = before[stat.Name]
                if old ~= stat.Value then
                    table.insert(changed, string.format("%s: %s → %s", stat.Name, tostring(old), tostring(stat.Value)))
                end
            end
        end
        if #changed > 0 then
            logFn("  result: " .. table.concat(changed, ", "))
            return true, "changed"
        end
        logFn("  result: no leaderstats change")
        return false, "no-change"
    end

    ProbeTool.candidates = candidates
end

-- === Page: Server ===
Pages["Server"] = function()
    clearContent()
    local y = 0

    sectionTitle("Main", y); y += 30
    local c1 = card(y, 306); y += 316

    actionButton(c1, "Server Hop", 12, function()
        task.spawn(ServerTools.hop, false)
    end)
    actionButton(c1, "Join Smallest Server", 50, function()
        task.spawn(ServerTools.hop, true)
    end)
    actionButton(c1, "Rejoin Server", 88, function()
        ServerTools.rejoin()
    end)
    toggleRow(c1, "Auto Rejoin on disconnect / kick", 126, State.AutoRejoin, function(v)
        State.AutoRejoin = v
        Notifications.info("Auto Rejoin", v and "Enabled" or "Disabled")
    end)

    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 20), Position = UDim2.fromOffset(16, 164),
        BackgroundTransparency = 1, Font = Theme.FontBold, Text = "JobId",
        TextColor3 = Theme.TextDim, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center, Parent = c1,
    })
    local _, box = textboxRow(c1, "", 186, "Enter JobId here...", nil)
    box.Size = UDim2.new(1, -32, 0, 30)
    box.Position = UDim2.fromOffset(16, 186)
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.BackgroundTransparency = 0.5

    actionButton(c1, "Join by JobId", 224, function()
        ServerTools.joinJob(box.Text)
    end)
    actionButton(c1, "Copy JobId", 262, function()
        local copied = false
        pcall(function()
            local clip = rawget(_G, "setclipboard")
            if typeof(clip) == "function" then
                clip(game.JobId)
                copied = true
            end
        end)
        if copied then
            Notifications.success("JobId", "Copied to clipboard")
        else
            Notifications.warn("JobId", game.JobId)
        end
    end)

    sectionTitle("Server Info", y); y += 30
    local c2 = card(y, 130); y += 140
    local infoLabel = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, -24), Position = UDim2.fromOffset(16, 12),
        BackgroundTransparency = 1, Font = Enum.Font.Code, Text = "Loading...",
        TextColor3 = Theme.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = c2,
    })
    Scheduler.add("page:serverinfo", "logic", 0.5, function()
        if Flags.Unloading or currentPage ~= "Server" or not infoLabel.Parent then return end
        local mem = 0
        pcall(function() mem = math.floor(Stats:GetTotalMemoryUsageMb()) end)
        local fps = math.floor(FrameRate.fps + 0.5)
        infoLabel.Text = string.format(
            "Players: %d / %d\nMemory: %d MB\nPlaceId: %d\nFPS: %d\nPing: %d ms",
            #Players:GetPlayers(), Players.MaxPlayers, mem, game.PlaceId, fps, getPingMs())
    end)

    sectionTitle("Probe Remote", y); y += 30
    local probeH = 44 + #ProbeTool.candidates * 38 + 12
    local c3 = card(y, probeH); y += probeH + 10

    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 36), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Fires each remote with small, safe test values and logs the result.",
        TextColor3 = Theme.TextDim, TextSize = 11, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = c3,
    })

    for i, name in ProbeTool.candidates do
        actionButton(c3, "Probe  " .. name, 44 + (i - 1) * 38, function()
            local ok, result = ProbeTool.run(name, function(line) log(line) end)
            if ok then
                Notifications.success("Probe", name .. " responded")
            else
                Notifications.warn("Probe", name .. " → " .. tostring(result))
            end
        end)
    end

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)
end

-- === Page: UI Settings ===
Pages["UI Settings"] = function()
    clearContent()
    local y = 0

    local KEYBIND_ROWS = {
        { "Menu Toggle", "MenuKey" },
        { "Auto Gather", "GatherKey" },
        { "Panic (unload everything)", "PanicKey" },
        { "Fly", "FlyKey" },
        { "Noclip", "NoclipKey" },
        { "Infinite Jump", "InfJumpKey" },
        { "Aim", "AimKeyCode" },
    }
    local ACCENT_PRESETS = {
        { "Gold", Color3.fromRGB(212, 160, 64), Color3.fromRGB(196, 112, 48) },
        { "Ember", Color3.fromRGB(232, 120, 64), Color3.fromRGB(180, 64, 48) },
        { "Sage", Color3.fromRGB(132, 176, 112), Color3.fromRGB(88, 140, 96) },
        { "Sand", Color3.fromRGB(212, 196, 156), Color3.fromRGB(164, 140, 104) },
        { "Mono", Color3.fromRGB(220, 220, 216), Color3.fromRGB(140, 140, 136) },
    }
    local function colorToHex(c: Color3): string
        return string.format("%02X%02X%02X",
            math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end
    local function hexToColor(text: string): Color3?
        local hex = string.gsub(text or "", "[^%x]", "")
        if #hex ~= 6 then return nil end
        local n = tonumber(hex, 16)
        if not n then return nil end
        return Color3.fromRGB(
            math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
    end

    -- === Search ===
    sectionTitle("Find a Setting", y); y += 34
    local cSearch = card(y, 250); y += 260
    local _, searchBox = textboxRow(cSearch, "", 12, "Type a setting name…", nil)
    searchBox.Size = UDim2.new(1, -32, 0, 30)
    searchBox.Position = UDim2.fromOffset(16, 12)
    searchBox.BackgroundTransparency = 0.5

    local resultHolder = new("Frame", {
        Size = UDim2.new(1, -32, 0, 190), Position = UDim2.fromOffset(16, 50),
        BackgroundTransparency = 1, Parent = cSearch,
    })
    local hint = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Search across every page.", TextColor3 = Theme.TextFaint, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = resultHolder,
    })

    local function renderResults(query: string)
        for _, child in resultHolder:GetChildren() do
            if child ~= hint then child:Destroy() end
        end
        local q = string.lower(string.gsub(query, "^%s+", ""))
        if #q < 2 then
            hint.Text = if Search.ready
                then string.format("Search across every page.")
                else "Building the index…"
            return
        end
        local hits = {}
        for label, page in Search.map do
            if string.find(string.lower(label), q, 1, true) then
                table.insert(hits, { label = label, page = page })
            end
        end
        table.sort(hits, function(a, b)
            if a.page ~= b.page then return a.page < b.page end
            return a.label < b.label
        end)
        if #hits == 0 then
            hint.Text = "Nothing matches \"" .. query .. "\""
            return
        end
        hint.Text = string.format("%d match%s — click to jump", #hits, if #hits == 1 then "" else "es")
        for i = 1, math.min(#hits, 6) do
            local hit = hits[i]
            local row = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 22 + (i - 1) * 28),
                BackgroundColor3 = Theme.GlassHi, BorderSizePixel = 0,
                Font = Theme.Font, Text = "", AutoButtonColor = false, Parent = resultHolder,
            })
            corner(6, row)
            new("TextLabel", {
                Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(10, 0),
                BackgroundTransparency = 1, Font = Theme.Font, Text = hit.label,
                TextColor3 = Theme.Text, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
            })
            new("TextLabel", {
                Size = UDim2.fromOffset(100, 26), Position = UDim2.new(1, -104, 0, 0),
                BackgroundTransparency = 1, Font = Theme.FontBold, Text = hit.page,
                TextColor3 = Theme.Accent, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
            })
            trackPage(row.MouseButton1Click:Connect(function()
                navigateTo(hit.page)
            end))
        end
    end

    trackPage(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        renderResults(searchBox.Text)
    end))
    renderResults("")

    -- === Keybinds ===
    sectionTitle("Keybinds", y); y += 34
    local cKeys = card(y, 12 + #KEYBIND_ROWS * 38 + 12)
    y += 12 + #KEYBIND_ROWS * 38 + 20
    for i, entry in KEYBIND_ROWS do
        local label, field = entry[1], entry[2]
        keybindRow(cKeys, label, 12 + (i - 1) * 38,
            function() return State[field] end,
            function(k) State[field] = k end)
    end

    -- === Theme ===
    sectionTitle("Theme", y); y += 34
    local cTheme = card(y, 176); y += 186
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 10),
        BackgroundTransparency = 1, Font = Theme.Font, Text = "Accent preset",
        TextColor3 = Theme.TextDim, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = cTheme,
    })
    local hexA, hexB
    local swatchW = 1 / #ACCENT_PRESETS
    for i, preset in ACCENT_PRESETS do
        local name, a, b = preset[1], preset[2], preset[3]
        local sw = new("TextButton", {
            Size = UDim2.new(swatchW, -8, 0, 34),
            Position = UDim2.new(swatchW * (i - 1), 16, 0, 32),
            BackgroundColor3 = a, BorderSizePixel = 0, Font = Theme.FontBold,
            Text = name, TextColor3 = Theme.Bg, TextSize = 11,
            AutoButtonColor = false, Parent = cTheme,
        })
        corner(8, sw)
        gradient(a, b, 0, sw)
        trackPage(sw.MouseButton1Click:Connect(function()
            applyAccents(a, b)
            if hexA then hexA.Text = colorToHex(a) end
            if hexB then hexB.Text = colorToHex(b) end
            Notifications.success("Theme", name .. " applied")
        end))
    end

    local _, boxA = textboxRow(cTheme, "Accent hex", 76, "D4A040", function(txt)
        local c = hexToColor(txt)
        if not c then
            Notifications.warn("Theme", "Use a 6-digit hex like D4A040")
            return
        end
        applyAccents(c, Theme.Accent2)
    end)
    hexA = boxA
    hexA.Text = colorToHex(Theme.Accent)

    local _, boxB = textboxRow(cTheme, "Secondary hex", 114, "C47030", function(txt)
        local c = hexToColor(txt)
        if not c then
            Notifications.warn("Theme", "Use a 6-digit hex like C47030")
            return
        end
        applyAccents(Theme.Accent, c)
    end)
    hexB = boxB
    hexB.Text = colorToHex(Theme.Accent2)

    -- === Interface ===
    sectionTitle("Interface", y); y += 34
    local cUI = card(y, 250); y += 260
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "– hides the menu (toggle key shows it). ✕ or Unload Hub fully stops the script.",
        TextColor3 = Theme.TextFaint, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cUI,
    })
    toggleRow(cUI, "Auto-fit to screen size", 44, State.AutoUIScale, function(v)
        State.AutoUIScale = v
        applyUiScale()
    end)
    sliderRow(cUI, "Extra UI Scale", 82, 50, 200,
        math.floor(clampNum(State.UIScale, 0.5, 2, 1) * 100), "%", function(v)
        State.UIScale = v / 100
        applyUiScale()
    end)
    toggleRow(cUI, "Mobile toggle button", 140, State.TouchButton, function(v)
        State.TouchButton = v
    end)
    actionButton(cUI, "Reset Window Position", 178, function()
        Main.Position = UDim2.fromScale(0.5, 0.5)
        Main.AnchorPoint = Vector2.new(0.5, 0.5)
        applyUiScale()
        Notifications.info("UI", "Window centered")
    end)
    actionButton(cUI, "Rebuild Search Index", 212, function()
        Search.ready = false
        table.clear(Search.map)
        task.defer(buildSettingsIndex)
        Notifications.info("Search", "Reindexing every page…")
    end)

    -- === Config ===
    sectionTitle("Config", y); y += 34
    local cCfg = card(y, 302); y += 312
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Saved to " .. Hub.Config.fileName() .. " in your executor's workspace folder. Without file access, Save copies to the clipboard instead.",
        TextColor3 = Theme.TextFaint, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = cCfg,
    })
    actionButton(cCfg, "Save Config", 46, function()
        Hub.Config.save()
    end)
    actionButton(cCfg, "Load Config", 84, function()
        Hub.Config.load()
    end)
    actionButton(cCfg, "Copy Config to Clipboard", 122, function()
        local text = Hub.Config.serialize()
        local clip = rawget(_G, "setclipboard")
        if text and type(clip) == "function" then
            pcall(clip, text)
            Notifications.success("Config", "Copied to clipboard")
        else
            Notifications.warn("Config", "No clipboard access")
        end
    end)
    local _, pasteBox = textboxRow(cCfg, "", 160, "Paste a config JSON here, then press Enter", function(txt)
        Hub.Config.loadFromText(txt)
    end)
    pasteBox.Size = UDim2.new(1, -32, 0, 30)
    pasteBox.Position = UDim2.fromOffset(16, 160)
    pasteBox.BackgroundTransparency = 0.5
    actionButton(cCfg, "Delete Saved Config", 198, function()
        Hub.Config.delete()
    end)
    actionButton(cCfg, "Reset All Settings to Default", 236, function()
        Hub.Config.resetAll()
    end)

    -- === Danger ===
    sectionTitle("Danger", y); y += 34
    local cDanger = card(y, 56); y += 66
    local unloadBtn = actionButton(cDanger, "Unload Hub", 12, function()
        Notifications.info("Troy", "Flags.Unloading…")
        CloseAndUnload()
    end)
    unloadBtn.TextColor3 = Theme.Danger

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)
end

-- === Page: Dashboard ===
Pages["Dashboard"] = function()
    clearContent()
    local y = 0

    sectionTitle("Overview", y); y += 34
    local cHi = card(y, 78); y += 88
    local hello = new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 22), Position = UDim2.fromOffset(16, 12),
        BackgroundTransparency = 1, Font = Theme.FontBold,
        Text = "Hi, " .. (player.DisplayName or player.Name),
        TextColor3 = Theme.Text, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = cHi,
    })
    local session = new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(16, 36),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Turn on Auto Gather to farm. Visuals, Combat, and Server are in the left list.", TextColor3 = Theme.TextDim, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = cHi,
    })

    sectionTitle("Live Stats", y); y += 34
    local statsRow = new("Frame", {
        Size = UDim2.new(1, -8, 0, 70), Position = UDim2.fromOffset(0, y),
        BackgroundTransparency = 1, Parent = Content,
    })
    y += 82

    local function miniStat(parent, xScale, xOff, label)
        local box = new("Frame", {
            Size = UDim2.new(0.25, xOff, 1, 0), Position = UDim2.new(xScale, 0, 0, 0),
            BackgroundColor3 = Theme.Glass, BorderSizePixel = 0, Parent = parent,
        })
        corner(10, box)
        stroke(Theme.Stroke, 1, box)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 10),
            BackgroundTransparency = 1, Font = Theme.Font, Text = label:upper(),
            TextColor3 = Theme.TextFaint, TextSize = 10, Parent = box,
        })
        return new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 26),
            BackgroundTransparency = 1, Font = Theme.FontBlack, Text = "—",
            TextColor3 = Theme.Text, TextSize = 20, Parent = box,
        })
    end

    local fpsVal  = miniStat(statsRow, 0.00, -6, "FPS")
    local pingVal = miniStat(statsRow, 0.25, -6, "Ping")
    pingVal.TextColor3 = Theme.Accent2
    local memVal  = miniStat(statsRow, 0.50, -6, "Memory")
    local plyVal  = miniStat(statsRow, 0.75, -6, "Players")
    plyVal.TextColor3 = Theme.Success

    sectionTitle("Farm", y); y += 34
    local cFarm = card(y, 90); y += 100
    local farmLabel = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, -24), Position = UDim2.fromOffset(16, 12),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Idle", TextColor3 = Theme.TextDim, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = cFarm,
    })

    sectionTitle("Session Stats", y); y += 34
    local cStats = card(y, 100); y += 110
    local statsLabel = new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 44), Position = UDim2.fromOffset(16, 12),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "No farming yet", TextColor3 = Theme.TextDim, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = cStats,
    })
    actionButton(cStats, "Reset Session Counters", 58, function()
        FarmStats.reset()
        Notifications.info("Stats", "Session counters cleared")
    end)

    sectionTitle("Quick Toggles", y); y += 34
    local cQ = card(y, 12 + 5 * 38 + 12); y += 12 + 5 * 38 + 20
    local _, syncDashGather = toggleRow(cQ, "Auto Gather", 12, State.AutoGather, function(v)
        setFeature("AutoGather", v, true)
    end)
    toggleSync.AutoGather = syncDashGather
    toggleRow(cQ, "Player ESP", 50, State.PlayerESP, function(v)
        setFeature("PlayerESP", v, true)
    end)
    local _, syncDashFly = toggleRow(cQ, "Fly", 88, State.Fly, function(v)
        setFeature("Fly", v)
    end)
    toggleSync.Fly = syncDashFly
    local _, syncDashClip = toggleRow(cQ, "Noclip", 126, State.Noclip, function(v)
        setFeature("Noclip", v)
    end)
    toggleSync.Noclip = syncDashClip
    toggleRow(cQ, "AimboT", 164, State.AimboT, function(v)
        setFeature("AimboT", v, true)
    end)

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)

    Scheduler.add("page:dashboard", "logic", 0.4, function()
        if Flags.Unloading or currentPage ~= "Dashboard" then return end
        local mem = 0
        pcall(function() mem = math.floor(Stats:GetTotalMemoryUsageMb()) end)
        if fpsVal.Parent then
            fpsVal.Text = tostring(math.floor(FrameRate.fps + 0.5))
            pingVal.Text = tostring(getPingMs()) .. "ms"
            memVal.Text = tostring(mem) .. " MB"
            plyVal.Text = string.format("%d/%d", #Players:GetPlayers(), Players.MaxPlayers)
        end
        if session.Parent then
            session.Text = string.format("Place %d  ·  Job %s", game.PlaceId, string.sub(game.JobId, 1, 8))
        end
        if farmLabel.Parent then
            local last = State._debugLog[1] or "no gather activity yet"
            if State.TeleportGather then
                farmLabel.Text = string.format("Teleport Gather on\n%s", last)
                farmLabel.TextColor3 = Theme.Success
            elseif State.LegitMode then
                farmLabel.Text = string.format("Legit Gather on — walking and clicking\n%s", last)
                farmLabel.TextColor3 = Theme.Success
            elseif State.AutoGather then
                farmLabel.Text = string.format("Auto Gather on  ·  fly\n%s", last)
                farmLabel.TextColor3 = Theme.Success
            elseif State.GatherAround then
                farmLabel.Text = "Gather Around on — mines what you walk by\n" .. last
                farmLabel.TextColor3 = Theme.Warn
            else
                farmLabel.Text = "Farm idle — press " .. tostring(State.GatherKey):gsub("^Enum%.%a+%.", "") .. " or use Auto Gather"
                farmLabel.TextColor3 = Theme.TextDim
            end
        end
        if statsLabel.Parent then
            statsLabel.Text = string.format(
                "Session %s   ·   %d nodes   ·   %.1f / min   ·   %d swings\n%s",
                FarmStats.clock(), FarmStats.nodes, FarmStats.perMinute(),
                FarmStats.swings, FarmStats.topKinds(4))
        end
    end)
end

Pages["Diagnostics"] = function()
    clearContent()
    local y = 0
    sectionTitle("Runtime", y); y += 34
    local cRun = card(y, 150); y += 160
    local runLabel = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, -16), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "Collecting…", TextColor3 = Theme.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = cRun,
    })

    sectionTitle("Jobs", y); y += 34
    local cJobs = card(y, 130); y += 140
    local jobLabel = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, -16), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "—", TextColor3 = Theme.TextDim, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = cJobs,
    })

    sectionTitle("Console", y); y += 34
    local cCmd = card(y, 90); y += 100
    new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 8),
        BackgroundTransparency = 1, Font = Theme.Font,
        Text = "/help  /toggle  /reload  /reset  /debug  /dump  /panic  /profile",
        TextColor3 = Theme.TextFaint, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = cCmd,
    })
    local _, cmdBox = textboxRow(cCmd, "", 34, "/help", function(txt)
        local out = if Hub.Gui and Hub.Gui.runCommand then Hub.Gui.runCommand(txt) else "console unavailable"
        Notifications.info("Console", out)
        if Hub.log then Hub.log(out) end
    end)
    cmdBox.Size = UDim2.new(1, -32, 0, 30)
    cmdBox.Position = UDim2.fromOffset(16, 34)
    cmdBox.BackgroundTransparency = 0.4

    sectionTitle("Actions", y); y += 34
    local cAct = card(y, 94); y += 104
    actionButton(cAct, "Safe Mode", 12, function()
        if Hub.safeMode then Hub.safeMode(true) end
    end)
    actionButton(cAct, "Recovery", 50, function()
        if Hub.recovery then Hub.recovery() end
    end)

    Content.CanvasSize = UDim2.new(0, 0, 0, y + 40)

    Scheduler.add("page:diagnostics", "logic", 0.5, function()
        if Flags.Unloading or currentPage ~= "Diagnostics" then return end
        if not runLabel.Parent then return end
        local snap = if Hub.Gui and Hub.Gui.diagnostics then Hub.Gui.diagnostics() else {}
        local feats = snap.features
        local featText = "none"
        if type(feats) == "table" and #feats > 0 then
            featText = table.concat(feats, ", ")
        end
        runLabel.Text = string.format(
            "v%s\nFPS %.0f   ping %d   mem %.0f MB\njobs %s   signals %s   page %s\nfeatures: %s\nlast error: %s",
            tostring(snap.version or "?"),
            snap.fps or 0,
            snap.ping or 0,
            snap.memoryMb or 0,
            tostring(snap.jobs or 0),
            tostring(snap.signals or 0),
            tostring(snap.page or "—"),
            featText,
            (snap.lastError ~= "" and snap.lastError) or "none"
        )
        local rows = {}
        if Hub.Scheduler and Hub.Scheduler.snapshot then
            for _, job in Hub.Scheduler.snapshot() do
                table.insert(rows, string.format("%s  %.1fms  err=%d%s",
                    job.name, job.lastMs or 0, job.errors or 0,
                    job.disabled and "  ISOLATED" or ""))
            end
            table.sort(rows)
        end
        jobLabel.Text = if #rows > 0 then table.concat(rows, "\n") else "no jobs"
    end)
end

-- ============================================================
--  BUILD SIDEBAR
-- ============================================================
local function sectionHeader(text, y)
    return new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(16, y),
        BackgroundTransparency = 1, Font = Theme.FontBold, Text = text:upper(),
        TextColor3 = Theme.TextFaint, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Sidebar,
    })
end

local sidebarY = 34
local function addNav(name)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, sidebarY),
        BackgroundColor3 = Theme.GlassHi, BackgroundTransparency = 1,
        BorderSizePixel = 0, Font = Theme.Font, Text = "    " .. name,
        TextColor3 = Theme.TextDim, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, Parent = Sidebar,
    })
    corner(8, btn)
    sidebarY += 40
    local bar = new("Frame", {
        Name = "AccentBar", Size = UDim2.fromOffset(3, 18),
        Position = UDim2.fromOffset(0, 9), BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0, Visible = false, Parent = btn,
    })
    corner(2, bar)
    gradient(Theme.Accent, Theme.Accent2, 90, bar)
    track(btn.MouseEnter:Connect(function()
        if currentPage ~= name then tween(btn, { TextColor3 = Theme.Text }, 0.12) end
    end))
    track(btn.MouseLeave:Connect(function()
        if currentPage ~= name then tween(btn, { TextColor3 = Theme.TextDim }, 0.12) end
    end))
    track(btn.MouseButton1Click:Connect(function()
        navigateTo(name)
    end))
    navButtons[name] = btn
end

sectionHeader("Overview", 10)
addNav("Dashboard")
addNav("Resources")
addNav("Auto Gather")

sectionHeader("Game", sidebarY + 4); sidebarY += 24
addNav("Combat")
addNav("Visuals")
addNav("Local Player")
addNav("Server")

sectionHeader("Settings", sidebarY + 4); sidebarY += 24
addNav("UI Settings")
addNav("Diagnostics")

-- ============================================================
--  DRAG
-- ============================================================
do
    local dragging, dragStart, startPos
    track(Header.InputBegan:Connect(function(input)
        if isPointerBegin(input) then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and isPointerMove(input) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if isPointerBegin(input) then dragging = false end
    end))
end

-- ============================================================
--  MOBILE TOGGLE
--  Touch devices have no RightShift, so without this the hub can be hidden
--  with no way back. Draggable, because a fixed corner button always ends up
--  on top of something the game needs.
-- ============================================================
do
    local touchBtn: TextButton? = nil
    local touchGui: ScreenGui? = nil

    local function buildTouchButton()
        if touchBtn then return end
        -- Its own ScreenGui: minimising the hub sets ScreenGui.Enabled = false,
        -- which would take the only way back with it.
        local gui = new("ScreenGui", {
            Name = "TroyHubTouch", ResetOnSpawn = false,
            IgnoreGuiInset = true, DisplayOrder = 998, Parent = playerGui,
        })
        touchGui = gui
        local btn = new("TextButton", {
            Name = "Toggle", Size = UDim2.fromOffset(52, 52),
            Position = UDim2.new(0, 16, 0.5, -26),
            BackgroundColor3 = Theme.Glass, BorderSizePixel = 0,
            Font = Theme.FontBlack, Text = "T", TextColor3 = Theme.Accent,
            TextSize = 22, AutoButtonColor = false, Parent = gui,
        })
        corner(26, btn)
        stroke(Theme.Accent, 1, btn)
        touchBtn = btn

        local dragging, moved, startAt, startPos
        track(btn.InputBegan:Connect(function(input)
            if isPointerBegin(input) then
                dragging = true
                moved = false
                startAt = input.Position
                startPos = btn.Position
            end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if not dragging or not isPointerMove(input) then return end
            local d = input.Position - startAt
            if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then moved = true end
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if not dragging or not isPointerBegin(input) then return end
            dragging = false
            -- A drag should reposition the button, not toggle the hub.
            if not moved then
                ScreenGui.Enabled = true
                releaseGuiFocus()
            end
        end))
    end

    local function syncTouchButton()
        if Flags.Unloading then return end
        local want = State.TouchButton == true and UserInputService.TouchEnabled
        if want and not touchBtn then buildTouchButton() end
        if touchGui then
            -- Only needed while the hub is hidden; on screen at the same time
            -- as the window it just covers the game for no reason.
            (touchGui :: ScreenGui).Enabled = want and not ScreenGui.Enabled
        end
    end

    Scheduler.add("touchbtn", "logic", 0.4, syncTouchButton)
    syncTouchButton()
end

-- Panic: everything off, movement freed, forces cleared, hub gone. Meant to be
-- hit when a moderator shows up, so it does the destructive things first and
-- notifies nobody.
local function Panic()
    pcall(function() ScreenGui.Enabled = false end)
    State.AutoGather = false
    State.TeleportGather = false
    State.GatherAround = false
    State.LegitMode = false
    State.PlayerESP = false
    State.ResourceESP = false
    State.AimboT = false
    State.AutoSell = false
    if Hub.FeatureManager then
        pcall(function() Hub.FeatureManager.disableAll() end)
    end
    if cancelMoveTween then pcall(cancelMoveTween) end
    if unlockMovement then pcall(unlockMovement) end
    pcall(function()
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        for _, d in char:GetDescendants() do
            if d:IsA("BodyVelocity") or d:IsA("BodyGyro") or d:IsA("BodyPosition")
                or d:IsA("LinearVelocity") or d:IsA("AlignPosition")
                or d:IsA("AlignOrientation") or d:IsA("VectorForce") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.CanCollide = true
                d.LocalTransparencyModifier = 0
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        workspace.Gravity = EnvDefaults.Gravity
        Lighting.GlobalShadows = EnvDefaults.GlobalShadows
    end)
    CloseAndUnload()
end

-- Keeps the character inside believable speeds. Physics exploits read as a
-- single huge velocity frame, so clamping the assembly is what matters, not
-- WalkSpeed.
Scheduler.add("velclamp", "logic", 0, function()
    if Flags.Unloading or not State.VelocityClamp then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end
    local cap = clampNum(State.MaxVelocity, 16, 500, 160)
    local v = root.AssemblyLinearVelocity
    local horiz = Vector3.new(v.X, 0, v.Z)
    if horiz.Magnitude > cap then
        local capped = horiz.Unit * cap
        root.AssemblyLinearVelocity = Vector3.new(capped.X, math.clamp(v.Y, -250, 250), capped.Z)
    end
end)

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or Flags.Unloading or keybindCapturing then return end
    if inputMatches(input, State.PanicKey) then
        Panic()
        return
    end
    -- Don't steal the hold key while a world prompt / job interact is up.
    if promptVisible > 0 then return end
    if inputMatches(input, State.MenuKey) then
        ScreenGui.Enabled = not ScreenGui.Enabled
        releaseGuiFocus()
        return
    end
    if inputMatches(input, State.GatherKey) then
        setFeature("AutoGather", not State.AutoGather, true)
    elseif inputMatches(input, State.FlyKey) then
        Hub.Registry.toggle("Fly", true)
    elseif inputMatches(input, State.NoclipKey) then
        Hub.Registry.toggle("Noclip", true)
    elseif inputMatches(input, State.InfJumpKey) then
        Hub.Registry.toggle("InfiniteJump", true)
    end
end))

-- Character / death / camera are owned by Hub.Lifecycle (bound at the end of
-- this module so farm cleanup closures already exist).

do
    local vu
    pcall(function()
        vu = game:GetService("VirtualUser")
    end)
    if vu then
        track(player.Idled:Connect(function()
            if Flags.Unloading or not State.AntiAFK then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            pcall(function()
                vu:Button2Down(Vector2.zero, cam.CFrame)
                task.wait(1)
                vu:Button2Up(Vector2.zero, cam.CFrame)
            end)
        end))
    end
end

navigateTo("Auto Gather")

-- ============================================================
--  ESP
-- ============================================================
local ESP = {}
do
    local espGui = new("ScreenGui", {
        Name = "TroyHubESP", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 998,
        Parent = playerGui,
    })
    local espFolder = new("Folder", { Name = "Drawings", Parent = espGui })
    local drawings = {}

    local PLAYER_COLOR = Color3.fromRGB(255, 90, 110)
    local RESOURCE_COLOR = Color3.fromRGB(80, 220, 140)
    local BONE_COUNT = 14
    local CHAM_CAP = 20
    local chamCount = 0
    local R15_BONES = {
        { "Head", "UpperTorso" },
        { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" },
        { "LeftUpperArm", "LeftLowerArm" },
        { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" },
        { "RightUpperArm", "RightLowerArm" },
        { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" },
        { "LeftUpperLeg", "LeftLowerLeg" },
        { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" },
        { "RightUpperLeg", "RightLowerLeg" },
        { "RightLowerLeg", "RightFoot" },
    }
    local R6_BONES = {
        { "Head", "Torso" },
        { "Torso", "Left Arm" },
        { "Torso", "Right Arm" },
        { "Torso", "Left Leg" },
        { "Torso", "Right Leg" },
    }

    local function buildDrawing(color)
        local holder = new("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = espFolder,
        })
        local box = new("Frame", {
            Name = "Box", BackgroundTransparency = 1, BorderSizePixel = 0,
            Visible = false, ZIndex = 5, Parent = holder,
        })
        local boxStroke = stroke(color, 1, box)
        local healthBg = new("Frame", {
            Name = "HealthBg", BackgroundColor3 = Color3.fromRGB(30,30,30),
            BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = holder,
        })
        local healthFill = new("Frame", {
            Name = "HealthFill", Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Theme.Success, BorderSizePixel = 0,
            ZIndex = 6, Parent = healthBg,
        })
        new("UIStroke", { Color = Color3.new(0,0,0), Thickness = 1, Transparency = 0.5, Parent = healthBg })
        local nameLabel = new("TextLabel", {
            Name = "NameLabel", Size = UDim2.new(0, 180, 0, 14),
            BackgroundTransparency = 1, Font = Theme.FontBold,
            Text = "", TextColor3 = color, TextSize = 12,
            TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.new(0,0,0),
            TextXAlignment = Enum.TextXAlignment.Center,
            Visible = false, ZIndex = 6, Parent = holder,
        })
        local distLabel = new("TextLabel", {
            Name = "DistLabel", Size = UDim2.new(0, 160, 0, 12),
            BackgroundTransparency = 1, Font = Theme.Font,
            Text = "", TextColor3 = color, TextSize = 11,
            TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.new(0,0,0),
            TextXAlignment = Enum.TextXAlignment.Center,
            Visible = false, ZIndex = 6, Parent = holder,
        })
        local extraLabel = new("TextLabel", {
            Name = "ExtraLabel", Size = UDim2.new(0, 160, 0, 12),
            BackgroundTransparency = 1, Font = Theme.Font,
            Text = "", TextColor3 = color, TextSize = 11,
            TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0,0,0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Visible = false, ZIndex = 6, Parent = holder,
        })
        local bones = {}
        for i = 1, BONE_COUNT do
            bones[i] = new("Frame", {
                Name = "Bone" .. i,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(0, 1),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 4,
                Parent = holder,
            })
        end
        return {
            holder = holder, box = box, boxStroke = boxStroke, nameLabel = nameLabel,
            distLabel = distLabel, extraLabel = extraLabel,
            healthBg = healthBg, healthFill = healthFill,
            bones = bones, cham = nil,
        }
    end

    local function hideBones(d)
        local bones = d.bones
        if not bones then return end
        for i = 1, #bones do
            bones[i].Visible = false
        end
    end

    local function dropCham(d)
        local hl = d.cham
        if hl then
            d.cham = nil
            chamCount = math.max(0, chamCount - 1)
            pcall(function() hl:Destroy() end)
        end
    end

    local function hideDrawing(d)
        d.box.Visible = false
        d.nameLabel.Visible = false
        d.distLabel.Visible = false
        d.extraLabel.Visible = false
        d.healthBg.Visible = false
        hideBones(d)
        if d.cham then
            d.cham.Enabled = false
        end
    end

    -- Pooled. Walking in and out of range used to Destroy and rebuild eight
    -- Instances per target every time, which is why ESP churned on the edge
    -- of your max distance.
    local pool = {}
    local POOL_CAP = 120
    -- Hidden-but-kept window for a target that just left range or lost the
    -- on-view sort. Long enough to absorb flicker, short enough that walking
    -- away really does release the drawing.
    local ESP_GRACE = 0.8
    local graceUntil = {}

    local function makeDrawing(color)
        local d = table.remove(pool)
        if not d or not d.holder.Parent then
            return buildDrawing(color)
        end
        d.boxStroke.Color = color
        d.nameLabel.TextColor3 = color
        d.distLabel.TextColor3 = color
        d.extraLabel.TextColor3 = color
        if d.bones then
            for i = 1, #d.bones do
                d.bones[i].BackgroundColor3 = color
            end
        end
        hideDrawing(d)
        return d
    end

    local function removeDrawing(d)
        if not d then return end
        dropCham(d)
        if #pool >= POOL_CAP or not d.holder.Parent then
            pcall(function() d.holder:Destroy() end)
            return
        end
        hideDrawing(d)
        table.insert(pool, d)
    end

    local function boundsOf(obj: Instance): (Vector3?, number?)
        if obj:IsA("Model") then
            local ok, cf, size = pcall(function() return obj:GetBoundingBox() end)
            if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
                return cf.Position, size.Y
            end
        elseif obj:IsA("BasePart") then
            return obj.Position, obj.Size.Y
        end
        return nil, nil
    end

    local function paintHealthBar(d, hp01: number, x: number, y: number, h: number)
        local hp = math.clamp(hp01, 0, 1)
        d.healthBg.Size = UDim2.fromOffset(3, h)
        d.healthBg.Position = UDim2.fromOffset(x, y)
        d.healthBg.Visible = true
        d.healthFill.Size = UDim2.new(1, 0, hp, 0)
        d.healthFill.Position = UDim2.new(0, 0, 1 - hp, 0)
        d.healthFill.BackgroundColor3 = Color3.fromRGB(
            math.floor(255 * (1 - hp)), math.floor(255 * hp), 60)
    end

    local function paintResourceBar(d, hp01: number, cx: number, y: number, width: number)
        local hp = math.clamp(hp01, 0, 1)
        local w = math.max(width, 42)
        d.healthBg.Size = UDim2.fromOffset(w, 5)
        d.healthBg.Position = UDim2.fromOffset(cx - w / 2, y)
        d.healthBg.Visible = true
        d.healthFill.Size = UDim2.new(hp, 0, 1, 0)
        d.healthFill.Position = UDim2.fromOffset(0, 0)
        d.healthFill.BackgroundColor3 = Color3.fromRGB(
            math.floor(255 * (1 - hp)), math.floor(255 * hp), 60)
    end

    local function placeBone(frame: Frame, ax: number, ay: number, bx: number, by: number)
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 2 then
            frame.Visible = false
            return
        end
        frame.Size = UDim2.fromOffset(len, 1)
        frame.Position = UDim2.fromOffset((ax + bx) * 0.5, (ay + by) * 0.5)
        frame.Rotation = math.deg(math.atan2(dy, dx))
        frame.Visible = true
    end

    local function drawSkeleton(d, char: Model, cam: Camera)
        local bones = d.bones
        if not bones then return end
        local links = if char:FindFirstChild("UpperTorso") then R15_BONES else R6_BONES
        local used = 0
        for i = 1, #links do
            if used >= #bones then break end
            local a = char:FindFirstChild(links[i][1])
            local b = char:FindFirstChild(links[i][2])
            if a and a:IsA("BasePart") and b and b:IsA("BasePart") then
                local pa, oa = cam:WorldToViewportPoint(a.Position)
                local pb, ob = cam:WorldToViewportPoint(b.Position)
                if pa.Z > 0 and pb.Z > 0 and (oa or ob) then
                    used += 1
                    placeBone(bones[used], pa.X, pa.Y, pb.X, pb.Y)
                end
            end
        end
        for i = used + 1, #bones do
            bones[i].Visible = false
        end
    end

    local function setCham(d, char: Model?, allow: boolean)
        if not allow or not char or not State.PlayerChams then
            if d.cham then
                d.cham.Enabled = false
            end
            return
        end
        local hl = d.cham
        if not hl or not hl.Parent then
            if chamCount >= CHAM_CAP then
                return
            end
            hl = Instance.new("Highlight")
            hl.Name = "TroyHubCham"
            hl.FillColor = PLAYER_COLOR
            hl.OutlineColor = Color3.fromRGB(255, 220, 220)
            hl.FillTransparency = 0.55
            hl.OutlineTransparency = 0.15
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = espFolder
            d.cham = hl
            chamCount += 1
        end
        hl.Adornee = char
        hl.Enabled = true
    end

    local STAT_ALIASES = {
        gold = { "Gold", "Money", "Cash", "Coins", "Currency" },
        job = { "Job", "Class", "Occupation", "Profession", "Role", "Career" },
        age = { "Age", "Years" },
        deaths = { "Deaths", "Death", "Downs" },
    }
    local statCache: { [Player]: any } = {}

    local function valueFrom(inst: Instance, name: string): any?
        local okAttr, attr = pcall(function()
            return inst:GetAttribute(name)
        end)
        if okAttr and attr ~= nil then
            return attr
        end
        local child = inst:FindFirstChild(name)
        if child and child:IsA("ValueBase") then
            return (child :: any).Value
        end
        return nil
    end

    local function scanStat(plr: Player, aliases: { string }): any?
        local char = plr.Character
        local roots: { Instance } = { plr }
        local ls = plr:FindFirstChild("leaderstats")
        if ls then table.insert(roots, ls) end
        for _, name in { "Stats", "Data", "Info", "Values", "PlayerData" } do
            local folder = plr:FindFirstChild(name)
            if folder then table.insert(roots, folder) end
        end
        if char then table.insert(roots, char) end
        for _, root in roots do
            for _, alias in aliases do
                local v = valueFrom(root, alias)
                if v ~= nil and v ~= "" then
                    return v
                end
            end
            for _, child in root:GetChildren() do
                if child:IsA("Folder") or child:IsA("Configuration") then
                    for _, alias in aliases do
                        local v = valueFrom(child, alias)
                        if v ~= nil and v ~= "" then
                            return v
                        end
                    end
                end
            end
        end
        return nil
    end

    local function playerStats(plr: Player): any
        local now = os.clock()
        local cached = statCache[plr]
        if cached and now - cached.at < 0.45 then
            return cached
        end
        local pack = {
            at = now,
            gold = scanStat(plr, STAT_ALIASES.gold),
            job = scanStat(plr, STAT_ALIASES.job),
            age = scanStat(plr, STAT_ALIASES.age),
            deaths = scanStat(plr, STAT_ALIASES.deaths),
        }
        statCache[plr] = pack
        return pack
    end

    local function fmtStat(v: any): string
        if type(v) == "number" then
            if v >= 10000 then
                return string.format("%.1fk", v / 1000)
            end
            if v == math.floor(v) then
                return tostring(math.floor(v))
            end
            return string.format("%.1f", v)
        end
        return tostring(v)
    end

    local HP_KEYS = { "Health", "HP", "Hits", "Durability", "Lives", "Remaining" }
    local MAX_KEYS = { "MaxHealth", "MaxHP", "MaxHits", "MaxDurability", "Max" }
    local resourceHP: { [Instance]: { hp: number, max: number, vol: number } } = {}

    local function parseHpPair(v: any): (number?, number?)
        if type(v) == "number" then
            return v, nil
        end
        if type(v) == "string" then
            local a, b = string.match(v, "(%d+)%s*/%s*(%d+)")
            if a and b then
                return tonumber(a), tonumber(b)
            end
            return tonumber(v), nil
        end
        return nil, nil
    end

    local function volumeOf(obj: Instance): number
        if obj:IsA("BasePart") then
            local s = obj.Size
            return s.X * s.Y * s.Z
        end
        if obj:IsA("Model") then
            local ok, _cf, size = pcall(function()
                return obj:GetBoundingBox()
            end)
            if ok and typeof(size) == "Vector3" then
                return size.X * size.Y * size.Z
            end
        end
        return 0
    end

    local function looksBarName(name: string): boolean
        local n = string.lower(name)
        return string.find(n, "health", 1, true) ~= nil
            or string.find(n, "hp", 1, true) ~= nil
            or string.find(n, "fill", 1, true) ~= nil
            or string.find(n, "bar", 1, true) ~= nil
            or string.find(n, "progress", 1, true) ~= nil
    end

    local function readBillboardHealth(root: Instance): (number?, number?)
        for _, gui in root:GetDescendants() do
            if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then
                for _, g in gui:GetDescendants() do
                    if g:IsA("TextLabel") or g:IsA("TextBox") then
                        local a, b = parseHpPair(g.Text)
                        if a and b and b > 0 then
                            return a, b
                        end
                    end
                end
                local namedScale: number? = nil
                local anyScale: number? = nil
                local namedAbs: number? = nil
                local namedAbsMax: number? = nil
                for _, g in gui:GetDescendants() do
                    if g:IsA("GuiObject") then
                        local sx = g.Size.X.Scale
                        if sx > 0.01 and sx <= 1.001 then
                            if looksBarName(g.Name) then
                                namedScale = sx
                            elseif sx < 0.999 then
                                anyScale = sx
                            end
                        end
                        if looksBarName(g.Name) and g.Parent and g.Parent:IsA("GuiObject") then
                            local pw = (g.Parent :: GuiObject).AbsoluteSize.X
                            local cw = g.AbsoluteSize.X
                            if pw > 4 and cw >= 0 and cw <= pw + 1 then
                                namedAbs = cw
                                namedAbsMax = pw
                            end
                        end
                    end
                end
                if namedScale then
                    return namedScale, 1
                end
                if namedAbs and namedAbsMax then
                    return namedAbs, namedAbsMax
                end
                if anyScale then
                    return anyScale, 1
                end
            end
        end
        return nil, nil
    end

    local function resourceHealth(obj: Instance): (number?, number?)
        local rec = resourceHP[obj]
        local hp, maxHp
        local roots = { obj }
        if obj.Parent and obj.Parent ~= workspace then
            table.insert(roots, obj.Parent)
        end
        for _, root in roots do
            local a, b = readBillboardHealth(root)
            if a then
                hp, maxHp = a, b
                break
            end
            for _, key in HP_KEYS do
                local va, vb = parseHpPair(valueFrom(root, key))
                if va then
                    hp = va
                    maxHp = vb
                    break
                end
            end
            if hp then break end
        end
        if not maxHp then
            for _, root in roots do
                for _, key in MAX_KEYS do
                    local a = parseHpPair(valueFrom(root, key))
                    if a then
                        maxHp = a
                        break
                    end
                end
                if maxHp then break end
            end
        end
        local vol = volumeOf(obj)
        if not rec then
            rec = { hp = hp or 1, max = maxHp or hp or 1, vol = math.max(vol, 0.01) }
            resourceHP[obj] = rec
        end
        if vol > rec.vol then
            rec.vol = vol
        end
        if hp then
            rec.hp = hp
            if maxHp then
                rec.max = math.max(maxHp, hp)
            elseif hp > rec.max then
                rec.max = hp
            end
            return rec.hp, rec.max
        end
        if vol > 0 and rec.vol > 0 and vol < rec.vol * 0.98 then
            return vol, rec.vol
        end
        return nil, nil
    end

    local function renderDrawing(d, worldPos, heightStuds, distance, displayName, kind, info)
        local cam = workspace.CurrentCamera
        if not cam then hideDrawing(d); return end
        local center = cam:WorldToViewportPoint(worldPos)
        if center.Z <= 0 then hideDrawing(d); return end
        local topPt = cam:WorldToViewportPoint(worldPos + Vector3.new(0, heightStuds / 2, 0))
        local bottomPt = cam:WorldToViewportPoint(worldPos - Vector3.new(0, heightStuds / 2, 0))
        local heightPx = math.abs(topPt.Y - bottomPt.Y)
        if heightPx > 4000 then hideDrawing(d); return end
        local boxY = math.min(topPt.Y, bottomPt.Y)
        if heightPx < 8 then
            heightPx = 8
            boxY = center.Y - 4
        end
        local widthPx = math.max(heightPx * 0.55, 16)
        local isPlayer = kind == "player"
        info = info or {}

        if (isPlayer and State.PlayerBox) or (not isPlayer and State.ResourceBox) then
            d.box.Size = UDim2.fromOffset(widthPx, heightPx)
            d.box.Position = UDim2.fromOffset(center.X - widthPx / 2, boxY)
            d.box.Visible = true
        else
            d.box.Visible = false
        end

        if (isPlayer and State.PlayerName) or (not isPlayer and State.ResourceName) then
            d.nameLabel.Text = displayName
            d.nameLabel.Position = UDim2.fromOffset(center.X - 90, boxY - 16)
            d.nameLabel.Visible = true
        else
            d.nameLabel.Visible = false
        end

        if (isPlayer and State.PlayerDistance) or (not isPlayer and State.ResourceDistance) then
            d.distLabel.Text = string.format("%dm", math.floor(distance + 0.5))
            local distY = boxY + heightPx + 2
            if not isPlayer and State.ResourceHealth then
                distY += 8
            end
            d.distLabel.Position = UDim2.fromOffset(center.X - 80, distY)
            d.distLabel.Visible = true
        else
            d.distLabel.Visible = false
        end

        local lines = {}
        local hp01 = nil :: number?
        if isPlayer then
            local humanoid = info.humanoid
            if humanoid and humanoid:IsA("Humanoid") then
                local cur = humanoid.Health
                local maxh = math.max(humanoid.MaxHealth, 1)
                hp01 = math.clamp(cur / maxh, 0, 1)
                if State.PlayerHealthText then
                    table.insert(lines, string.format("Health %d/%d", math.floor(cur), math.floor(maxh)))
                end
            end
            if State.PlayerHealth and hp01 then
                paintHealthBar(d, hp01, center.X + widthPx / 2 + 3, boxY, heightPx)
            else
                d.healthBg.Visible = false
            end
            local plr = info.player
            if plr and typeof(plr) == "Instance" then
                local stats = playerStats(plr)
                if State.PlayerDeaths and stats.deaths ~= nil then
                    table.insert(lines, "Deaths " .. fmtStat(stats.deaths))
                end
                if State.PlayerGold and stats.gold ~= nil then
                    table.insert(lines, "Gold " .. fmtStat(stats.gold))
                end
                if State.PlayerJob and stats.job ~= nil then
                    table.insert(lines, "Job " .. fmtStat(stats.job))
                end
                if State.PlayerAge and stats.age ~= nil then
                    table.insert(lines, "Age " .. fmtStat(stats.age))
                end
            end
            if State.PlayerSkeleton and info.character and info.character:IsA("Model") then
                drawSkeleton(d, info.character, cam)
            else
                hideBones(d)
            end
            setCham(d, if info.character and info.character:IsA("Model") then info.character else nil, info.cham == true)
        else
            hideBones(d)
            setCham(d, nil, false)
            local res = info.resource
            local hp, maxh
            if res and res:IsA("Instance") then
                hp, maxh = resourceHealth(res)
            end
            if hp and maxh and maxh > 0 then
                hp01 = math.clamp(hp / maxh, 0, 1)
            end
            if State.ResourceHealth and hp01 then
                local barY = boxY + heightPx + 2
                paintResourceBar(d, hp01, center.X, barY, math.max(widthPx, 48))
                if State.ResourceDistance then
                    -- Keep distance under the bar instead of covering it.
                end
            else
                d.healthBg.Visible = false
            end
            if State.ResourceHealthText and hp and maxh then
                if maxh <= 1.001 then
                    table.insert(lines, string.format("HP %d%%", math.floor(hp01 and hp01 * 100 or 0)))
                else
                    table.insert(lines, string.format("HP %s/%s", fmtStat(hp), fmtStat(maxh)))
                end
            end
        end

        if #lines > 0 then
            d.extraLabel.Text = table.concat(lines, "\n")
            d.extraLabel.Size = UDim2.fromOffset(160, #lines * 13)
            d.extraLabel.Position = UDim2.fromOffset(center.X + widthPx / 2 + 10, boxY)
            d.extraLabel.Visible = true
        else
            d.extraLabel.Visible = false
        end
    end

    function ESP.step()
        if Flags.Unloading then return end
        -- Both ESP modes off: drop any leftover drawings once, then do no
        -- per-frame work at all instead of rebuilding tables every frame.
        if not State.PlayerESP and not State.ResourceESP then
            if next(drawings) ~= nil then
                for inst, d in drawings do
                    removeDrawing(d)
                    drawings[inst] = nil
                end
                table.clear(graceUntil)
                table.clear(statCache)
            end
            return
        end
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local myPos = (myRoot and myRoot:IsA("BasePart")) and myRoot.Position or Vector3.zero
        local activeSet = {}

        if State.PlayerESP then
            local players = {}
            for _, plr in Players:GetPlayers() do
                local char = plr.Character
                if plr ~= player and char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hrp and hrp:IsA("BasePart") and hum and hum:IsA("Humanoid") and hum.Health > 0 then
                        local pos, height = boundsOf(char)
                        if not pos or not height then pos, height = hrp.Position, 5 end
                        local dist = (pos - myPos).Magnitude
                        if dist <= clampNum(State.PlayerMaxDist, 50, 2000, 700) then
                            table.insert(players, {
                                plr = plr, char = char, hum = hum,
                                pos = pos, height = height, dist = dist,
                            })
                        end
                    end
                end
            end
            table.sort(players, function(a, b)
                return a.dist < b.dist
            end)
            for i, row in players do
                activeSet[row.plr] = true
                local d = drawings[row.plr]
                if not d then
                    d = makeDrawing(PLAYER_COLOR)
                    drawings[row.plr] = d
                end
                renderDrawing(d, row.pos, row.height, row.dist, row.plr.Name, "player", {
                    humanoid = row.hum,
                    character = row.char,
                    player = row.plr,
                    cham = i <= CHAM_CAP,
                })
            end
        end

        if State.ResourceESP then
            ResourceScanner.discover()
            local candidates = {}
            local maxDist = math.max(clampNum(State.ResourceMaxDist, 25, 1000, 500), 50)
            local maxD2 = maxDist * maxDist
            local cam = workspace.CurrentCamera
            local view = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            -- Grid query: only the cells within ESP range are touched, instead
            -- of every indexed node on the map every frame.
            ResourceScanner.queryRadius(myPos, maxDist * 1.3, function(entry)
                local obj = entry.inst
                if not obj.Parent then return end
                local kind = entry.kind
                if not (kind and State.ResourceTypeFilter[kind]) then return end
                local rough = entry.pos
                local rdx, rdy, rdz = rough.X - myPos.X, rough.Y - myPos.Y, rough.Z - myPos.Z
                if rdx * rdx + rdy * rdy + rdz * rdz > maxD2 * 1.6 then return end
                local pos = scanPos(obj)
                if pos then
                    ResourceScanner.reposition(entry, pos)
                else
                    pos = entry.pos
                end
                local dx, dy, dz = pos.X - myPos.X, pos.Y - myPos.Y, pos.Z - myPos.Z
                local d2 = dx * dx + dy * dy + dz * dz
                if d2 > maxD2 then return end
                local dist = math.sqrt(d2)
                local onView = false
                if cam then
                    local sp, vis = cam:WorldToViewportPoint(pos)
                    onView = sp.Z > 0 and vis == true
                    if not onView and sp.Z > 0 then
                        onView = sp.X > -80 and sp.Y > -80 and sp.X < view.X + 80 and sp.Y < view.Y + 80
                    end
                end
                local _p, height = boundsOf(obj)
                table.insert(candidates, {
                    inst = obj, kind = kind, pos = pos,
                    dist = dist, height = height or 5, onView = onView,
                })
            end)
            table.sort(candidates, function(a, b)
                if a.onView ~= b.onView then return a.onView end
                return a.dist < b.dist
            end)
            local maxN = math.floor(clampNum(State.ResourceLimit, 1, 500, 80))
            for i = 1, math.min(#candidates, maxN) do
                local c = candidates[i]
                activeSet[c.inst] = true
                local d = drawings[c.inst]
                if not d then
                    d = makeDrawing(RESOURCE_COLOR)
                    drawings[c.inst] = d
                end
                renderDrawing(d, c.pos, c.height, c.dist, c.kind, "resource", {
                    resource = c.inst,
                })
            end
        end

        -- Grace period. A target hovering at the distance limit, or one that
        -- lost the on-view sort by a place or two, used to churn a drawing per
        -- frame. Hold it hidden for a moment instead, so a target that comes
        -- straight back reuses the same drawing with no allocation at all.
        local now = os.clock()
        for inst, d in drawings do
            if activeSet[inst] then
                graceUntil[inst] = nil
            else
                local expiry = graceUntil[inst]
                if not expiry then
                    graceUntil[inst] = now + ESP_GRACE
                    hideDrawing(d)
                elseif now >= expiry then
                    graceUntil[inst] = nil
                    if typeof(inst) == "Instance" and inst:IsA("Player") then
                        statCache[inst] = nil
                    elseif typeof(inst) == "Instance" then
                        resourceHP[inst] = nil
                    end
                    removeDrawing(d)
                    drawings[inst] = nil
                end
            end
        end
    end

    Scheduler.add("esp", "render", 0, ESP.step)
end

-- ============================================================
--  AIMBOT + FOV CIRCLE
-- ============================================================
do
    local fovGui = new("ScreenGui", {
        Name = "TroyHubFOV", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 997,
        Parent = playerGui,
    })
    fovCircleGui = fovGui
    fovCircle = new("Frame", {
        Size = UDim2.fromOffset(State.FOVRadius * 2, State.FOVRadius * 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = fovGui,
    })
    local circleCorner = corner(State.FOVRadius, fovCircle)
    local circleStroke = stroke(State.FOVColor, 1, fovCircle)
    circleStroke.Transparency = 0.2

    local indicator = new("Frame", {
        Name = "TargetIndicator", Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Danger,
        BorderSizePixel = 0, Visible = false, Parent = fovGui,
    })
    corner(5, indicator)

    -- Cached with an expiry so the table cannot grow for a whole session and
    -- so a friend added mid-game is picked up.
    local friendCache = {}
    local function isFriend(plr): boolean
        local now = os.clock()
        local entry = friendCache[plr.UserId]
        if entry and now < entry.expires then return entry.value end
        friendCache[plr.UserId] = { value = entry and entry.value or false, expires = now + 120 }
        task.spawn(function()
            local ok, res = pcall(function() return player:IsFriendsWith(plr.UserId) end)
            friendCache[plr.UserId] = { value = ok and res == true, expires = os.clock() + 120 }
        end)
        return friendCache[plr.UserId].value
    end

    local function hasLineOfSight(cam, part: BasePart, char: Model): boolean
        local origin = cam.CFrame.Position
        local delta = part.Position - origin
        if delta.Magnitude < 0.01 then return true end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = { char }
        if player.Character then table.insert(ignore, player.Character) end
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = true
        return workspace:Raycast(origin, delta, params) == nil
    end

    local function aimCenter(cam): Vector2
        if State.FOVFollowMouse then
            local m = UserInputService:GetMouseLocation()
            return Vector2.new(m.X, m.Y)
        end
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end

    local function getAimTarget(cam): BasePart?
        local myChar = player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot or not myRoot:IsA("BasePart") then return nil end
        local center = aimCenter(cam)
        local best: BasePart? = nil
        local bestScore = math.huge

        for _, plr in Players:GetPlayers() do
            if plr ~= player then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and hum and hum:IsA("Humanoid") then
                    local skip = false
                    if State.AliveCheck and hum.Health <= 0 then skip = true end
                    if not skip and State.TeamCheck and player.Team ~= nil and plr.Team == player.Team then
                        skip = true
                    end
                    if not skip and State.FriendCheck and isFriend(plr) then skip = true end

                    local part = not skip and char:FindFirstChild(State.AimPart) or nil
                    if part and part:IsA("BasePart") then
                        if (part.Position - myRoot.Position).Magnitude <= clampNum(State.AimMaxDist, 10, 5000, 300) then
                            local screenPos = cam:WorldToViewportPoint(part.Position)
                            if screenPos.Z > 0 then
                                local r = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                                local inFov = not State.FOVCheck or r <= clampNum(State.FOVRadius, 10, 2000, 120)
                                if inFov and r < bestScore then
                                    if not State.WallCheck or hasLineOfSight(cam, part, char) then
                                        best, bestScore = part, r
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local aimHeld = false
    local aimToggled = false
    track(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if inputMatches(input, State.AimKeyCode) then
            aimHeld = true
            if State.AimKey == "Toggle" then aimToggled = not aimToggled end
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if inputMatches(input, State.AimKeyCode) then aimHeld = false end
    end))

    local function aimEnabled(): boolean
        if not State.AimboT then return false end
        if State.AimKey == "Hold" then return aimHeld end
        if State.AimKey == "Toggle" then return aimToggled end
        return true
    end

    -- Velocity sampled from replicated position, not from the part's own
    -- AssemblyLinearVelocity. For a remote character that property is often
    -- zero or a frame stale, which is exactly why linear prediction looked
    -- wrong on strafing targets. Smoothed so a single late packet does not
    -- throw the lead sideways.
    local velSample = {
        part = nil :: BasePart?,
        pos = Vector3.zero,
        at = 0,
        vel = Vector3.zero,
        accel = Vector3.zero,
    }

    local function sampledVelocity(target: BasePart): (Vector3, Vector3)
        local now = os.clock()
        local pos = target.Position
        if velSample.part ~= target or (now - velSample.at) > 0.5 then
            velSample.part = target
            velSample.pos = pos
            velSample.at = now
            velSample.vel = target.AssemblyLinearVelocity
            velSample.accel = Vector3.zero
            return velSample.vel, velSample.accel
        end
        local dt = now - velSample.at
        if dt < 1 / 120 then return velSample.vel, velSample.accel end
        local measured = (pos - velSample.pos) / dt
        local prev = velSample.vel
        velSample.pos = pos
        velSample.at = now
        velSample.vel = velSample.vel:Lerp(measured, 0.35)
        -- Acceleration from the smoothed velocity, not the raw packet delta,
        -- so a single stutter does not invent a 200-stud dodge.
        velSample.accel = velSample.accel:Lerp((velSample.vel - prev) / dt, 0.25)
        return velSample.vel, velSample.accel
    end

    -- Lead the shot. Strength is expressed in hundredths of a second of travel
    -- so the slider reads as "how far ahead", and it scales with range because
    -- a distant target drifts further across the screen in the same time.
    local function predictedAim(target: BasePart, camPos: Vector3): Vector3
        local pos = target.Position
        if not State.AimPrediction then return pos end
        local vel, accel = sampledVelocity(target)
        if vel.Magnitude < 1 then return pos end
        local lead = clampNum(State.AimPredictStrength, 0, 60, 12) / 100
        local range = (pos - camPos).Magnitude
        lead *= math.clamp(range / 150, 0.4, 2.5)
        -- Quadratic term is what actually tracks a strafe instead of aiming
        -- where they were. Vertical is still damped: jump arcs are short.
        local pred = pos
            + Vector3.new(vel.X, vel.Y * 0.25, vel.Z) * lead
            + Vector3.new(accel.X, 0, accel.Z) * (0.5 * lead * lead)
        return pred
    end

    -- Linear lerp toward the target snaps hard on the first frame and then
    -- crawls, which is the recognisable aimbot shape. These ease the approach
    -- based on how far off-target the camera currently is.
    local function easedAlpha(base: number, offAngle: number): number
        local curve = State.AimCurve
        if curve == "Linear" then
            return base
        end
        -- Normalised error: 0 when already on target, 1 at roughly 60 degrees.
        local err = math.clamp(offAngle / 1.05, 0, 1)
        if curve == "Human" then
            -- Slow start, quick middle, slow settle, plus a little tremor so
            -- the track is never perfectly smooth.
            local s = err * err * (3 - 2 * err)
            local jitter = 0.85 + math.random() * 0.3
            return math.clamp(base * s * 1.8 * jitter, base * 0.15, 1)
        end
        -- "Ease": accelerate out of the current error, decelerate into target.
        return math.clamp(base * (0.35 + err * 1.3), base * 0.2, 1)
    end

    Scheduler.add("aimbot", "render", 0, function()
        if Flags.Unloading then return end
        local cam = workspace.CurrentCamera

        if cam and State.ShowFOVCircle and State.AimboT then
            local radius = clampNum(State.FOVRadius, 10, 2000, 120)
            local diameter = radius * 2
            fovCircle.Size = UDim2.fromOffset(diameter, diameter)
            circleCorner.CornerRadius = UDim.new(0, radius)
            circleStroke.Color = State.FOVColor
            local c = aimCenter(cam)
            fovCircle.Position = UDim2.fromOffset(c.X, c.Y)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end

        if not cam or not aimEnabled() then
            indicator.Visible = false
            return
        end

        local target = getAimTarget(cam)
        if not target then
            indicator.Visible = false
            return
        end

        if State.TargetIndicator then
            local sp = cam:WorldToViewportPoint(target.Position)
            indicator.Position = UDim2.fromOffset(sp.X, sp.Y)
            indicator.Visible = sp.Z > 0
        else
            indicator.Visible = false
        end

        local cf = cam.CFrame
        local aimPoint = predictedAim(target, cf.Position)
        local toTarget = aimPoint - cf.Position
        if toTarget.Magnitude < 0.05 then return end
        local goal = CFrame.lookAt(cf.Position, aimPoint)
        local smooth = clampNum(State.Smoothness, 0, 100, 0)
        if smooth <= 0 then
            cam.CFrame = goal
            return
        end
        local base = math.clamp(1 / math.max(smooth, 1), 0.02, 1)
        local dot = math.clamp(cf.LookVector:Dot(toTarget.Unit), -1, 1)
        cam.CFrame = cf:Lerp(goal, easedAlpha(base, math.acos(dot)))
    end)

    aimbotCleanup = function()
        Scheduler.remove("aimbot")
        if fovGui then pcall(function() fovGui:Destroy() end) end
        fovCircleGui = nil
        fovCircle = nil
    end
end

-- ============================================================
--  GATHER BACKEND
-- ============================================================
local function getRoot(): BasePart?
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return nil
end

local function getHumanoid(): Humanoid?
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum:IsA("Humanoid") then return hum end
    return nil
end

local function flatDist(a: Vector3, b: Vector3): number
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

-- Prefer the trunk/base, never the canopy. The biggest part on a Tree is the
-- leaf ball, whose center sits ~15 studs up — you can stand under it forever
-- and never enter an 8-stud 3D stop range, so gather never fires.
local function liveHarvestPart(obj: Instance): BasePart?
    if obj:IsA("BasePart") then
        if obj.Parent and obj.Size.Magnitude >= 0.4 then return obj end
        return nil
    end
    if not obj:IsA("Model") then return nil end
    local bestTrunk: BasePart? = nil
    local bestTrunkY = math.huge
    local bestAny: BasePart? = nil
    local bestAnyY = math.huge
    for _, d in obj:GetDescendants() do
        if d:IsA("BasePart") and d.Size.Magnitude >= 0.4 then
            local bottom = d.Position.Y - d.Size.Y * 0.5
            if bottom < bestAnyY then
                bestAny = d
                bestAnyY = bottom
            end
            if d.Size.Y >= d.Size.X * 0.7 and d.Size.Y >= d.Size.Z * 0.7 then
                if bottom < bestTrunkY then
                    bestTrunk = d
                    bestTrunkY = bottom
                end
            end
        end
    end
    return bestTrunk or bestAny
end

local function flatLook(fromPos: Vector3, targetPos: Vector3): CFrame
    local at = Vector3.new(targetPos.X, fromPos.Y, targetPos.Z)
    if (at - fromPos).Magnitude < 0.05 then return CFrame.new(fromPos) end
    return CFrame.lookAt(fromPos, at)
end

local movementLocked = false
local Farm = {
    dest = nil :: Vector3?,
    look = nil :: Vector3?,
    mining = false,
    skipUntil = {} :: { [Instance]: number },
    recentMines = {} :: { { pos: Vector3, expires: number } },
}

cancelMoveTween = function()
    Farm.dest = nil
    Farm.look = nil
    Farm.mining = false
end

-- Anchoring the root is the reliable way to stay on a node, and also the most
-- visible thing the hub does. So it is rationed: hold for PinMax seconds, then
-- rest, and fall back to re-asserting the CFrame every swing pass instead.
local Pin = { since = 0, restUntil = 0, drifted = 0 }

local function pinAllowed(): boolean
    -- Anchored roots are ignored by Gathering. Teleport Gather holds pose
    -- with CFrame writes instead of a pin.
    if State.TeleportGather then return false end
    if State.UsePin ~= true then return false end
    -- Never drop the pin mid-cluster. High ping plus an unanchored CFrame hold
    -- is exactly the slide-off you already solved with the pin.
    if Farm.mining and movementLocked then return true end
    local now = os.clock()
    if now < Pin.drifted then return true end
    if now < Pin.restUntil then return false end
    local cap = clampNum(State.PinMax, 0, 600, 6)
    if cap <= 0 then return false end
    if Pin.since > 0 and (now - Pin.since) >= cap then
        Pin.restUntil = now + 1.2
        return false
    end
    return true
end

-- Called from pinAt each swing pass. Two consecutive passes where the CFrame
-- write failed to hold means the unanchored path is not working here.
local function notePinDrift(distance: number)
    if distance > 2.5 then
        Pin.drifted = os.clock() + 2.5
    end
end

local function lockMovement()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum:IsA("Humanoid") and hum.Health <= 0 then return end
    local root = getRoot()
    if not root then return end
    if not root.Anchored then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    root.Anchored = true
    movementLocked = true
    if Pin.since == 0 then Pin.since = os.clock() end
end

unlockMovement = function()
    Pin.since = 0
    if not movementLocked then return end
    movementLocked = false
    local root = getRoot()
    if not root then return end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.Anchored = false
end

-- Safety net: never leave the root anchored once the farm stops needing it.
Scheduler.add("unlockguard", "logic", 0.1, function()
    if Flags.Unloading then return end
    if movementLocked and not Farm.mining and Farm.dest == nil then
        unlockMovement()
    end
    local hum = getHumanoid()
    if movementLocked and (not hum or hum.Health <= 0) then
        unlockMovement()
    end
end)

-- While mining with the anchor released, re-assert the stand pose between
-- swings. A 0.12s HIT_GAP is long enough to slide off on high ping; this
-- job is the unanchored hold. If even this loses, notePinDrift re-takes
-- the actual pin for 2.5s.
Scheduler.add("pinhold", "logic", 0, function()
    if Flags.Unloading or not Farm.mining then return end
    local dest, look = Farm.dest, Farm.look
    if not dest or not look then return end
    local root = getRoot()
    if not root then return end
    if not root.Anchored then
        notePinDrift(flatDist(root.Position, dest))
        if pinAllowed() then
            lockMovement()
        end
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = flatLook(dest, look)
end)

local GatherRemote: Instance? = nil
local marketRemote: RemoteEvent? = nil
local ResourcesFolder: Instance? = nil
local resourceWatchBound = false

local function bindResourceWatchers(folder: Instance)
    if resourceWatchBound then return end
    resourceWatchBound = true
    track(folder.DescendantAdded:Connect(function(obj)
        ResourceScanner.consider(obj)
        local p = obj.Parent
        if p then ResourceScanner.consider(p) end
    end))
    track(folder.DescendantRemoving:Connect(function(obj)
        if farmStore.byInst[obj] then
            ResourceScanner.drop(obj)
        end
    end))
    ResourceScanner.buildCache(folder)
end

local remotesWatchBound = false

-- Exact-name lookup in one folder was the only search. A game update that
-- renames the folder or nests the remote deeper killed the farm silently.
local REMOTE_HOSTS = { "Remotes", "Events", "RemoteEvents", "Network", "Packages", "Modules" }

local function findRemote(names: { string }, wantEvent: boolean): Instance?
    local function accept(inst: Instance): boolean
        if wantEvent then
            return inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")
        end
        return inst:IsA("RemoteEvent")
    end
    for _, host in REMOTE_HOSTS do
        local folder = ReplicatedStorage:FindFirstChild(host)
        if folder then
            for _, want in names do
                local hit = folder:FindFirstChild(want)
                if hit and accept(hit) then return hit end
            end
        end
    end
    for _, want in names do
        local hit = ReplicatedStorage:FindFirstChild(want, true)
        if hit and accept(hit) then return hit end
    end
    return nil
end

local bindHealth = { gatherLostAt = 0, folderLostAt = 0, warnedAt = 0 }

local function tryBindGather()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes and not remotesWatchBound then
        remotesWatchBound = true
        track(remotes.ChildAdded:Connect(function() tryBindGather() end))
    end
    -- Re-resolve anything the game took away instead of dying silently. A
    -- vanished remote usually means the game shipped an update, which is worth
    -- telling the user about rather than leaving the farm silently idle.
    if GatherRemote and not GatherRemote.Parent then
        log("Gathering remote disappeared — rebinding")
        Notifications.warn("Gather remote lost", "The game moved or renamed it. Searching…")
        GatherRemote = nil
        bindHealth.gatherLostAt = os.clock()
    end
    if marketRemote and not marketRemote.Parent then
        if State.AutoSell then
            Notifications.warn("Sell remote lost", "Auto Sell is paused until it is found")
        end
        marketRemote = nil
    end
    if not GatherRemote then
        local g = findRemote({ "Gathering", "Gather", "GatherResource" }, true)
        if g then
            GatherRemote = g
            log("Gathering remote bound (" .. g.ClassName .. " @ " .. g:GetFullName() .. ")")
            if bindHealth.gatherLostAt > 0 then
                Notifications.success("Gather remote", "Rebound to " .. g.Name)
                bindHealth.gatherLostAt = 0
            end
        end
    end
    if not marketRemote then
        local m = findRemote({ "Market", "Sell", "SellResource" }, false)
        if m and m:IsA("RemoteEvent") then
            marketRemote = m
        end
    end
    if ResourcesFolder and not ResourcesFolder.Parent then
        log("Resources folder disappeared — rebinding")
        Notifications.warn("Resources folder lost", "Rebuilding the node index")
        ResourcesFolder = nil
        resourceWatchBound = false
        ResourceScanner.reset()
        bindHealth.folderLostAt = os.clock()
    end
    if not ResourcesFolder then
        local folder = workspace:FindFirstChild("Resources")
        if folder then
            ResourcesFolder = folder
            bindResourceWatchers(folder)
            log("Resources folder bound (" .. #folder:GetChildren() .. " items)")
            if bindHealth.folderLostAt > 0 then
                Notifications.success("Resources folder", "Reindexing " .. #folder:GetChildren() .. " items")
                bindHealth.folderLostAt = 0
            end
        end
    end
end

-- One nag, not one per retry: if the farm has been on and starved of a remote
-- for a while, the game has almost certainly changed and the user should know.
Scheduler.add("bindhealth", "logic", 5, function()
    if Flags.Unloading then return end
    local farmOn = State.AutoGather or State.TeleportGather or State.GatherAround or State.LegitMode
    if not farmOn then
        bindHealth.warnedAt = 0
        return
    end
    local missing = (not GatherRemote) or (not ResourcesFolder)
    if not missing then
        bindHealth.warnedAt = 0
        return
    end
    local now = os.clock()
    if now - bindHealth.warnedAt < 60 then return end
    bindHealth.warnedAt = now
    local what = if not GatherRemote then "gather remote" else "Resources folder"
    Notifications.error("Farm stalled", "Cannot find the " .. what .. ". The game may have updated.", 6)
end)

tryBindGather()
track(ReplicatedStorage.ChildAdded:Connect(function() tryBindGather() end))
track(workspace.ChildAdded:Connect(function() tryBindGather() end))
task.spawn(function()
    for _ = 1, 40 do
        if Flags.Unloading then return end
        tryBindGather()
        if GatherRemote and ResourcesFolder then return end
        task.wait(0.5)
    end
    if not GatherRemote then log("Gathering remote not found — farm waiting") end
    if not ResourcesFolder then log("Resources folder not found — farm waiting") end
end)

local function listedNearby(maxDist: number, maxN: number?)
    local root = getRoot()
    if not root then return {} end
    local myPos = root.Position
    local maxD2 = maxDist * maxDist
    local out = {}
    ResourceScanner.queryRadius(myPos, maxDist, function(e)
        local inst = e.inst
        if not inst.Parent then
            ResourceScanner.drop(inst)
            return
        end
        if not State.ResourcesToCollect[e.kind] then return end
        local pos = e.pos
        local dx, dz = pos.X - myPos.X, pos.Z - myPos.Z
        local d2 = dx * dx + dz * dz
        if d2 <= maxD2 then
            table.insert(out, { inst = inst, kind = e.kind, dist = math.sqrt(d2), pos = pos })
        end
    end)
    table.sort(out, function(a, b) return a.dist < b.dist end)
    if maxN and #out > maxN then
        local trimmed = {}
        for i = 1, maxN do trimmed[i] = out[i] end
        return trimmed
    end
    return out
end

-- Score is distance minus a priority bonus, so a high-value node stays worth
-- travelling for. PriorityWeight is studs of detour each priority point buys.
local function nodeScore(kind: string, dist: number): number
    local pri = State.ResourcePriority[kind]
    if type(pri) ~= "number" then pri = 0 end
    return dist - pri * clampNum(State.PriorityWeight, 0, 400, 40)
end

-- Rings out from the player instead of scoring all 10k nodes. The first ring
-- that yields a candidate wins, which is also what keeps travel short.
local NEAREST_RINGS = { 120, 400, 1200, 4000 }

local function nearestListed()
    local root = getRoot()
    if not root then return nil end
    local myPos = root.Position
    local now = os.clock()
    for inst, untilT in Farm.skipUntil do
        if not inst.Parent or now >= untilT then
            Farm.skipUntil[inst] = nil
        end
    end
    for _, ring in NEAREST_RINGS do
        local best = nil
        local bestScore = math.huge
        local ring2 = ring * ring
        ResourceScanner.queryRadius(myPos, ring, function(e)
            if not e.inst.Parent then return end
            if not State.ResourcesToCollect[e.kind] then return end
            local skipT = Farm.skipUntil[e.inst]
            if skipT and now < skipT then return end
            local pos = e.pos
            local dx, dz = pos.X - myPos.X, pos.Z - myPos.Z
            local d2 = dx * dx + dz * dz
            if d2 > ring2 then return end
            local dist = math.sqrt(d2)
            local score = nodeScore(e.kind, dist)
            if score < bestScore then
                bestScore = score
                best = { inst = e.inst, kind = e.kind, dist = dist, pos = pos }
            end
        end)
        if best then return best end
    end
    return nil
end

local function inRecentCluster(pos: Vector3): boolean
    local now = os.clock()
    for i = #Farm.recentMines, 1, -1 do
        local m = Farm.recentMines[i]
        if now >= m.expires then
            table.remove(Farm.recentMines, i)
        elseif (m.pos - pos).Magnitude < 90 then
            return true
        end
    end
    return false
end

local function markCluster(pos: Vector3)
    table.insert(Farm.recentMines, { pos = pos, expires = os.clock() + 75 })
    while #Farm.recentMines > 48 do
        table.remove(Farm.recentMines, 1)
    end
end

local function onScreen(pos: Vector3): boolean
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local sp, vis = cam:WorldToViewportPoint(pos)
    if sp.Z <= 0 then return false end
    if vis == true then return true end
    local v = cam.ViewportSize
    return sp.X > -120 and sp.Y > -120 and sp.X < v.X + 120 and sp.Y < v.Y + 120
end

local function skipClusterAt(pos: Vector3, radius: number, seconds: number)
    local r2 = radius * radius
    local untilT = os.clock() + seconds
    ResourceScanner.queryRadius(pos, radius, function(e)
        if not e.inst.Parent then return end
        local p = e.pos
        local dx, dy, dz = p.X - pos.X, p.Y - pos.Y, p.Z - pos.Z
        if dx * dx + dy * dy + dz * dz <= r2 then
            Farm.skipUntil[e.inst] = untilT
        end
    end)
    markCluster(pos)
end

local function nextTravelTarget()
    local root = getRoot()
    if not root then return nil end
    local myPos = root.Position
    local now = os.clock()
    local best, bestScore = nil, math.huge
    -- Player-root only. Camera view used to steal the pick when you were
    -- zoomed in on a far tree, so the farm walked toward look-at instead of
    -- what was underfoot.
    local widest = NEAREST_RINGS[#NEAREST_RINGS]
    ResourceScanner.queryRadius(myPos, widest, function(e)
        if not e.inst.Parent then return end
        if not State.ResourcesToCollect[e.kind] then return end
        local skipT = Farm.skipUntil[e.inst]
        if skipT and now < skipT then return end
        local pos = e.pos
        if inRecentCluster(pos) then return end
        local dx = pos.X - myPos.X
        local dz = pos.Z - myPos.Z
        local dist = math.sqrt(dx * dx + dz * dz)
        local score = nodeScore(e.kind, dist)
        if score < bestScore then
            bestScore = score
            best = { inst = e.inst, kind = e.kind, dist = dist, pos = pos }
        end
    end)
    return best
end

-- Selling fires one remote per selected type. Without a cooldown this ran
-- after every node and every Gather Around tick — a dozen remotes a second.
local lastSellAt = 0
local function doAutoSell()
    if not State.AutoSell or not marketRemote then return end
    local now = os.clock()
    if now - lastSellAt < 5 then return end
    lastSellAt = now
    for _, name in RESOURCE_LIST do
        if State.ResourcesToCollect[name] then
            pcall(function() fireSell(marketRemote, State.SellArgStyle, name) end)
        end
    end
end


-- ============================================================
--  GATHER MODES
-- ============================================================
local SNAP_OFF = 3.5
local STAND_HIP = 3
-- Pace between every FireServer, not just between drain passes. Gather Around
-- used to ignore this entirely and dump a cluster at FireFloor (0.03s).
local function hitGap(): number
    return clampNum(State.HitGap, 0.05, 3, 0.12)
end
local DWELL_MAX = 22
local EMPTY_NEEDED = 5
-- Neighbours hit per pass alongside the target. Unbounded fan-out was firing
-- a couple hundred remotes a second in a dense grove.
local MAX_FAN = 8
local function fireFloor(): number
    return clampNum(State.FireFloor, 0.01, 0.5, 0.03)
end

-- Per-node landing offset so every teleport does not arrive on the exact same
-- mathematical spot. Stable per node, so it does not jitter while mining.
local nodeOffsets = {}
local nodeOffsetCount = 0
clearNodeOffsets = function()
    table.clear(nodeOffsets)
    nodeOffsetCount = 0
end
local function nodeOffset(inst: Instance?): (number, number)
    if not inst then return 0, SNAP_OFF end
    if not State.LandingJitter then return 0, SNAP_OFF end
    local o = nodeOffsets[inst]
    if not o then
        if nodeOffsetCount > 256 then
            for k in nodeOffsets do
                if not k.Parent then
                    nodeOffsets[k] = nil
                    nodeOffsetCount -= 1
                end
            end
        end
        nodeOffsetCount += 1
        o = {
            ang = (math.random() - 0.5) * 0.9,
            dist = SNAP_OFF + (math.random() - 0.5) * clampNum(State.LandSpread, 0, 6, 1.4),
        }
        nodeOffsets[inst] = o
    end
    return o.ang, o.dist
end

local function groundAt(x: number, z: number, hintY: number): number
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {}
    if player.Character then table.insert(exclude, player.Character) end
    local folder = ResourcesFolder or ResourceScanner.folder()
    if folder then table.insert(exclude, folder) end
    params.FilterDescendantsInstances = exclude
    local origin = Vector3.new(x, hintY + 24, z)
    local hit = workspace:Raycast(origin, Vector3.new(0, -96, 0), params)
    if hit then return hit.Position.Y end
    return hintY
end

local function standBeside(obj: Instance?, fromPos: Vector3, fallback: Vector3): Vector3
    local x, z, hintY = fallback.X, fallback.Z, fallback.Y
    if obj and obj.Parent then
        local part = liveHarvestPart(obj)
        if part then
            x = part.Position.X
            z = part.Position.Z
            hintY = part.Position.Y - part.Size.Y * 0.5
        else
            local p = scanPos(obj)
            if p then
                x, z, hintY = p.X, p.Z, p.Y
            end
        end
    end
    local gy = groundAt(x, z, math.min(hintY, fromPos.Y))
    local dir = Vector3.new(fromPos.X - x, 0, fromPos.Z - z)
    if dir.Magnitude < 0.2 then dir = Vector3.new(1, 0, 0) end
    dir = dir.Unit
    local ang, off = nodeOffset(obj)
    local c, s = math.cos(ang), math.sin(ang)
    local rx = dir.X * c - dir.Z * s
    local rz = dir.X * s + dir.Z * c
    return Vector3.new(x + rx * off, gy + STAND_HIP, z + rz * off)
end

local function inStandRange(myPos: Vector3, dest: Vector3): boolean
    return flatDist(myPos, dest) <= 7 and math.abs(myPos.Y - dest.Y) <= 6
end

local function folderChild(inst: Instance): Instance?
    if not ResourcesFolder then return nil end
    local cur: Instance? = inst
    while cur and cur ~= ResourcesFolder do
        if cur.Parent == ResourcesFolder then return cur end
        cur = cur.Parent
    end
    return nil
end

local lastFireLog = 0
local lastFireAt = 0

-- Overpower rides the game's Gathering remote instead of inventing a new one.
-- 1. Learn the real FireServer/InvokeServer args when the game swings.
-- 2. After Hit Delay, fire that payload several times on the same tick so a
--    cooldown-then-apply server can accept more than one hit per swing.
-- 3. Scale numeric args and any gather-power values sitting on the character.
local GatherTap = {
    hooked = false,
    ourFire = false,
    learned = nil :: any,
    loggedLearn = false,
    origNamecall = nil :: any,
}

local POWER_SKIP = {
    health = true, hp = true, gold = true, money = true, cash = true,
    wood = true, stone = true, iron = true, count = true, amount = true,
    exp = true, xp = true, level = true, hunger = true, thirst = true,
}

local function looksGatherPower(name: string): boolean
    local n = string.lower(name)
    n = string.gsub(n, "[%s_%-]", "")
    if POWER_SKIP[n] then return false end
    if string.find(n, "jump", 1, true) or string.find(n, "walk", 1, true) then
        return false
    end
    return string.find(n, "damage", 1, true) ~= nil
        or string.find(n, "power", 1, true) ~= nil
        or string.find(n, "mining", 1, true) ~= nil
        or string.find(n, "gather", 1, true) ~= nil
        or string.find(n, "strength", 1, true) ~= nil
        or string.find(n, "harvest", 1, true) ~= nil
        or string.find(n, "axe", 1, true) ~= nil
        or string.find(n, "pickaxe", 1, true) ~= nil
        or string.find(n, "efficiency", 1, true) ~= nil
        or string.find(n, "multiplier", 1, true) ~= nil
end

local function executorFn(name: string): any?
    local ok, fn = pcall(function()
        local env = getfenv(0) :: any
        if type(env[name]) == "function" then
            return env[name]
        end
        if type(env.getgenv) == "function" then
            local g = env.getgenv()
            if type(g) == "table" and type(g[name]) == "function" then
                return g[name]
            end
        end
        return nil
    end)
    if ok and type(fn) == "function" then
        return fn
    end
    return nil
end

local function rememberGatherArgs(...)
    GatherTap.learned = table.pack(...)
    if not GatherTap.loggedLearn then
        GatherTap.loggedLearn = true
        log("Gather payload learned (" .. tostring(GatherTap.learned.n) .. " arg(s))")
    end
end

local function installGatherHook(remote: Instance)
    if GatherTap.hooked or not remote.Parent then return end
    local hookmeta = executorFn("hookmetamethod")
    local getmethod = executorFn("getnamecallmethod")
    local wrap = executorFn("newcclosure")
    if type(hookmeta) ~= "function" or type(getmethod) ~= "function" then
        return
    end
    local function body(self: any, ...: any)
        local prev = GatherTap.origNamecall
        if type(prev) ~= "function" then
            return
        end
        local method = getmethod()
        if self == remote and (method == "FireServer" or method == "InvokeServer") then
            if not GatherTap.ourFire then
                rememberGatherArgs(...)
            end
        end
        return prev(self, ...)
    end
    local hooked = if type(wrap) == "function" then wrap(body) else body
    local ok, old = pcall(function()
        return hookmeta(game, "__namecall", hooked)
    end)
    if ok and type(old) == "function" then
        GatherTap.origNamecall = old
        GatherTap.hooked = true
        log("Gather remote hooked — learning payload")
    end
end

local powerSpoof = {
    values = {} :: { [Instance]: number },
    attrs = {} :: { [string]: { inst: Instance, name: string, value: number } },
}

restoreGatherPower = function()
    for inst, val in powerSpoof.values do
        if inst.Parent then
            pcall(function()
                (inst :: any).Value = val
            end)
        end
    end
    table.clear(powerSpoof.values)
    for _, rec in powerSpoof.attrs do
        if rec.inst.Parent then
            pcall(function()
                rec.inst:SetAttribute(rec.name, rec.value)
            end)
        end
    end
    table.clear(powerSpoof.attrs)
end

local function spoofValue(inst: Instance, scale: number)
    local val = (inst :: any).Value
    if type(val) ~= "number" or val <= 0 then return end
    if powerSpoof.values[inst] == nil then
        powerSpoof.values[inst] = val
    end
    local base = powerSpoof.values[inst]
    local nextVal = base * scale
    if inst:IsA("IntValue") then
        nextVal = math.floor(nextVal + 0.5)
    end
    pcall(function()
        (inst :: any).Value = nextVal
    end)
end

local function spoofAttrs(inst: Instance, scale: number)
    local ok, attrs = pcall(function()
        return inst:GetAttributes()
    end)
    if not ok or type(attrs) ~= "table" then return end
    for name, val in attrs do
        if type(name) == "string" and type(val) == "number" and val > 0 and looksGatherPower(name) then
            local key = inst:GetFullName() .. "@" .. name
            if powerSpoof.attrs[key] == nil then
                powerSpoof.attrs[key] = { inst = inst, name = name, value = val }
            end
            local base = powerSpoof.attrs[key].value
            pcall(function()
                inst:SetAttribute(name, base * scale)
            end)
        end
    end
end

applyGatherPower = function()
    if not State.Overpower then
        restoreGatherPower()
        return
    end
    local scale = clampNum(State.PowerScale, 1, 10, 2)
    if scale <= 1 then return end
    local roots: { Instance } = { player }
    local char = player.Character
    if char then table.insert(roots, char) end
    local bag = player:FindFirstChild("Backpack")
    if bag then table.insert(roots, bag) end
    local ls = player:FindFirstChild("leaderstats")
    if ls then table.insert(roots, ls) end
    for _, root in roots do
        spoofAttrs(root, scale)
        if looksGatherPower(root.Name) and (root:IsA("NumberValue") or root:IsA("IntValue")) then
            spoofValue(root, scale)
        end
        for _, d in root:GetDescendants() do
            spoofAttrs(d, scale)
            if looksGatherPower(d.Name) and (d:IsA("NumberValue") or d:IsA("IntValue")) then
                spoofValue(d, scale)
            end
        end
    end
end

local function firePacked(remote: Instance, packed: any): boolean
    local n = packed.n
    if type(n) ~= "number" then n = #packed end
    local ok, err
    if remote:IsA("RemoteEvent") then
        ok, err = pcall(function()
            (remote :: RemoteEvent):FireServer(table.unpack(packed, 1, n))
        end)
    elseif remote:IsA("RemoteFunction") then
        ok, err = pcall(function()
            (remote :: RemoteFunction):InvokeServer(table.unpack(packed, 1, n))
        end)
    else
        return false
    end
    if not ok then
        local now = os.clock()
        if now - lastFireLog > 2 then
            lastFireLog = now
            log("Gather failed: " .. tostring(err))
        end
        return false
    end
    return true
end

-- Shop catalog. Spoof these names even when the player owns nothing.
local SHOP_TOOLS = {
    { name = "Steel Pick", kind = "pick", tier = 7 },
    { name = "Iron Pick", kind = "pick", tier = 6 },
    { name = "Bronze Pick", kind = "pick", tier = 5 },
    { name = "Copper Pick", kind = "pick", tier = 4 },
    { name = "Flint Pick", kind = "pick", tier = 3 },
    { name = "Stone Pick", kind = "pick", tier = 2 },
    { name = "Steel Axe", kind = "axe", tier = 7 },
    { name = "Iron Axe", kind = "axe", tier = 6 },
    { name = "Bronze Axe", kind = "axe", tier = 5 },
    { name = "Copper Axe", kind = "axe", tier = 4 },
    { name = "Flint Axe", kind = "axe", tier = 3 },
    { name = "Stone Axe", kind = "axe", tier = 2 },
}
local TREE_KINDS = {
    Tree = true, ["Cherry Tree"] = true, ["Rubber Tree"] = true,
}
local shopBind = { at = 0, byName = {} :: { [string]: Instance }, logged = false }

local function bindShopTools()
    local now = os.clock()
    if now - shopBind.at < 6 and next(shopBind.byName) ~= nil then
        return
    end
    shopBind.at = now
    table.clear(shopBind.byName)
    local function remember(inst: Instance)
        for _, row in SHOP_TOOLS do
            if inst.Name == row.name and shopBind.byName[row.name] == nil then
                shopBind.byName[row.name] = inst
            end
        end
    end
    local function walk(root: Instance?)
        if not root then return end
        remember(root)
        for _, d in root:GetDescendants() do
            remember(d)
        end
    end
    walk(ReplicatedStorage)
    pcall(function()
        walk(game:GetService("Lighting"))
    end)
    pcall(function()
        walk(game:GetService("StarterPack"))
    end)
    if not shopBind.logged then
        shopBind.logged = true
        local names = {}
        for name in shopBind.byName do
            table.insert(names, name)
        end
        if #names > 0 then
            log("Shop tools bound: " .. table.concat(names, ", "))
        else
            log("Shop tools: no catalog instances — spoofing Flint/Bronze names")
        end
    end
end

local function resolveTool(kind: string): (Instance?, string)
    bindShopTools()
    local fallback = if kind == "axe" then "Flint Axe" else "Flint Pick"
    local bestName = fallback
    local bestTier = 0
    local bestInst: Instance? = nil
    for _, row in SHOP_TOOLS do
        if row.kind == kind then
            local inst = shopBind.byName[row.name]
            local usable = inst ~= nil or row.tier <= 5
            if usable and row.tier > bestTier then
                bestTier = row.tier
                bestName = row.name
                bestInst = inst
            end
        end
    end
    return bestInst, bestName
end

local function payloadKey(packed: any): string
    local bits = {}
    for i = 1, packed.n do
        local v = packed[i]
        if typeof(v) == "Instance" then
            table.insert(bits, "I:" .. (v :: Instance):GetFullName())
        else
            table.insert(bits, typeof(v) .. ":" .. tostring(v))
        end
    end
    return table.concat(bits, "|")
end

local function addPayload(list: { any }, seen: { [string]: boolean }, packed: any)
    local key = payloadKey(packed)
    if seen[key] then return end
    seen[key] = true
    table.insert(list, packed)
end

local function fireGather(inst: Instance): boolean
    local remote = GatherRemote
    if not remote or not remote.Parent then return false end
    installGatherHook(remote)
    local gap = os.clock() - lastFireAt
    local floor = hitGap()
    if gap < floor then
        task.wait(floor - gap)
    end
    lastFireAt = os.clock()
    local root = getRoot()
    if root and root.Anchored then
        root.Anchored = false
        movementLocked = false
    end
    local model = folderChild(inst) or inst
    local part = liveHarvestPart(inst)
    local kind = ResourceScanner.typeOf(inst)
    local wantKind = if kind and TREE_KINDS[kind] then "axe" else "pick"
    local payloads = {}
    local seen = {}
    addPayload(payloads, seen, table.pack(model))
    if part and part ~= model then
        addPayload(payloads, seen, table.pack(part))
    end
    if State.SpoofPickaxe then
        local toolInst, toolName = resolveTool(wantKind)
        addPayload(payloads, seen, table.pack(model, toolName))
        if toolInst then
            addPayload(payloads, seen, table.pack(model, toolInst))
        end
    end
    local learned = GatherTap.learned
    if type(learned) == "table" and type(learned.n) == "number" and learned.n > 0 then
        local copy = table.pack(table.unpack(learned, 1, learned.n))
        local scale = clampNum(State.PowerScale, 1, 10, 2)
        for i = 1, copy.n do
            local v = copy[i]
            if typeof(v) == "Instance" and ResourcesFolder and (v :: Instance):IsDescendantOf(ResourcesFolder) then
                copy[i] = model
            elseif type(v) == "number" then
                copy[i] = v * scale
            end
        end
        addPayload(payloads, seen, copy)
    end
    local hits = 1
    if State.Overpower then
        hits = math.floor(clampNum(State.HitsPerSwing, 1, 8, 3) + 0.5)
    end
    GatherTap.ourFire = true
    local hit = false
    for _ = 1, hits do
        for _, packed in payloads do
            if firePacked(remote, packed) then
                hit = true
            end
        end
    end
    GatherTap.ourFire = false
    if hit then
        FarmStats.noteSwing()
    end
    return hit
end

local function mineCluster(radius: number, keepGoing: () -> boolean): number
    local fired = 0
    for _, r in listedNearby(radius, MAX_FAN + 4) do
        if not keepGoing() then break end
        if r.inst.Parent and fireGather(r.inst) then
            fired += 1
        end
    end
    return fired
end

-- Drops collision for the duration of fn, so a teleport or glide cannot be
-- blocked by geometry and cannot shove other players around on arrival.
local function withoutCollision(fn: () -> ())
    local char = player.Character
    if not char then fn(); return end
    local changed = {}
    for _, p in char:GetDescendants() do
        if p:IsA("BasePart") and p.CanCollide then
            changed[p] = true
            p.CanCollide = false
        end
    end
    local ok, err = pcall(fn)
    for p in changed do
        if p.Parent then pcall(function() p.CanCollide = true end) end
    end
    if not ok then log("move: " .. tostring(err)) end
end

-- A single CFrame jump across the map is the loudest signal the client can
-- send. The Safe profile covers the same distance in small per-frame steps at
-- a speed the server would accept from a fast vehicle.
local function glideTo(dest: Vector3, lookAt: Vector3)
    local speed = clampNum(State.SoftTeleportSpeed, 40, 800, 220)
    local total = 0
    local root = getRoot()
    if root then total = (dest - root.Position).Magnitude end
    -- Budget the travel time from the actual distance rather than a flat 8s.
    -- A long glide used to hit the deadline mid-flight and get finished off by
    -- the hard snap, which defeated the point of gliding at all.
    local deadline = os.clock() + math.clamp(total / math.max(speed, 1) * 2.5 + 1.5, 2, 20)
    local last = os.clock()
    local lastRemain = math.huge
    local stallSince = 0
    while not Flags.Unloading and os.clock() < deadline do
        root = getRoot()
        if not root then return end
        local gap = dest - root.Position
        local remaining = gap.Magnitude
        if remaining <= 1.5 then break end
        local now = os.clock()
        -- If we stop closing for a third of a second we are fighting terrain
        -- or a server correction. Snap the rest instead of looping forever.
        if remaining >= lastRemain - 0.2 then
            if stallSince == 0 then stallSince = now end
            if now - stallSince > 0.35 then break end
        else
            stallSince = 0
        end
        lastRemain = remaining
        local dt = math.clamp(now - last, 1 / 240, 0.25)
        last = now
        local pace = speed * math.clamp(remaining / 20, 0.25, 1)
        local step = math.min(remaining, pace * dt)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = flatLook(root.Position + gap.Unit * step, lookAt)
        task.wait()
    end
    -- Always finish on the dest, even if the loop stalled or the last step
    -- left us 1.6 studs short of the 1.5 threshold.
    root = getRoot()
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = flatLook(dest, lookAt)
    end
end

local function snapTeleport(obj: Instance?, treePos: Vector3)
    local root = getRoot()
    local char = player.Character
    if not root or not char then return false end
    local dest = Farm.dest
    if not dest then
        dest = standBeside(obj, root.Position, treePos)
    end
    Farm.dest = dest
    Farm.look = treePos
    local far = (dest - root.Position).Magnitude > 10
    withoutCollision(function()
        if State.SoftTeleport and far then
            glideTo(dest, treePos)
        elseif State.TravelHops and far then
            -- Waypoint travel: one 3000-stud jump is a single obvious event,
            -- where a chain of shorter ones reads closer to fast movement.
            local hop = clampNum(State.HopDistance, 40, 600, 180)
            local start = root.Position
            local total = (dest - start).Magnitude
            local steps = math.min(math.floor(total / hop), 24)
            for i = 1, steps do
                if Flags.Unloading then return end
                local r = getRoot()
                if not r then return end
                local at = start:Lerp(dest, i / (steps + 1))
                -- Ride above the terrain between hops; landing mid-cliff and
                -- getting wedged was the old failure here.
                local gy = groundAt(at.X, at.Z, at.Y)
                r.AssemblyLinearVelocity = Vector3.zero
                r.CFrame = flatLook(Vector3.new(at.X, math.max(at.Y, gy + STAND_HIP), at.Z), dest)
                task.wait(0.05)
            end
        end
        local r = getRoot()
        if not r then return end
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        r.CFrame = flatLook(dest, treePos)
    end)
    -- Do not leave the root anchored. Gathering ignores anchored characters,
    -- which is why Teleport Gather moved you and never broke the node.
    unlockMovement()
    root = getRoot()
    if root then
        root.Anchored = false
        root.CFrame = flatLook(dest, treePos)
    end
    return true
end

local function pinAt(obj: Instance?, treePos: Vector3)
    local root = getRoot()
    if not root then return end
    -- Recomputing standBeside from the current root walks you around the
    -- trunk. Keep the first landing pose for the whole drain.
    local dest = Farm.dest
    if not dest then
        dest = standBeside(obj, root.Position, treePos)
        Farm.dest = dest
    end
    Farm.look = treePos
    -- Measured before we correct it: this is how far the last pass drifted,
    -- which is the only honest signal for whether unanchored holding works.
    if not root.Anchored then
        notePinDrift(flatDist(root.Position, dest))
    end
    if pinAllowed() then
        if not root.Anchored then lockMovement() end
    elseif movementLocked and not Farm.mining then
        -- Rest only between nodes. Releasing mid-drain is how high ping
        -- slides you off the trunk.
        unlockMovement()
        local again = getRoot()
        if not again then return end
        root = again
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = flatLook(dest, treePos)
end

local function setFarmStatus(txt: string, color: Color3)
    local statusLabel = State._statusLabel
    local statusDot = State._statusDot
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = txt
        statusLabel.Visible = State.StatusEnabled
    end
    if statusDot and statusDot.Parent then
        statusDot.BackgroundColor3 = color
        statusDot.Visible = State.StatusEnabled
    end
end

local function drainUntilGone(radius: number, inst: Instance?, pos: Vector3?, keepGoing: () -> boolean, label: string): number
    Farm.mining = true
    local t0 = os.clock()
    local empty = 0
    local fired = 0
    local aim = pos
    -- Nodes only count once each, however many passes notice them missing.
    local counted = {}
    local kindOf = if inst then ResourceScanner.typeOf(inst) else nil
    while keepGoing() and not Flags.Unloading and (os.clock() - t0) < DWELL_MAX do
        local alive = getHumanoid()
        if not alive or alive.Health <= 0 then break end
        if inst and inst.Parent then
            local live = scanPos(inst)
            if live then aim = live end
        end
        if aim then pinAt(inst, aim) end
        local targetLive = inst ~= nil and inst.Parent ~= nil
        if targetLive and inst then
            if fireGather(inst) then fired += 1 end
        end
        -- One scan per pass. This used to walk the whole resource index twice
        -- every 0.12s, which is what made dense areas chug.
        local around = listedNearby(radius, MAX_FAN)
        for _, r in around do
            if not keepGoing() then break end
            if r.inst ~= inst and r.inst.Parent then
                if fireGather(r.inst) then fired += 1 end
            end
        end
        local remainFirst: Instance? = nil
        local remainCount = 0
        for _, r in around do
            if r.inst.Parent then
                remainCount += 1
                if not remainFirst then remainFirst = r.inst end
            elseif not counted[r.inst] then
                -- Gone between the fire and this check, while we were standing
                -- on it: that is a node we harvested, not one that streamed out.
                counted[r.inst] = true
                FarmStats.noteNode(r.kind)
            end
        end
        if targetLive == false and inst and not counted[inst] then
            counted[inst] = true
            FarmStats.noteNode(kindOf)
        end
        if (not targetLive) and remainCount == 0 then
            empty += 1
            if empty >= EMPTY_NEEDED then break end
        else
            empty = 0
        end
        local name = if targetLive and inst then inst.Name elseif remainFirst then remainFirst.Name else "node"
        setFarmStatus(
            string.format("%s\n%s  ·  mining until gone", label, name),
            Theme.Success
        )
        -- fireGather already waited Hit Delay per swing. Yield so Unload and
        -- keepGoing can run; do not wait Hit Delay a second time.
        task.wait()
    end
    Farm.mining = false
    return fired
end

local LegitBot = {}
do
    local function clearMovement()
        local hum = getHumanoid()
        if not hum then return end
        local root = hum.RootPart
        if root then
            pcall(function() hum:MoveTo(root.Position) end)
        end
    end

    -- Straight-line MoveTo into a pixel-perfect click on a fixed delay reads
    -- as a bot. Wander the approach and vary the clicks.
    function LegitBot.walkTo(pos: Vector3)
        local hum = getHumanoid()
        if not hum then return end
        local root = hum.RootPart
        local aim = pos
        if root then
            local toNode = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
            if toNode.Magnitude > 6 then
                local side = Vector3.new(-toNode.Unit.Z, 0, toNode.Unit.X)
                aim = pos + side * (math.random() - 0.5) * 5
            end
        end
        pcall(function() hum:MoveTo(aim) end)
    end

    function LegitBot.click(pos: Vector3)
        local cam = workspace.CurrentCamera
        if not cam then return end
        local screenPos, onScreen = cam:WorldToViewportPoint(pos)
        if not onScreen or screenPos.Z <= 0 then return end
        local jx = (math.random() - 0.5) * 6
        local jy = (math.random() - 0.5) * 6
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(screenPos.X + jx, screenPos.Y + jy, 0, true, game, 1)
            task.wait(0.05 + math.random() * 0.07)
            vim:SendMouseButtonEvent(screenPos.X + jx, screenPos.Y + jy, 0, false, game, 1)
        end)
    end

    function LegitBot.stop()
        clearMovement()
    end
end

farmActive = function(): boolean
    return State.AutoGather or State.GatherAround or State.TeleportGather or State.LegitMode
end

local function rememberCluster(inst: Instance, pos: Vector3)
    if inst.Parent then
        Farm.skipUntil[inst] = os.clock() + clampNum(State.SkipSeconds, 2, 60, 8)
    else
        skipClusterAt(pos,
            clampNum(State.ClusterRadius, 20, 250, 90),
            clampNum(State.ClusterSeconds, 10, 180, 60))
    end
end

-- One farm pass. Blocking work (glide, drain, legit clicks) lives here so the
-- Heartbeat scheduler is never stalled. The scheduler only decides when a
-- pass may start, and Unload drops the job instead of racing an inner wait.
local farmJob = { busy = false, wasFarming = false }

local function farmPass()
    if Flags.Unloading or not ScreenGui.Parent then return end

    if not farmActive() then
        Farm.dest = nil
        Farm.look = nil
        Farm.mining = false
        if farmJob.wasFarming then
            LegitBot.stop()
            farmJob.wasFarming = false
            table.clear(Farm.skipUntil)
            table.clear(Farm.recentMines)
            clearNodeOffsets()
            restoreGatherPower()
        end
        setFarmStatus("Idle\nTarget —  ·  Distance —", Theme.Danger)
        return
    end
    farmJob.wasFarming = true
    if State.Overpower then
        applyGatherPower()
    end

    tryBindGather()
    local needRemote = State.AutoGather or State.GatherAround or State.TeleportGather
    if not ResourcesFolder or (needRemote and not GatherRemote) then
        Farm.dest = nil
        Farm.mining = false
        setFarmStatus("Waiting for Remotes / Resources…", Theme.Warn)
        return
    end

    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then
        Farm.dest = nil
        Farm.look = nil
        Farm.mining = false
        setFarmStatus("Dead — farm paused", Theme.Danger)
        return
    end

    local keep = function()
        return farmActive() and not Flags.Unloading and ScreenGui.Parent ~= nil
    end
    local aroundRange = math.max(clampNum(State.HitRange, 10, 120, 45), 18)
    local fireRadius = math.max(16, math.min(aroundRange, 28))
    local movingFarm = State.AutoGather or State.TeleportGather
    ResourceScanner.discover()
    local nearest = nearestListed()

    if State.LegitMode then
        if not nearest then
            setFarmStatus("Searching...\nNo listed resources in cache", Theme.Accent)
            return
        end
        Farm.dest = nil
        Farm.mining = false
        local reach = clampNum(State.LegitReach, 4, 20, 8)
        if nearest.dist > reach then
            LegitBot.walkTo(nearest.pos)
            setFarmStatus(
                string.format("Legit walk\n%s  ·  %.0f studs", nearest.inst.Name, nearest.dist),
                Theme.Accent
            )
            return
        end
        LegitBot.stop()
        setFarmStatus(
            string.format("Legit farm\n%s  ·  %.0f studs", nearest.inst.Name, nearest.dist),
            Theme.Success
        )
        for _, r in listedNearby(reach, 12) do
            if not keep() then break end
            LegitBot.click(r.pos)
            if math.random() < 0.15 then
                task.wait(0.2 + math.random() * 0.5)
            end
        end
        local delay = hitGap()
        task.wait(math.max(delay, 0.05) + math.random() * 0.08)
        doAutoSell()
        return
    end

    if State.GatherAround then
        local localNodes = listedNearby(aroundRange, 32)
        if #localNodes > 0 then
            Farm.mining = true
            Farm.dest = nil
            setFarmStatus(
                string.format("Gather Around\n%d listed node%s nearby", #localNodes, #localNodes == 1 and "" or "s"),
                Theme.Success
            )
            mineCluster(aroundRange, keep)
            doAutoSell()
            Farm.mining = false
        elseif not movingFarm then
            Farm.dest = nil
            if nearest then
                setFarmStatus(
                    string.format("Gather Around\nNearest %s  ·  %.0f studs — walk closer", nearest.inst.Name, nearest.dist),
                    Theme.Accent
                )
            else
                setFarmStatus("Gather Around\nNothing listed nearby", Theme.Accent)
            end
        end
    end

    if not movingFarm then return end

    -- Gather Around owns the local cluster when it is on. Draining here as
    -- well double-fired every node and flapped the status between the two.
    if State.GatherAround then
        if listedNearby(aroundRange, 1)[1] ~= nil then return end
    else
        local localLive = listedNearby(fireRadius, 1)
        if localLive[1] then
            Farm.dest = nil
            drainUntilGone(fireRadius, localLive[1].inst, localLive[1].pos, keep, "Mining")
            rememberCluster(localLive[1].inst, localLive[1].pos)
            doAutoSell()
            unlockMovement()
            Farm.dest = nil
            return
        end
    end

    local target = nextTravelTarget()
    if not target then
        setFarmStatus("Looking for listed nodes near you…", Theme.Warn)
        return
    end
    setFarmStatus(
        string.format("Teleport\n%s  ·  %.0f studs", target.inst.Name, target.dist),
        Theme.Accent
    )
    Farm.dest = nil
    local rootNow = getRoot()
    local dest = if rootNow then standBeside(target.inst, rootNow.Position, target.pos) else target.pos
    Farm.dest = dest
    if not rootNow or not inStandRange(rootNow.Position, dest) then
        snapTeleport(target.inst, target.pos)
    else
        pinAt(target.inst, target.pos)
    end
    drainUntilGone(fireRadius, target.inst, target.pos, keep, "Teleport mine")
    rememberCluster(target.inst, target.pos)
    doAutoSell()
    unlockMovement()
    Farm.dest = nil
end

Scheduler.add("farm", "logic", 0.08, function()
    if Flags.Unloading or not ScreenGui.Parent then return end
    if farmJob.busy then return end
    farmJob.busy = true
    task.spawn(function()
        local ok, err = pcall(farmPass)
        farmJob.busy = false
        if not ok then
            log("Gather pass error: " .. tostring(err))
            cancelMoveTween()
            unlockMovement()
            Farm.mining = false
            Farm.dest = nil
        end
    end)
end)

-- ============================================================
--  STARTUP
--  Runs last so every setter, page and loop it touches already exists.
-- ============================================================
task.defer(function()
    if Flags.Unloading then return end

    -- Restore a saved config before anything else, so the accent and the farm
    -- settings the user left behind are what they come back to.
    pcall(function() if Hub.Config then Hub.Config.autoLoad() end end)
    pcall(function()
        if typeof(State.ThemeAccent) == "Color3" and typeof(State.ThemeAccent2) == "Color3" then
            applyAccents(State.ThemeAccent, State.ThemeAccent2)
        end
    end)
    pcall(applyUiScale)

    -- The profile is the source of truth for the movement settings, but only
    -- when the user has not saved overrides on top of it.
    if not Stealth.presets[State.StealthProfile] then
        Stealth.apply("Balanced")
    end

    -- Index every page for the search box once the first page is up.
    later(1.5, function()
        if not Flags.Unloading then pcall(buildSettingsIndex) end
    end)

    log(string.format("2.0.11 ready  ·  %d nodes indexed", ResourceScanner.count()))
end)
    Hub.toggleSync = toggleSync
    Hub.setFeature = setFeature
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
    Hub.hooks.aimbotCleanup = function()
        if aimbotCleanup then aimbotCleanup() end
    end
    Hub.hooks.destroyFov = function()
        if fovCircleGui then pcall(function() fovCircleGui:Destroy() end) end
    end

    if Hub.Lifecycle then
        Hub.Lifecycle.onCharacterAdded(function(_char: Model)
            if Flags.Unloading then return end
            if cancelMoveTween then pcall(cancelMoveTween) end
            if unlockMovement then pcall(unlockMovement) end
            if clearNodeOffsets then pcall(clearNodeOffsets) end
            pcall(function()
                player.CameraMaxZoomDistance = State.CamZoom
                local cam = workspace.CurrentCamera
                if cam then cam.FieldOfView = State.FOV end
            end)
            if State.Overpower and farmActive and farmActive() then
                task.defer(applyGatherPower)
            end
        end)
        Hub.Lifecycle.onHumanoid(function(hum: Humanoid)
            if Flags.Unloading then return end
            if State.EnableWalkSpeed then applyWalkSettings(hum) end
        end)
        Hub.Lifecycle.onDied(function()
            if Flags.Unloading then return end
            if cancelMoveTween then pcall(cancelMoveTween) end
            if unlockMovement then pcall(unlockMovement) end
        end)
        Hub.Lifecycle.onUnload(function()
            if restoreGatherPower then pcall(restoreGatherPower) end
        end)
        Hub.Lifecycle.onCameraChanged(function(cam: Camera)
            if Flags.Unloading then return end
            pcall(function()
                cam.FieldOfView = State.FOV
            end)
        end)
    end
    return Hub
end
