--[[
    TROYHUB ADDON v2 — Humanlife 3: Civilization
    Companion script for TroyHub 2.0.18
    9 tabs, 40+ features using all 140 remotes from debug scan.
    PlaceId: 133115820245903  |  Toggle: RightControl
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PGui = LP:WaitForChild("PlayerGui")
local Camera = WS.CurrentCamera

local function rname(n)
    local c = "abcdefghijklmnopqrstuvwxyz0123456789"; local s = ""
    for _ = 1, n or 10 do local i = math.random(1, #c); s = s .. string.sub(c, i, i) end
    return s
end
local ID = rname(6)
local function uid(tag) return ID .. "_" .. (tag or rname(4)) end

local guiParent = PGui
do
    local ok = pcall(function()
        if typeof(gethui) == "function" then guiParent = gethui(); return end
    end)
    if not ok or guiParent == PGui then
        pcall(function() guiParent = game:GetService("CoreGui") end)
    end
end

-- ════════════════════════════════════════════════════════
--  REMOTE LOOKUP
-- ════════════════════════════════════════════════════════

local Remotes = RS:FindFirstChild("Remotes")
local CombatRemotes = RS:FindFirstChild("CombatRemotes")
local CombatServer = CombatRemotes and CombatRemotes:FindFirstChild("Server")
local CombatClient = CombatRemotes and CombatRemotes:FindFirstChild("Client")
local RangedEvents = RS:FindFirstChild("RangedEvents")
local RangedServer = RangedEvents and RangedEvents:FindFirstChild("Server")
local AnimEvents = RS:FindFirstChild("AnimEvents")

local function fireRemote(parent, name, ...)
    if not parent then return end
    local r = parent:FindFirstChild(name)
    local args = { ... }
    if r and r:IsA("RemoteEvent") then pcall(function() r:FireServer(unpack(args)) end) end
end

local function invokeRemote(parent, name, ...)
    if not parent then return nil end
    local r = parent:FindFirstChild(name)
    local args = { ... }
    if r and r:IsA("RemoteFunction") then
        local ok, result = pcall(function() return r:InvokeServer(unpack(args)) end)
        return ok and result or nil
    end
    return nil
end

-- ════════════════════════════════════════════════════════
--  THEME
-- ════════════════════════════════════════════════════════

local T = {
    Bg        = Color3.fromRGB(14, 14, 20),
    Panel     = Color3.fromRGB(18, 18, 24),
    Header    = Color3.fromRGB(12, 12, 16),
    SidebarBg = Color3.fromRGB(16, 16, 22),
    GroupBg   = Color3.fromRGB(20, 21, 28),
    Row       = Color3.fromRGB(28, 30, 40),
    RowHi     = Color3.fromRGB(36, 40, 54),
    Stroke    = Color3.fromRGB(36, 40, 54),
    StrokeLo  = Color3.fromRGB(28, 30, 40),
    Text      = Color3.fromRGB(220, 225, 240),
    Dim       = Color3.fromRGB(90, 96, 120),
    Accent    = Color3.fromRGB(80, 170, 255),
    Green     = Color3.fromRGB(55, 200, 110),
    Red       = Color3.fromRGB(255, 70, 70),
    Yellow    = Color3.fromRGB(230, 200, 60),
    Orange    = Color3.fromRGB(255, 150, 50),
    Purple    = Color3.fromRGB(160, 120, 255),
    Cyan      = Color3.fromRGB(50, 210, 200),
    Pink      = Color3.fromRGB(240, 100, 170),
    White     = Color3.fromRGB(255, 255, 255),
}

-- ════════════════════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════════════════════

local alive = true
local conns = {}
local ScreenGui

local S = {
    -- Combat
    AutoAttack = false, AttackDelay = 0.4,
    AutoBlock = false,
    AutoShove = false, ShoveDelay = 1.0,
    KillAura = false, KillAuraRange = 15,
    HitboxExpand = false, HitboxSize = 5,
    AntiRagdoll = false,
    -- Ranged
    AutoFire = false, FireDelay = 0.5,
    AutoReload = false,
    -- Farming
    AutoGatherBot = false, GatherDelay = 0.3, GatherRange = 200,
    AutoFarmCycle = false, FarmDelay = 1.0,
    AutoUpgrade = false,
    -- Market
    AutoSell = false, SellDelay = 1.0, SellResource = "Tree",
    AutoStorage = false,
    -- Camera
    FOV = 70,
    FreecamOn = false, FreecamSpeed = 1,
    ThirdPersonDist = 20,
    SpectateOn = false, SpectateTarget = "",
    -- Players
    ProxAlert = false, ProxAlertRange = 30,
    -- Utility
    Sprint = false,
    AntiKill = false,
    AutoHeal = false,
    AutoEat = false, EatDelay = 5,
    HorseAutoMount = false,
    -- Misc
    ChatSpam = false, ChatSpamDelay = 2, ChatSpamText = "GG",
    PingSpam = false,
    AutoFriendly = false,
}

local Waypoints = {}
local freecamCF = nil
local origCameraType = nil
local origCameraSubject = nil

local function conn(c) if c then table.insert(conns, c) end; return c end
local function isTyping() return UIS:GetFocusedTextBox() ~= nil end

-- ════════════════════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════════════════════

local function new(class, props)
    local inst = Instance.new(class)
    local parent = props.Parent
    for k, v in props do if k ~= "Parent" then inst[k] = v end end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(r, p) return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end
local function stroke(c, th, p) return new("UIStroke", { Color = c or T.Stroke, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p }) end
local function padding(p, t, b, l, r) return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r), Parent = p }) end
local function listLayout(p, pad) return new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, pad or 4), Parent = p }) end

local function getHRP()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getModelPos(model)
    if model:IsA("BasePart") then return model.Position end
    if model:IsA("Model") then
        local ok, pos = pcall(function() return model:GetPivot().Position end)
        if ok then return pos end
        local prim = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if prim then return prim.Position end
    end
    return nil
end

local function getNearestPlayer(range)
    local hrp = getHRP()
    if not hrp then return nil end
    local closest, closestDist = nil, range or 30
    for _, plr in Players:GetPlayers() do
        if plr ~= LP then
            local c = plr.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if h and hum and hum.Health > 0 then
                local d = (h.Position - hrp.Position).Magnitude
                if d < closestDist then closestDist = d; closest = plr end
            end
        end
    end
    return closest
end

local function findInWorkspace(name)
    for _, folder in ipairs({ "Buildings", "Wargod Folder (DONT TOUCH THIS)", "Map" }) do
        local f = WS:FindFirstChild(folder)
        if f then
            for _, child in f:GetDescendants() do
                if string.find(child.Name, name, 1, true) then return child end
            end
        end
    end
    return nil
end

-- ════════════════════════════════════════════════════════
--  COMBAT LOOPS
-- ════════════════════════════════════════════════════════

