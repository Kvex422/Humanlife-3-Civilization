--!strict
-- Connection tracking, page-scoped debris, and the deterministic Unload pipeline.

return function(Hub: any)
	local Flags = Hub.Flags
	local player = Hub.player
	local playerGui = Hub.playerGui
	local Lighting = Hub.Services.Lighting
	local RunService = Hub.Services.RunService

	local Connections: { any } = {}
	local connectionMap: { [string]: any } = {}
	local pageConnections: { any } = {}
	local pageDebris: { Instance } = {}
	local pageStore: { [string]: { connections: { any }, debris: { Instance }, data: { [string]: any } } } = {}

	local function track(conn)
		table.insert(Connections, conn)
		return conn
	end

	local function trackNamed(name: string, conn)
		local prev = connectionMap[name]
		if prev then
			pcall(function()
				prev:Disconnect()
			end)
		end
		connectionMap[name] = conn
		return track(conn)
	end

	local function disconnectAll()
		for _, c in Connections do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(Connections)
		for name, c in connectionMap do
			pcall(function()
				c:Disconnect()
			end)
			connectionMap[name] = nil
		end
	end

	local function trackPage(conn)
		table.insert(pageConnections, conn)
		return conn
	end

	local function holdDebris(inst)
		table.insert(pageDebris, inst)
		return inst
	end

	local function clearPageScope()
		for _, c in pageConnections do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(pageConnections)
		for _, inst in pageDebris do
			pcall(function()
				inst:Destroy()
			end)
		end
		table.clear(pageDebris)
		if Hub.Scheduler then
			Hub.Scheduler.removePages()
		end
	end

	local function pageEnsure(name: string)
		local page = pageStore[name]
		if not page then
			page = { connections = {}, debris = {}, data = {} }
			pageStore[name] = page
		end
		return page
	end

	local Pages = {}

	function Pages.open(name: string)
		Hub.Flags.ActivePage = name
		local page = pageEnsure(name)
		local onFocus = Hub.PageHooks and Hub.PageHooks[name] and Hub.PageHooks[name].onFocus
		if type(onFocus) == "function" then
			pcall(onFocus, page.data)
		end
		return page
	end

	function Pages.close(name: string)
		local page = pageStore[name]
		if not page then
			return
		end
		local onBlur = Hub.PageHooks and Hub.PageHooks[name] and Hub.PageHooks[name].onBlur
		if type(onBlur) == "function" then
			pcall(onBlur, page.data)
		end
		for _, c in page.connections do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(page.connections)
		for _, inst in page.debris do
			pcall(function()
				inst:Destroy()
			end)
		end
		table.clear(page.debris)
		if Hub.Scheduler then
			Hub.Scheduler.removeGroup("page")
		end
	end

	function Pages.hasData(name: string): boolean
		local page = pageStore[name]
		return page ~= nil and next(page.data) ~= nil
	end

	function Pages.cleanup(name: string)
		Pages.close(name)
		pageStore[name] = nil
	end

	function Pages.reset(name: string)
		local page = pageEnsure(name)
		table.clear(page.data)
	end

	local HUB_GUI_NAMES = {
		TroyHub = true,
		TroyHubESP = true,
		TroyHubFOV = true,
		TroyHubKill = true,
		TroyHubTouch = true,
		-- Orphan names from the pre-rebrand inject. Destroy only; never bind.
		SamuraiHub = true,
		SamuraiHubESP = true,
		SamuraiHubFOV = true,
		SamuraiHubKill = true,
		SamuraiHubTouch = true,
	}

	local function isHubInstance(name: string): boolean
		return HUB_GUI_NAMES[name] == true
	end

	local function restoreDefaults()
		local EnvDefaults = Hub.EnvDefaults
		if not EnvDefaults then
			return
		end
		pcall(function()
			workspace.Gravity = EnvDefaults.Gravity
			player.CameraMaxZoomDistance = EnvDefaults.CameraZoom
			Lighting.GlobalShadows = EnvDefaults.GlobalShadows
			local cam = workspace.CurrentCamera
			if cam then
				cam.FieldOfView = EnvDefaults.FieldOfView
			end
			local hum = Hub.getHumanoid and Hub.getHumanoid()
			if hum then
				hum.WalkSpeed = 16
			end
		end)
	end

	local function destroyUI()
		pcall(function()
			if Hub.ScreenGui then
				Hub.ScreenGui:Destroy()
			end
		end)
		for _, g in playerGui:GetChildren() do
			if isHubInstance(g.Name) then
				pcall(function()
					g:Destroy()
				end)
			end
		end
	end

	local function removeGlobals()
		pcall(function()
			if rawget(_G, "TroyHubUnload") then
				rawset(_G, "TroyHubUnload", nil)
			end
			if rawget(_G, "TroyHub") == Hub then
				rawset(_G, "TroyHub", nil)
			end
		end)
		pcall(function()
			if shared.TroyHub == Hub then
				shared.TroyHub = nil
			end
			shared.TroyHubLoaded = nil
		end)
	end

	local function Unload()
		if Flags.Unloading then
			return
		end
		Flags.Unloading = true
		Flags.Closing = false
		if Hub.Lifecycle and Hub.Lifecycle.fireUnload then
			pcall(Hub.Lifecycle.fireUnload)
		end
		if Hub.Tasks then
			pcall(function()
				Hub.Tasks.cancelAll()
			end)
		end

		-- 1. disable all states / features
		local State = Hub.State
		if State then
			State.AutoGather = false
			State.PlayerESP = false
			State.ResourceESP = false
			State.Noclip = false
			State.Fly = false
			State.InfiniteJump = false
			State.Fullbright = false
			State.AimboT = false
			State.GatherAround = false
			State.LegitMode = false
			State.TeleportGather = false
			State.XRay = false
			State.EnableWalkSpeed = false
			State.PanicMode = true
		end
		if Hub.FeatureManager then
			pcall(function()
				Hub.FeatureManager.disableAll()
			end)
		end
		local hooks = Hub.hooks
		if hooks then
			for _, key in {
				"cancelMoveTween",
				"unlockMovement",
				"flightCleanup",
				"noclipCleanup",
				"infJumpCleanup",
				"fullbrightCleanup",
				"xrayCleanup",
				"aimbotCleanup",
			} do
				local fn = hooks[key]
				if type(fn) == "function" then
					pcall(fn)
				end
			end
		end
		pcall(function()
			RunService:UnbindFromRenderStep("TroyHubLighting")
		end)

		-- 2. stop scheduler jobs
		if Hub.Scheduler then
			Hub.Scheduler.clear()
		end

		-- 3. disconnect all signals
		disconnectAll()

		-- 4. clear page scope
		clearPageScope()
		for name in pageStore do
			Pages.cleanup(name)
		end
		table.clear(pageStore)

		-- 5. destroy UI
		if hooks and hooks.destroyFov then
			pcall(hooks.destroyFov)
		end
		destroyUI()

		-- 6. restore defaults
		restoreDefaults()

		removeGlobals()

		-- 8. clear registration tables
		if Hub.FeatureManager then
			pcall(function()
				Hub.FeatureManager.clear()
			end)
		end
		if Hub.Hotkeys then
			pcall(function()
				Hub.Hotkeys.clear()
			end)
		end
		table.clear(Connections)
		table.clear(connectionMap)

		print("[Troy] Unloaded")
	end

	local function CloseAndUnload()
		Unload()
	end

	local function installKillSwitch()
		local hubKill = Instance.new("BindableEvent")
		hubKill.Name = "TroyHubKill"
		hubKill.Parent = playerGui
		track(hubKill.Event:Connect(Unload))
		track(hubKill.AncestryChanged:Connect(function(_, parent)
			if parent == nil and not Flags.Unloading then
				Unload()
			end
		end))
	end

	local function bindGlobals()
		shared.TroyHub = Hub
		shared.TroyHub.Unload = Unload
		pcall(function()
			rawset(_G, "TroyHubUnload", function()
				local hub = (shared :: any).TroyHub
				if hub and type(hub.Unload) == "function" then
					hub.Unload()
				end
			end)
		end)
	end

	Hub.track = track
	Hub.trackNamed = trackNamed
	Hub.disconnectAll = disconnectAll
	Hub.trackPage = trackPage
	Hub.holdDebris = holdDebris
	Hub.clearPageScope = clearPageScope
	Hub.Pages = Pages
	Hub.isHubInstance = isHubInstance
	Hub.Unload = Unload
	Hub.CloseAndUnload = CloseAndUnload
	Hub.installKillSwitch = installKillSwitch
	Hub.bindGlobals = bindGlobals
	Hub.hooks = Hub.hooks or {}
	Hub.PageHooks = Hub.PageHooks or {}
	Hub.Connections = Connections
	return Hub
end
