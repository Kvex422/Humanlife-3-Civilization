--!strict
-- TroyHub entry. The bundler inlines every module above this file and
-- provides import(name). Studio can swap import for require.

return function(import: (string) -> any)
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Lighting = game:GetService("Lighting")
	local TeleportService = game:GetService("TeleportService")
	local Stats = game:GetService("Stats")
	local HttpService = game:GetService("HttpService")
	local GuiService = game:GetService("GuiService")
	local ProximityPromptService = game:GetService("ProximityPromptService")

	local player = Players.LocalPlayer
	if not player then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		player = Players.LocalPlayer
	end
	local playerGui = player:WaitForChild("PlayerGui")

	-- Previous inject: deterministic unload first, then the guard.
	pcall(function()
		local prev = (shared :: any).TroyHub
		if prev and type(prev.Unload) == "function" then
			prev.Unload()
		else
			local raw = rawget(_G, "TroyHubUnload")
			if typeof(raw) ~= "function" then
				raw = rawget(_G, "SamuraiHubUnload")
			end
			if typeof(raw) == "function" then
				raw()
			end
		end
	end)

	if (shared :: any).TroyHubLoaded then
		return
	end
	(shared :: any).TroyHubLoaded = true

	local Hub: any = {
		Flags = {
			Unloading = false,
			keybindCapturing = false,
			ActivePage = "Dashboard",
			Closing = false,
			StartedAt = os.clock(),
		},
		Diagnostics = {},
		hooks = {},
		PageHooks = {},
		FrameRate = { fps = 60 },
		player = player,
		playerGui = playerGui,
		Services = {
			Players = Players,
			UserInputService = UserInputService,
			RunService = RunService,
			TweenService = TweenService,
			ReplicatedStorage = ReplicatedStorage,
			Lighting = Lighting,
			TeleportService = TeleportService,
			Stats = Stats,
			HttpService = HttpService,
			GuiService = GuiService,
			ProximityPromptService = ProximityPromptService,
		},
	}

	local function load(name: string)
		local factory = import(name)
		if type(factory) ~= "function" then
			error("TroyHub module '" .. name .. "' did not return a factory")
		end
		factory(Hub)
	end

	load("utils")
	load("logger")
	load("data")
	load("constants")
	load("state")
	load("theme")
	load("cleanup")
	load("tasks")
	load("scheduler")
	load("lifecycle")
	load("featureManager")
	load("hotkeys")

	Hub.Scheduler.start()
	Hub.Scheduler.add("framerate", "render", 0, function(dt)
		if dt > 0 then
			Hub.FrameRate.fps = Hub.FrameRate.fps * 0.9 + (1 / dt) * 0.1
		end
	end, { priority = 1, budget = 0.002 })

	load("app")
	load("config")
	load("gui")
	load("features/movement")
	load("features/utility")
	load("features/esp")
	load("features/combat")
	load("features/farming")

	if Hub.FEATURE_SETTERS then
		Hub.FeatureManager.adoptSetters(Hub.FEATURE_SETTERS, Hub.toggleSync)
	end
	if Hub.Hotkeys then
		pcall(function()
			Hub.Hotkeys.adoptState()
		end)
	end

	Hub.bindGlobals()
	Hub.installKillSwitch()

	if Hub.log then
		local n = 0
		pcall(function()
			if Hub.ResourceScanner then
				n = Hub.ResourceScanner.count()
			end
		end)
		Hub.log(string.format("v%s ready  ·  %d nodes indexed", Hub.Version.script, n))
	end

	return Hub
end