task.spawn(function()
    while alive do
        if S.AutoAttack then fireRemote(CombatServer, "Attack") end
        task.wait(S.AttackDelay)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoBlock then fireRemote(CombatServer, "Block", true) end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoShove then fireRemote(CombatServer, "Shove") end
        task.wait(S.ShoveDelay)
    end
end)

task.spawn(function()
    while alive do
        if S.KillAura then
            local target = getNearestPlayer(S.KillAuraRange)
            if target then
                fireRemote(CombatServer, "Attack")
                if CombatClient then fireRemote(CombatClient, "HitEnemy", target) end
            end
        end
        task.wait(S.AttackDelay)
    end
end)

-- Hitbox Expander
task.spawn(function()
    while alive do
        if S.HitboxExpand then
            for _, plr in Players:GetPlayers() do
                if plr ~= LP then
                    local char = plr.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            pcall(function()
                                hrp.Size = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
                                hrp.Transparency = 0.7
                            end)
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

-- Anti-Ragdoll
conn(RunService.Heartbeat:Connect(function()
    if not alive or not S.AntiRagdoll then return end
    local char = LP.Character
    if not char then return end
    for _, child in char:GetDescendants() do
        if child:IsA("BallSocketConstraint") or child:IsA("HingeConstraint") then
            pcall(function() child.Enabled = false end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end) end
end))

-- ════════════════════════════════════════════════════════
--  RANGED LOOPS
-- ════════════════════════════════════════════════════════

task.spawn(function()
    while alive do
        if S.AutoFire then fireRemote(RangedServer, "Fire") end
        task.wait(S.FireDelay)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoReload then
            fireRemote(RangedServer, "Reload")
            fireRemote(RangedServer, "BeginReload")
        end
        task.wait(1)
    end
end)

-- ════════════════════════════════════════════════════════
--  FARMING LOOPS
-- ════════════════════════════════════════════════════════

task.spawn(function()
    while alive do
        if S.AutoGatherBot then
            local res = WS:FindFirstChild("Resources")
            local hrp = getHRP()
            if res and hrp then
                for _, child in res:GetChildren() do
                    if not alive or not S.AutoGatherBot then break end
                    local pos = getModelPos(child)
                    if pos and (pos - hrp.Position).Magnitude < S.GatherRange then
                        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                        task.wait(0.1)
                        fireRemote(Remotes, "Gathering", child)
                        task.wait(S.GatherDelay)
                    end
                end
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoFarmCycle then
            local bldg = WS:FindFirstChild("Buildings")
            if bldg then
                for _, farm in bldg:GetChildren() do
                    if not alive or not S.AutoFarmCycle then break end
                    if string.find(farm.Name, "Farm", 1, true) then
                        local re = farm:FindFirstChildOfClass("RemoteEvent", true)
                        if re then pcall(function() re:FireServer("plant") end) end
                        for _, desc in farm:GetDescendants() do
                            if desc:IsA("ProximityPrompt") and string.find(string.lower(desc.ActionText), "water", 1, true) then
                                pcall(function() desc:InputHoldBegin(); task.wait(0.2); desc:InputHoldEnd() end)
                                pcall(function() fireProximityPrompt(desc) end)
                            end
                        end
                        local crop = farm:FindFirstChildWhichIsA("Model")
                        if crop then fireRemote(Remotes, "Gathering", crop) end
                        task.wait(S.FarmDelay)
                    end
                end
            end
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoUpgrade then
            fireRemote(Remotes, "Upgrade")
        end
        task.wait(3)
    end
end)

-- ════════════════════════════════════════════════════════
--  MARKET / STORAGE LOOPS
-- ════════════════════════════════════════════════════════

task.spawn(function()
    while alive do
        if S.AutoSell then fireRemote(Remotes, "Market", S.SellResource, 1) end
        task.wait(S.SellDelay)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoStorage then fireRemote(Remotes, "Storage") end
        task.wait(2)
    end
end)

-- ════════════════════════════════════════════════════════
--  UTILITY LOOPS
-- ════════════════════════════════════════════════════════

task.spawn(function()
    while alive do
        if S.Sprint then fireRemote(Remotes, "SprintClient", true) end
        task.wait(0.3)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoHeal then
            local hum = getHum()
            if hum and hum.Health < hum.MaxHealth * 0.6 then
                fireRemote(Remotes, "Medecine", "heal")
            end
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoEat then fireRemote(Remotes, "Hunger") end
        task.wait(S.EatDelay)
    end
end)

-- Anti-Kill
do
    local dieRemote = Remotes and Remotes:FindFirstChild("Die")
    if dieRemote and dieRemote:IsA("RemoteEvent") then
        conn(dieRemote.OnClientEvent:Connect(function()
            if S.AntiKill then
                task.wait(0.1)
                fireRemote(Remotes, "Spawn")
                task.wait(0.5)
                local hum = getHum()
                if hum then hum.Health = hum.MaxHealth end
            end
        end))
    end
end

-- Horse Auto-Mount
task.spawn(function()
    while alive do
        if S.HorseAutoMount then
            local hrp = getHRP()
            if hrp then
                local horse = findInWorkspace("Horse")
                if horse then
                    local pos = getModelPos(horse)
                    if pos and (pos - hrp.Position).Magnitude > 10 then
                        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                    end
                    if AnimEvents then
                        local server = AnimEvents:FindFirstChild("Server")
                        if server then fireRemote(server, "MountHorse") end
                    end
                end
            end
        end
        task.wait(3)
    end
end)

-- Proximity Alert
task.spawn(function()
    while alive do
        if S.ProxAlert then
            local hrp = getHRP()
            if hrp then
                for _, plr in Players:GetPlayers() do
                    if plr ~= LP then
                        local c = plr.Character
                        local h = c and c:FindFirstChild("HumanoidRootPart")
                        if h and (h.Position - hrp.Position).Magnitude < S.ProxAlertRange then
                            pcall(function()
                                game:GetService("StarterGui"):SetCore("SendNotification", {
                                    Title = "PROXIMITY ALERT",
                                    Text = plr.DisplayName .. " is nearby! (" .. math.floor((h.Position - hrp.Position).Magnitude) .. " studs)",
                                    Duration = 2,
                                })
                            end)
                        end
                    end
                end
            end
        end
        task.wait(3)
    end
end)

-- ════════════════════════════════════════════════════════
--  MISC LOOPS (Chat/Ping/Friendly spam)
-- ════════════════════════════════════════════════════════

task.spawn(function()
    while alive do
        if S.ChatSpam then fireRemote(Remotes, "QCSendMessage", S.ChatSpamText) end
        task.wait(S.ChatSpamDelay)
    end
end)

task.spawn(function()
    while alive do
        if S.PingSpam then
            local hrp = getHRP()
            if hrp then fireRemote(Remotes, "QCPingLocation", hrp.Position) end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while alive do
        if S.AutoFriendly then fireRemote(Remotes, "Friendly") end
        task.wait(2)
    end
end)

-- ════════════════════════════════════════════════════════
--  CAMERA SYSTEM
-- ════════════════════════════════════════════════════════

local function startFreecam()
    if origCameraType then return end
    origCameraType = Camera.CameraType
    origCameraSubject = Camera.CameraSubject
    Camera.CameraType = Enum.CameraType.Scriptable
    freecamCF = Camera.CFrame
end

local function stopFreecam()
    if not origCameraType then return end
    Camera.CameraType = origCameraType
    Camera.CameraSubject = origCameraSubject
    origCameraType = nil; origCameraSubject = nil; freecamCF = nil
end

conn(RunService.RenderStepped:Connect(function(dt)
    if not alive then return end

    if S.FreecamOn and freecamCF then
        local speed = S.FreecamSpeed * 50 * dt
        local move = Vector3.new(0, 0, 0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector * speed end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector * speed end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector * speed end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector * speed end
        if UIS:IsKeyDown(Enum.KeyCode.E) then move = move + Vector3.new(0, speed, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then move = move - Vector3.new(0, speed, 0) end
        freecamCF = CFrame.new(freecamCF.Position + move) * (freecamCF - freecamCF.Position)
        Camera.CFrame = freecamCF
    end

    if S.FOV ~= 70 then pcall(function() Camera.FieldOfView = S.FOV end) end
end))

local function startSpectate(targetName)
    for _, plr in Players:GetPlayers() do
        if plr ~= LP and (string.find(string.lower(plr.Name), string.lower(targetName), 1, true) or string.find(string.lower(plr.DisplayName), string.lower(targetName), 1, true)) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                Camera.CameraSubject = hum
                return true
            end
        end
    end
    return false
end

local function stopSpectate()
    local hum = getHum()
    if hum then Camera.CameraSubject = hum end
end

-- ════════════════════════════════════════════════════════
--  CURSOR UNLOCK
-- ════════════════════════════════════════════════════════

local cursorUnlocked = false
local CURSOR_BIND = uid("cur")
local function forceCursor()
    if not alive or not cursorUnlocked then return end
    pcall(function()
        if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then UIS.MouseBehavior = Enum.MouseBehavior.Default end
    end)
end

-- ════════════════════════════════════════════════════════
--  WINDOW
-- ════════════════════════════════════════════════════════

local unload

ScreenGui = new("ScreenGui", {
    Name = uid(), ResetOnSpawn = false, DisplayOrder = 10001,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    Parent = guiParent,
})

local WIN_W, WIN_H = 560, 420
local SIDE_W = 100
local HEADER_H = 26

local Main = new("Frame", {
    Name = uid(), Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.new(0, 20, 0.5, -WIN_H / 2),
    BackgroundColor3 = T.Bg, BorderSizePixel = 0, ClipsDescendants = true,
    Active = true, Parent = ScreenGui,
})
corner(5, Main); stroke(T.Stroke, 1, Main)

local Header = new("Frame", {
    Name = uid(), Size = UDim2.new(1, 0, 0, HEADER_H),
    BackgroundColor3 = T.Header, BorderSizePixel = 0, Active = true, Parent = Main,
})
new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.Stroke, BorderSizePixel = 0, Parent = Header })
new("TextLabel", { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "TROYHUB ADDON", TextColor3 = T.Orange, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header })
new("TextLabel", { Size = UDim2.fromOffset(16, HEADER_H), Position = UDim2.fromOffset(118, 0), BackgroundTransparency = 1, Font = Enum.Font.Code, Text = "v2", TextColor3 = T.Dim, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header })

local minimized = false
local bodyFrame

local function headerBtn(text, xOff, onClick)
    local b = new("TextButton", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, xOff, 0, 4), BackgroundColor3 = T.Row, BorderSizePixel = 0, Font = Enum.Font.Code, Text = text, TextColor3 = T.Dim, TextSize = 10, AutoButtonColor = false, Parent = Header })
    corner(3, b)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = T.RowHi; b.TextColor3 = T.Text end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = T.Row; b.TextColor3 = T.Dim end)
    b.MouseButton1Click:Connect(onClick); return b
end

headerBtn("_", -44, function()
    minimized = not minimized
    if bodyFrame then bodyFrame.Visible = not minimized end
    Main.Size = minimized and UDim2.fromOffset(WIN_W, HEADER_H) or UDim2.fromOffset(WIN_W, WIN_H)
end)
headerBtn("X", -22, function() unload() end)

do
    local dragging, dragStart, startPos = false, nil, nil
    Header.InputBegan:Connect(function(input) if alive and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then dragging = true; dragStart = input.Position; startPos = Main.Position end end)
    conn(UIS.InputChanged:Connect(function(input) if alive and dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local d = input.Position - dragStart; Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end))
    conn(UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end))
end

bodyFrame = new("Frame", { Name = uid(), Size = UDim2.new(1, 0, 1, -HEADER_H), Position = UDim2.fromOffset(0, HEADER_H), BackgroundTransparency = 1, Parent = Main })

-- ════════════════════════════════════════════════════════
--  SIDEBAR + TABS (9 tabs)
-- ════════════════════════════════════════════════════════

local Sidebar = new("ScrollingFrame", {
    Name = uid(), Size = UDim2.new(0, SIDE_W, 1, 0),
    BackgroundColor3 = T.SidebarBg, BorderSizePixel = 0,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 0, Parent = bodyFrame,
})
listLayout(Sidebar, 2); padding(Sidebar, 6, 6, 5, 5)
new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(SIDE_W - 1, 0), BackgroundColor3 = T.Stroke, BorderSizePixel = 0, Parent = bodyFrame })

local ContentArea = new("Frame", { Name = uid(), Size = UDim2.new(1, -SIDE_W, 1, 0), Position = UDim2.fromOffset(SIDE_W, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = bodyFrame })

local pages = {}
local activePageId = nil

local TAB_DATA = {
    { id = "combat",  label = "COMBAT",   accent = T.Red },
    { id = "ranged",  label = "RANGED",   accent = T.Orange },
    { id = "farming", label = "FARMING",  accent = T.Green },
    { id = "market",  label = "MARKET",   accent = T.Yellow },
    { id = "camera",  label = "CAMERA",   accent = T.Cyan },
    { id = "players", label = "PLAYERS",  accent = T.Pink },
    { id = "util",    label = "UTILITY",  accent = T.Accent },
    { id = "tp",      label = "TELEPORT", accent = T.Purple },
    { id = "misc",    label = "MISC",     accent = T.Dim },
}

local tabButtons = {}
local tabAccents = {}

local function showPage(id)
    activePageId = id
    for _, pg in pages do pg.Visible = false end
    if pages[id] then pages[id].Visible = true end
    for _, td in TAB_DATA do
        local b = tabButtons[td.id]; local acc = tabAccents[td.id]
        if b then
            local on = td.id == id
            b.BackgroundColor3 = on and td.accent:Lerp(T.SidebarBg, 0.65) or T.Row
            b.TextColor3 = on and td.accent or T.Text
            if acc then acc.BackgroundColor3 = on and td.accent or T.StrokeLo; acc.BackgroundTransparency = on and 0 or 0.6 end
        end
    end
end

for i, td in ipairs(TAB_DATA) do
    local page = new("ScrollingFrame", {
        Name = uid(), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false, BorderSizePixel = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
        ScrollBarImageColor3 = T.Dim, Parent = ContentArea,
    })
    listLayout(page, 5); padding(page, 6, 6, 8, 8)
    pages[td.id] = page

    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Row, BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = "  " .. td.label, TextColor3 = T.Text, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = i, Parent = Sidebar })
    corner(4, b)
    local acc = new("Frame", { Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, 0, 0.2, 0), BackgroundColor3 = T.StrokeLo, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = b })
    corner(2, acc)
    tabAccents[td.id] = acc
    b.MouseEnter:Connect(function() if activePageId ~= td.id then b.BackgroundColor3 = T.RowHi end end)
    b.MouseLeave:Connect(function() if activePageId ~= td.id then b.BackgroundColor3 = T.Row end end)
    b.MouseButton1Click:Connect(function() showPage(td.id) end)
    tabButtons[td.id] = b
end

-- ════════════════════════════════════════════════════════
--  WIDGETS
-- ════════════════════════════════════════════════════════

local function section(parent, text, order)
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = text, TextColor3 = T.Dim, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order or 0, Parent = parent })
end

local function switchRow(parent, label, getter, setter, order)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Row, BorderSizePixel = 0, LayoutOrder = order or 0, Parent = parent })
    corner(4, row); stroke(T.StrokeLo, 1, row)
    new("TextLabel", { Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = label, TextColor3 = T.Text, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
    local track = new("Frame", { Size = UDim2.fromOffset(28, 12), Position = UDim2.new(1, -36, 0.5, -6), BackgroundColor3 = getter() and T.Accent:Lerp(T.Bg, 0.5) or T.GroupBg, BorderSizePixel = 0, Parent = row })
    corner(6, track)
    local knob = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = getter() and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = getter() and T.Accent or T.Dim, BorderSizePixel = 0, Parent = track })
    corner(4, knob)
    local function repaint()
        track.BackgroundColor3 = getter() and T.Accent:Lerp(T.Bg, 0.5) or T.GroupBg
        knob.Position = getter() and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2)
        knob.BackgroundColor3 = getter() and T.Accent or T.Dim
    end
    new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row }).MouseButton1Click:Connect(function()
        setter(not getter()); repaint()
    end)
    return row, repaint
end

local function sliderRow(parent, label, min, max, getter, setter, order, suffix)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.Row, BorderSizePixel = 0, LayoutOrder = order or 0, Parent = parent })
    corner(4, row); stroke(T.StrokeLo, 1, row)
    new("TextLabel", { Size = UDim2.fromOffset(160, 12), Position = UDim2.fromOffset(8, 2), BackgroundTransparency = 1, Font = Enum.Font.Code, Text = label, TextColor3 = T.Dim, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
    local readout = new("TextLabel", { Size = UDim2.fromOffset(60, 12), Position = UDim2.new(1, -68, 0, 2), BackgroundTransparency = 1, Font = Enum.Font.Code, Text = tostring(getter()) .. (suffix or ""), TextColor3 = T.Accent, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
    local track = new("Frame", { Size = UDim2.new(1, -16, 0, 4), Position = UDim2.fromOffset(8, 20), BackgroundColor3 = T.GroupBg, BorderSizePixel = 0, Parent = row })
    corner(2, track)
    local fill = new("Frame", { Size = UDim2.fromScale(math.clamp((getter() - min) / (max - min), 0, 1), 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = track })
    corner(2, fill)
    local sliding = false
    track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = true end end)
    conn(UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end end))
    conn(UIS.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + rel * (max - min))
            setter(val); fill.Size = UDim2.fromScale(rel, 1)
            readout.Text = tostring(val) .. (suffix or "")
        end
    end))
end

local function btnRow(parent, label, color, order, onClick)
    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Row, BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = label, TextColor3 = color or T.Accent, TextSize = 9, AutoButtonColor = false, LayoutOrder = order or 0, Parent = parent })
    corner(4, b); stroke(T.StrokeLo, 1, b)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = T.RowHi end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = T.Row end)
    b.MouseButton1Click:Connect(onClick)
    return b
end

local function textInput(parent, placeholder, order)
    local box = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Row, BorderSizePixel = 0,
        Font = Enum.Font.Code, Text = "", PlaceholderText = placeholder,
        PlaceholderColor3 = T.Dim, TextColor3 = T.Text, TextSize = 9,
        ClearTextOnFocus = false, LayoutOrder = order or 0, Parent = parent,
    })
    corner(4, box); stroke(T.StrokeLo, 1, box)
    padding(box, 0, 0, 6, 6)
    return box
end

-- ════════════════════════════════════════════════════════
--  PAGE: COMBAT
-- ════════════════════════════════════════════════════════

do
    local p = pages.combat
    section(p, "MELEE COMBAT", 1)
    switchRow(p, "Auto Attack", function() return S.AutoAttack end, function(v) S.AutoAttack = v end, 2)
    sliderRow(p, "Attack Speed", 1, 20, function() return math.floor(S.AttackDelay * 10) end, function(v) S.AttackDelay = v / 10 end, 3, "")
    switchRow(p, "Auto Block", function() return S.AutoBlock end, function(v) S.AutoBlock = v; if not v then fireRemote(CombatServer, "Block", false) end end, 4)
    switchRow(p, "Auto Shove", function() return S.AutoShove end, function(v) S.AutoShove = v end, 5)
    sliderRow(p, "Shove Cooldown", 5, 30, function() return math.floor(S.ShoveDelay * 10) end, function(v) S.ShoveDelay = v / 10 end, 6, "")

    section(p, "KILL AURA", 10)
    switchRow(p, "Kill Aura", function() return S.KillAura end, function(v) S.KillAura = v end, 11)
    sliderRow(p, "Aura Range", 5, 50, function() return S.KillAuraRange end, function(v) S.KillAuraRange = v end, 12, " studs")

    section(p, "EXPLOITS", 20)
    switchRow(p, "Hitbox Expander", function() return S.HitboxExpand end, function(v) S.HitboxExpand = v end, 21)
    sliderRow(p, "Hitbox Size", 2, 20, function() return S.HitboxSize end, function(v) S.HitboxSize = v end, 22, " studs")
    switchRow(p, "Anti-Ragdoll", function() return S.AntiRagdoll end, function(v) S.AntiRagdoll = v end, 23)

    section(p, "MANUAL", 30)
    btnRow(p, "Equip Weapon", T.Accent, 31, function() fireRemote(CombatServer, "Equip") end)
    btnRow(p, "Shove Once", T.Orange, 32, function() fireRemote(CombatServer, "Shove") end)
    btnRow(p, "Kick", T.Red, 33, function() fireRemote(CombatServer, "Attack", "kick") end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: RANGED
-- ════════════════════════════════════════════════════════

do
    local p = pages.ranged
    section(p, "RANGED WEAPONS", 1)
    switchRow(p, "Auto Fire", function() return S.AutoFire end, function(v) S.AutoFire = v end, 2)
    sliderRow(p, "Fire Rate", 1, 20, function() return math.floor(S.FireDelay * 10) end, function(v) S.FireDelay = v / 10 end, 3, "")
    switchRow(p, "Auto Reload", function() return S.AutoReload end, function(v) S.AutoReload = v end, 4)

    section(p, "MANUAL", 10)
    btnRow(p, "Equip Ranged", T.Accent, 11, function() fireRemote(RangedServer, "Equipped") end)
    btnRow(p, "Fire Once", T.Red, 12, function() fireRemote(RangedServer, "Fire") end)
    btnRow(p, "Prime Gun", T.Orange, 13, function() fireRemote(RangedServer, "PrimeGun") end)
    btnRow(p, "Reload", T.Green, 14, function() fireRemote(RangedServer, "Reload") end)
    btnRow(p, "Aim Gun", T.Cyan, 15, function() fireRemote(RangedServer, "AimGun", true) end)
    btnRow(p, "Unequip Ranged", T.Dim, 16, function() fireRemote(RangedServer, "Unequiped") end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: FARMING
-- ════════════════════════════════════════════════════════

do
    local p = pages.farming
    section(p, "AUTO-GATHER BOT", 1)
    switchRow(p, "Auto Gather (TP + Collect)", function() return S.AutoGatherBot end, function(v) S.AutoGatherBot = v end, 2)
    sliderRow(p, "Gather Delay", 1, 20, function() return math.floor(S.GatherDelay * 10) end, function(v) S.GatherDelay = v / 10 end, 3, "")
    sliderRow(p, "Gather Range", 50, 500, function() return S.GatherRange end, function(v) S.GatherRange = v end, 4, " studs")

    section(p, "FARM CYCLE", 10)
    switchRow(p, "Auto Farm (Plant/Water/Harvest)", function() return S.AutoFarmCycle end, function(v) S.AutoFarmCycle = v end, 11)
    sliderRow(p, "Farm Delay", 5, 50, function() return math.floor(S.FarmDelay * 10) end, function(v) S.FarmDelay = v / 10 end, 12, "")
    switchRow(p, "Auto Upgrade Buildings", function() return S.AutoUpgrade end, function(v) S.AutoUpgrade = v end, 13)

    section(p, "MANUAL GATHER", 20)
    local resources = { "Tree", "Cherry Tree", "Rubber Tree", "Rock", "Sand", "Clay", "Coal", "Copper", "Gold", "Iron", "Tin", "Sulfur" }
    for i, name in ipairs(resources) do
        btnRow(p, "Gather " .. name, T.Green, 20 + i, function()
            task.spawn(function()
                local res = WS:FindFirstChild("Resources")
                if not res then return end
                local hrp = getHRP()
                if not hrp then return end
                for _, child in res:GetChildren() do
                    if child.Name == name then
                        local pos = getModelPos(child)
                        if pos and (pos - hrp.Position).Magnitude < 200 then
                            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                            task.wait(0.1)
                            fireRemote(Remotes, "Gathering", child)
                            task.wait(0.2)
                        end
                    end
                end
            end)
        end)
    end

    section(p, "ANIMALS", 40)
    btnRow(p, "Interact Cow", T.Orange, 41, function() fireRemote(Remotes, "AnimalInteract", "Cow") end)
    btnRow(p, "Interact Bull", T.Red, 42, function() fireRemote(Remotes, "AnimalInteract", "Bull") end)
    btnRow(p, "Interact Dairy Cow", T.Cyan, 43, function() fireRemote(Remotes, "AnimalInteract", "Dairy Cow") end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: MARKET
-- ════════════════════════════════════════════════════════

do
    local p = pages.market
    section(p, "AUTO-SELL", 1)
    switchRow(p, "Auto Sell", function() return S.AutoSell end, function(v) S.AutoSell = v end, 2)
    sliderRow(p, "Sell Interval", 1, 30, function() return math.floor(S.SellDelay * 10) end, function(v) S.SellDelay = v / 10 end, 3, "")

    section(p, "STORAGE", 5)
    switchRow(p, "Auto Storage Deposit", function() return S.AutoStorage end, function(v) S.AutoStorage = v end, 6)
    btnRow(p, "Deposit Now", T.Accent, 7, function() fireRemote(Remotes, "Storage") end)

    section(p, "SELL RESOURCE", 10)
    local resources = { "Tree", "Cherry Tree", "Rubber Tree", "Rock", "Sand", "Clay", "Coal", "Copper", "Gold", "Iron", "Tin", "Sulfur" }
    for i, name in ipairs(resources) do
        btnRow(p, "Sell " .. name, T.Green, 10 + i, function()
            S.SellResource = name
            fireRemote(Remotes, "Market", name, 1)
        end)
    end

    section(p, "BULK", 30)
    btnRow(p, "Sell All Types (1 each)", T.Yellow, 31, function()
        task.spawn(function()
            for _, name in ipairs(resources) do
                fireRemote(Remotes, "Market", name, 1)
                task.wait(0.1)
            end
        end)
    end)

    section(p, "CRAFTING", 35)
    btnRow(p, "Fire Craft", T.Accent, 36, function() fireRemote(Remotes, "Craft") end)
    btnRow(p, "Fire Upgrade", T.Purple, 37, function() fireRemote(Remotes, "Upgrade") end)
    btnRow(p, "Fire Industrial", T.Orange, 38, function() fireRemote(Remotes, "Industrial") end)

    section(p, "EXPLOIT", 40)
    btnRow(p, "QCAddResources (test)", T.Red, 41, function()
        fireRemote(Remotes, "QCAddResources", "Tree", 100)
        fireRemote(Remotes, "QCAddResources", "Gold", 100)
        fireRemote(Remotes, "QCAddResources", "Iron", 100)
    end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: CAMERA
-- ════════════════════════════════════════════════════════

do
    local p = pages.camera
    section(p, "FIELD OF VIEW", 1)
    sliderRow(p, "FOV", 30, 120, function() return S.FOV end, function(v) S.FOV = v end, 2, "")
    btnRow(p, "Reset FOV (70)", T.Dim, 3, function() S.FOV = 70; pcall(function() Camera.FieldOfView = 70 end) end)

    section(p, "FREECAM", 5)
    switchRow(p, "Freecam (WASD + E/Q)", function() return S.FreecamOn end, function(v)
        S.FreecamOn = v
        if v then startFreecam() else stopFreecam() end
    end, 6)
    sliderRow(p, "Freecam Speed", 1, 10, function() return S.FreecamSpeed end, function(v) S.FreecamSpeed = v end, 7, "x")

    section(p, "THIRD PERSON", 10)
    sliderRow(p, "Max Zoom Distance", 10, 100, function() return S.ThirdPersonDist end, function(v)
        S.ThirdPersonDist = v
        pcall(function() LP.CameraMaxZoomDistance = v end)
    end, 11, " studs")
    btnRow(p, "Apply Zoom Distance", T.Accent, 12, function()
        pcall(function() LP.CameraMaxZoomDistance = S.ThirdPersonDist end)
    end)

    section(p, "SPECTATE", 15)
    local spectateBox = textInput(p, "player name to spectate...", 16)
    btnRow(p, "Start Spectating", T.Cyan, 17, function()
        if spectateBox.Text ~= "" then
            S.SpectateOn = startSpectate(spectateBox.Text)
        end
    end)
    btnRow(p, "Stop Spectating", T.Red, 18, function()
        S.SpectateOn = false; stopSpectate()
    end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: PLAYERS
-- ════════════════════════════════════════════════════════

do
    local p = pages.players
    section(p, "PROXIMITY ALERT", 1)
    switchRow(p, "Proximity Alert", function() return S.ProxAlert end, function(v) S.ProxAlert = v end, 2)
    sliderRow(p, "Alert Range", 10, 100, function() return S.ProxAlertRange end, function(v) S.ProxAlertRange = v end, 3, " studs")

    section(p, "PLAYER LIST", 5)

    local listFrame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 200), BackgroundColor3 = T.GroupBg, BorderSizePixel = 0,
        LayoutOrder = 6, ClipsDescendants = true, Parent = p,
    })
    corner(4, listFrame); stroke(T.StrokeLo, 1, listFrame)

    local listScroll = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = T.Dim, Parent = listFrame,
    })
    listLayout(listScroll, 2); padding(listScroll, 4, 4, 4, 4)

    task.spawn(function()
        while alive do
            if activePageId == "players" then
                for _, child in listScroll:GetChildren() do
                    if child:IsA("Frame") then child:Destroy() end
                end
                local hrp = getHRP()
                for _, plr in Players:GetPlayers() do
                    local char = plr.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local phrp = char and char:FindFirstChild("HumanoidRootPart")
                    local tool = char and char:FindFirstChildOfClass("Tool")
                    local dist = (hrp and phrp) and math.floor((phrp.Position - hrp.Position).Magnitude) or 0
                    local hp = hum and (math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) or "?"
                    local isMe = plr == LP
                    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = isMe and T.Accent:Lerp(T.Bg, 0.85) or T.Row, BorderSizePixel = 0, Parent = listScroll })
                    corner(3, row)
                    local info = '<font color="' .. (isMe and "#50AAFF" or "#DCE1F0") .. '">' .. plr.DisplayName .. '</font>'
                    info = info .. '  <font color="#5A6078">HP:' .. hp .. '  Dist:' .. dist .. 's'
                    if tool then info = info .. '  [' .. tool.Name .. ']' end
                    info = info .. '</font>'
                    new("TextLabel", { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(6, 0), BackgroundTransparency = 1, Font = Enum.Font.Code, Text = info, TextColor3 = T.Text, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = row })
                end
            end
            task.wait(2)
        end
    end)

    section(p, "ACTIONS", 10)
    btnRow(p, "TP to Nearest Player", T.Accent, 11, function()
        local target = getNearestPlayer(9999)
        if target then
            local char = target.Character
            local h = char and char:FindFirstChild("HumanoidRootPart")
            if h then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(h.Position + Vector3.new(0, 0, 3)) end end
        end
    end)
    btnRow(p, "Bring Nearest Player", T.Red, 12, function()
        local target = getNearestPlayer(9999)
        if target then
            local char = target.Character
            local h = char and char:FindFirstChild("HumanoidRootPart")
            local hrp = getHRP()
            if h and hrp then pcall(function() h.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 0, 3)) end) end
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: UTILITY
-- ════════════════════════════════════════════════════════

do
    local p = pages.util
    section(p, "SURVIVAL", 1)
    switchRow(p, "Sprint", function() return S.Sprint end, function(v) S.Sprint = v end, 2)
    switchRow(p, "Anti-Kill (Auto Respawn)", function() return S.AntiKill end, function(v) S.AntiKill = v end, 3)
    switchRow(p, "Auto Heal (60% HP)", function() return S.AutoHeal end, function(v) S.AutoHeal = v end, 4)
    switchRow(p, "Auto Eat (Hunger)", function() return S.AutoEat end, function(v) S.AutoEat = v end, 5)
    sliderRow(p, "Eat Interval", 1, 20, function() return S.EatDelay end, function(v) S.EatDelay = v end, 6, "s")
    switchRow(p, "Horse Auto-Mount", function() return S.HorseAutoMount end, function(v) S.HorseAutoMount = v end, 7)

    section(p, "ACTIONS", 10)
    btnRow(p, "Respawn", T.Green, 11, function() fireRemote(Remotes, "Spawn") end)
    btnRow(p, "Die", T.Red, 12, function() fireRemote(Remotes, "Die") end)
    btnRow(p, "Heal", T.Cyan, 13, function() fireRemote(Remotes, "Medecine", "heal") end)
    btnRow(p, "Feed (Hunger)", T.Orange, 14, function() fireRemote(Remotes, "Hunger") end)
    btnRow(p, "Customization", T.Purple, 15, function() fireRemote(Remotes, "Customization") end)
    btnRow(p, "Debug Ragdoll", T.Pink, 16, function() fireRemote(Remotes, "DebugRagdoll") end)

    section(p, "SOCIAL", 20)
    btnRow(p, "Friendly", T.Green, 21, function() fireRemote(Remotes, "Friendly") end)
    btnRow(p, "Callout", T.Yellow, 22, function() fireRemote(Remotes, "Callout") end)
    btnRow(p, "Priest Icon", T.Purple, 23, function() fireRemote(Remotes, "PriestIcon") end)

    section(p, "CIVILIZATION", 30)
    btnRow(p, "Civilization", T.Accent, 31, function() fireRemote(Remotes, "Civilization") end)
    btnRow(p, "Dynasty", T.Orange, 32, function() fireRemote(Remotes, "Dynasty") end)
    btnRow(p, "Diplomacy", T.Cyan, 33, function() fireRemote(Remotes, "Diplomacy") end)
    btnRow(p, "Military Camp", T.Red, 34, function() fireRemote(Remotes, "MilitaryCamp") end)
    btnRow(p, "Literature", T.Green, 35, function() fireRemote(Remotes, "Litterature") end)

    section(p, "WAR INSTRUMENTS", 40)
    btnRow(p, "Play War Drum", T.Orange, 41, function()
        local drum = findInWorkspace("Drum")
        if drum then
            local pp = drum:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pp then pcall(function() fireProximityPrompt(pp) end) end
            if AnimEvents then local s = AnimEvents:FindFirstChild("Server"); if s then fireRemote(s, "PlayDrum") end end
        end
    end)
    btnRow(p, "Play Harp", T.Cyan, 42, function()
        local harp = findInWorkspace("Harp")
        if harp then
            local pp = harp:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pp then pcall(function() fireProximityPrompt(pp) end) end
            if AnimEvents then local s = AnimEvents:FindFirstChild("Server"); if s then fireRemote(s, "PlayHarp") end end
        end
    end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: TELEPORT
-- ════════════════════════════════════════════════════════

do
    local p = pages.tp
    section(p, "KEY LOCATIONS", 1)

    btnRow(p, "TP to Spawn", T.Green, 2, function()
        local spawn = WS:FindFirstChild("Spawn")
        if spawn then
            for _, child in spawn:GetChildren() do
                if child:IsA("SpawnLocation") or child:IsA("BasePart") then
                    local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(child.Position + Vector3.new(0, 3, 0)) end; break
                end
            end
        end
    end)

    btnRow(p, "TP to Map Center", T.Accent, 3, function()
        local map = WS:FindFirstChild("Map")
        if map then
            local pos = getModelPos(map)
            if pos then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 10, 0)) end end
        end
    end)

    btnRow(p, "TP to Resources", T.Yellow, 4, function()
        local res = WS:FindFirstChild("Resources")
        if res and #res:GetChildren() > 0 then
            local first = res:GetChildren()[1]
            local pos = getModelPos(first)
            if pos then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end end
        end
    end)

    btnRow(p, "TP to Buildings", T.Orange, 5, function()
        local bldg = WS:FindFirstChild("Buildings")
        if bldg and #bldg:GetChildren() > 0 then
            local first = bldg:GetChildren()[1]
            local pos = getModelPos(first)
            if pos then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end end
        end
    end)

    btnRow(p, "TP to Civilizations", T.Cyan, 6, function()
        local civ = WS:FindFirstChild("Civilizations")
        if civ and #civ:GetChildren() > 0 then
            local first = civ:GetChildren()[1]
            local pos = getModelPos(first)
            if pos then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end end
        end
    end)

    btnRow(p, "TP to Horse", T.Orange, 7, function()
        local horse = findInWorkspace("Horse")
        if horse then
            local pos = getModelPos(horse)
            if pos then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end end
        end
    end)

    btnRow(p, "TP to Elephant", T.Purple, 8, function()
        local elep = findInWorkspace("Elephant")
        if elep then
            local pos = getModelPos(elep)
            if pos then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) end end
        end
    end)

    section(p, "PLAYER TELEPORT", 10)
    local plrBox = textInput(p, "player name...", 11)
    btnRow(p, "TP to Player", T.Accent, 12, function()
        local query = string.lower(plrBox.Text)
        if query == "" then return end
        for _, plr in Players:GetPlayers() do
            if string.find(string.lower(plr.Name), query, 1, true) or string.find(string.lower(plr.DisplayName), query, 1, true) then
                local char = plr.Character; local h = char and char:FindFirstChild("HumanoidRootPart")
                if h then local hrp = getHRP(); if hrp then hrp.CFrame = CFrame.new(h.Position + Vector3.new(0, 0, 3)) end; break end
            end
        end
    end)

    section(p, "WAYPOINTS", 20)
    local wpNameBox = textInput(p, "waypoint name...", 21)

    btnRow(p, "Save Waypoint", T.Green, 22, function()
        local name = wpNameBox.Text
        if name == "" then name = "WP" .. #Waypoints + 1 end
        local hrp = getHRP()
        if hrp then
            table.insert(Waypoints, { name = name, cf = hrp.CFrame })
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Waypoint Saved", Text = name, Duration = 2 })
            end)
        end
    end)

    btnRow(p, "TP to Last Waypoint", T.Accent, 23, function()
        if #Waypoints > 0 then
            local wp = Waypoints[#Waypoints]
            local hrp = getHRP()
            if hrp then hrp.CFrame = wp.cf end
        end
    end)

    btnRow(p, "List Waypoints", T.Dim, 24, function()
        local msg = ""
        for i, wp in ipairs(Waypoints) do
            msg = msg .. i .. ". " .. wp.name .. "\n"
        end
        if msg == "" then msg = "No waypoints saved" end
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Waypoints", Text = msg, Duration = 5 })
        end)
    end)

    btnRow(p, "Clear All Waypoints", T.Red, 25, function() table.clear(Waypoints) end)
end

-- ════════════════════════════════════════════════════════
--  PAGE: MISC
-- ════════════════════════════════════════════════════════

do
    local p = pages.misc
    section(p, "GAME INFO", 1)

    local infoLabel = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = T.Row, BorderSizePixel = 0,
        Font = Enum.Font.Code, Text = "", TextColor3 = T.Dim, TextSize = 8,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, RichText = true,
        LayoutOrder = 2, Parent = p,
    })
    corner(4, infoLabel); stroke(T.StrokeLo, 1, infoLabel)
    padding(infoLabel, 5, 5, 6, 6)

    task.spawn(function()
        while alive do
            if activePageId == "misc" then
                local char = LP.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local tool = char and char:FindFirstChildOfClass("Tool")
                local res = WS:FindFirstChild("Resources")
                local bldg = WS:FindFirstChild("Buildings")
                local hrp = getHRP()
                local lines = {}
                table.insert(lines, '<font color="#50AAFF">Game:</font> <font color="#DCE1F0">Humanlife 3: Civilization</font>')
                table.insert(lines, '<font color="#50AAFF">PlaceId:</font> <font color="#DCE1F0">' .. game.PlaceId .. '</font>')
                table.insert(lines, '<font color="#50AAFF">Players:</font> <font color="#DCE1F0">' .. #Players:GetPlayers() .. '</font>')
                if hum then table.insert(lines, '<font color="#50AAFF">HP:</font> <font color="#DCE1F0">' .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. '</font>') end
                table.insert(lines, '<font color="#50AAFF">Tool:</font> <font color="#DCE1F0">' .. (tool and tool.Name or "none") .. '</font>')
                table.insert(lines, '<font color="#50AAFF">Resources:</font> <font color="#DCE1F0">' .. (res and #res:GetChildren() or 0) .. ' nodes</font>')
                table.insert(lines, '<font color="#50AAFF">Buildings:</font> <font color="#DCE1F0">' .. (bldg and #bldg:GetChildren() or 0) .. '</font>')
                if hrp then table.insert(lines, '<font color="#50AAFF">Position:</font> <font color="#DCE1F0">' .. math.floor(hrp.Position.X) .. ', ' .. math.floor(hrp.Position.Y) .. ', ' .. math.floor(hrp.Position.Z) .. '</font>') end
                table.insert(lines, '<font color="#50AAFF">Waypoints:</font> <font color="#DCE1F0">' .. #Waypoints .. ' saved</font>')
                infoLabel.Text = table.concat(lines, "\n")
            end
            task.wait(1)
        end
    end)

    section(p, "CHAT / QC SPAM", 10)
    switchRow(p, "Chat Spam", function() return S.ChatSpam end, function(v) S.ChatSpam = v end, 11)
    local chatBox = textInput(p, "spam message (default: GG)...", 12)
    chatBox.FocusLost:Connect(function() if chatBox.Text ~= "" then S.ChatSpamText = chatBox.Text end end)
    sliderRow(p, "Chat Spam Delay", 1, 10, function() return S.ChatSpamDelay end, function(v) S.ChatSpamDelay = v end, 13, "s")
    switchRow(p, "Ping Spam (map ping)", function() return S.PingSpam end, function(v) S.PingSpam = v end, 14)
    switchRow(p, "Auto Friendly Spam", function() return S.AutoFriendly end, function(v) S.AutoFriendly = v end, 15)

    section(p, "QC EXPLOITS", 20)
    btnRow(p, "QCAddResources (Tree x100)", T.Green, 21, function() fireRemote(Remotes, "QCAddResources", "Tree", 100) end)
    btnRow(p, "QCAddResources (Gold x100)", T.Yellow, 22, function() fireRemote(Remotes, "QCAddResources", "Gold", 100) end)
    btnRow(p, "QCAddResources (Iron x100)", T.Orange, 23, function() fireRemote(Remotes, "QCAddResources", "Iron", 100) end)
    btnRow(p, "QCAddResources (All x50)", T.Red, 24, function()
        task.spawn(function()
            for _, name in ipairs({ "Tree", "Cherry Tree", "Rubber Tree", "Rock", "Sand", "Clay", "Coal", "Copper", "Gold", "Iron", "Tin", "Sulfur" }) do
                fireRemote(Remotes, "QCAddResources", name, 50)
                task.wait(0.05)
            end
        end)
    end)

    section(p, "PRISON / VOTE", 30)
    btnRow(p, "Fire Prison", T.Red, 31, function() fireRemote(Remotes, "Prison") end)
    btnRow(p, "Vote Kick Nearest", T.Orange, 32, function()
        local target = getNearestPlayer(50)
        if target then fireRemote(Remotes, "VoteKick", target) end
    end)

    section(p, "REMOTE DUMP", 40)
    btnRow(p, "Gather All Nearby (30 studs)", T.Green, 41, function()
        task.spawn(function()
            local res = WS:FindFirstChild("Resources"); if not res then return end
            local hrp = getHRP(); if not hrp then return end
            for _, child in res:GetChildren() do
                if not alive then break end
                local pos = getModelPos(child)
                if pos and (pos - hrp.Position).Magnitude < 30 then
                    fireRemote(Remotes, "Gathering", child); task.wait(0.05)
                end
            end
        end)
    end)
end

showPage("combat")

-- ════════════════════════════════════════════════════════
--  STATUS BAR
-- ════════════════════════════════════════════════════════

local statusBar = new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = T.Header, BorderSizePixel = 0, Parent = Main })
local statusLabel = new("TextLabel", { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1, Font = Enum.Font.Code, Text = "", TextColor3 = T.Dim, TextSize = 7, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusBar })

conn(RunService.Heartbeat:Connect(function()
    if not alive then return end
    local flags = {}
    if S.AutoAttack then table.insert(flags, "ATK") end
    if S.AutoBlock then table.insert(flags, "BLK") end
    if S.KillAura then table.insert(flags, "AURA") end
    if S.HitboxExpand then table.insert(flags, "HITBOX") end
    if S.AutoFire then table.insert(flags, "FIRE") end
    if S.AutoGatherBot then table.insert(flags, "GATHER") end
    if S.AutoFarmCycle then table.insert(flags, "FARM") end
    if S.AutoSell then table.insert(flags, "SELL") end
    if S.AutoStorage then table.insert(flags, "STORE") end
    if S.Sprint then table.insert(flags, "SPRINT") end
    if S.AntiKill then table.insert(flags, "GOD") end
    if S.AutoHeal then table.insert(flags, "HEAL") end
    if S.AutoEat then table.insert(flags, "EAT") end
    if S.FreecamOn then table.insert(flags, "FREECAM") end
    if S.ProxAlert then table.insert(flags, "ALERT") end
    if S.ChatSpam then table.insert(flags, "SPAM") end
    local active = #flags > 0 and table.concat(flags, " | ") or "idle"
    statusLabel.Text = active .. "  |  RCtrl  |  " .. #Players:GetPlayers() .. " plrs"
end))

-- ════════════════════════════════════════════════════════
--  INPUT
-- ════════════════════════════════════════════════════════

local function setMenuVisible(on)
    if not alive then return end
    ScreenGui.Enabled = on
    if on then
        cursorUnlocked = true
        pcall(function() RunService:BindToRenderStep(CURSOR_BIND, Enum.RenderPriority.Last.Value + 1, forceCursor) end)
    else
        cursorUnlocked = false
        pcall(function() RunService:UnbindFromRenderStep(CURSOR_BIND) end)
    end
end

conn(UIS.InputBegan:Connect(function(input, processed)
    if not alive or processed or isTyping() then return end
    if input.KeyCode == Enum.KeyCode.RightControl then setMenuVisible(not ScreenGui.Enabled) end
end))

-- ════════════════════════════════════════════════════════
--  UNLOAD
-- ════════════════════════════════════════════════════════

unload = function()
    if not alive then return end
    alive = false
    for k, v in S do if typeof(v) == "boolean" then S[k] = false end end
    if S.FreecamOn then stopFreecam() end
    if S.SpectateOn then stopSpectate() end
    pcall(function() Camera.FieldOfView = 70 end)
    pcall(function() LP.CameraMaxZoomDistance = 128 end)
    for _, c in conns do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    cursorUnlocked = false
    pcall(function() RunService:UnbindFromRenderStep(CURSOR_BIND) end)
    if ScreenGui then ScreenGui:Destroy() end
end

if ScreenGui.Enabled then setMenuVisible(true) end
