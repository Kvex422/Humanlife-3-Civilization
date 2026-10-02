--!strict
-- Shared GUI helpers: diagnostics snapshot, debug console, animation helpers,
-- panic/safe/recovery. Widget factories stay in the runtime so they keep
-- their Content / Theme closures.

return function(Hub: any)
	local Stats = Hub.Services.Stats
	local Gui = {}

	function Gui.animateHover(inst, hoverProps, restProps)
		if not inst then
			return
		end
		Hub.track(inst.MouseEnter:Connect(function()
			Hub.tween(inst, hoverProps, 0.12)
		end))
		Hub.track(inst.MouseLeave:Connect(function()
			Hub.tween(inst, restProps, 0.12)
		end))
	end

	function Gui.clickSquish(button)
		if not button then
			return
		end
		Hub.track(button.MouseButton1Down:Connect(function()
			Hub.tween(button, { Size = button.Size - UDim2.fromOffset(0, 2) }, 0.06)
		end))
		Hub.track(button.MouseButton1Up:Connect(function()
			Hub.tween(button, { Size = button.Size + UDim2.fromOffset(0, 2) }, 0.08)
		end))
	end

	function Gui.diagnostics(): { [string]: any }
		local State = Hub.State
		local ping = Hub.getPingMs and Hub.getPingMs() or 0
		local fps = Hub.FrameRate and Hub.FrameRate.fps or 0
		local jobs = Hub.Scheduler and Hub.Scheduler.snapshot and Hub.Scheduler.snapshot() or {}
		local mem = 0
		pcall(function()
			mem = Stats:GetTotalMemoryUsageMb()
		end)
		return {
			version = Hub.Version and Hub.Version.script or "?",
			page = Hub.Flags.ActivePage,
			fps = fps,
			ping = ping,
			memoryMb = mem,
			jobs = Hub.Scheduler and Hub.Scheduler.count and Hub.Scheduler.count() or 0,
			jobHealth = jobs,
			features = Hub.FeatureManager and Hub.FeatureManager.active() or {},
			signals = Hub.Connections and #Hub.Connections or 0,
			lastError = Hub.Diagnostics and Hub.Diagnostics.LastError or "",
			unloading = Hub.Flags.Unloading == true,
			safe = State and State.SafeMode or false,
			panic = State and State.PanicMode or false,
		}
	end

	function Gui.panic()
		local State = Hub.State
		if State then
			State.PanicMode = true
			State.SafeMode = true
		end
		if Hub.FeatureManager then
			Hub.FeatureManager.disableAll()
		end
		if Hub.Notifications then
			Hub.Notifications.warn("Panic", "All features stopped")
		end
	end

	function Gui.safeMode(on: boolean)
		if Hub.State then
			Hub.State.SafeMode = on
		end
		if on and Hub.FeatureManager then
			for _, name in Hub.FeatureManager.list() do
				local spec = Hub.FeatureManager.get(name)
				if spec and spec.safe == false and Hub.FeatureManager.isEnabled(name) then
					Hub.FeatureManager.set(name, false, false)
				end
			end
		end
	end

	function Gui.recovery()
		if Hub.Flags.Unloading then
			return
		end
		if Hub.State then
			Hub.State.PanicMode = false
		end
		if Hub.ScreenGui then
			Hub.ScreenGui.Enabled = true
		end
		if Hub.Notifications then
			Hub.Notifications.success("Recovery", "UI restored")
		end
	end

	local COMMANDS = {
		help = function()
			return "help, toggle, reload, reset, debug, dump, clear, panic, safe, recovery, profile"
		end,
		toggle = function(name)
			if not name or not Hub.FeatureManager then
				return "usage: /toggle <feature>"
			end
			local on = not Hub.FeatureManager.isEnabled(name)
			Hub.FeatureManager.set(name, on, true)
			return name .. " " .. (on and "on" or "off")
		end,
		reload = function()
			if Hub.ConfigX then
				Hub.ConfigX.reload()
			end
			return "config reloaded"
		end,
		reset = function()
			if Hub.FarmStats then
				Hub.FarmStats.reset()
			end
			return "stats reset"
		end,
		debug = function(arg)
			if Hub.State then
				Hub.State.DebugMode = arg ~= "off"
			end
			return "debug " .. tostring(Hub.State and Hub.State.DebugMode)
		end,
		dump = function()
			local snap = Gui.diagnostics()
			return string.format("v%s fps=%.0f ping=%d jobs=%s features=%d",
				tostring(snap.version), snap.fps, snap.ping, tostring(snap.jobs),
				snap.features and #snap.features or 0)
		end,
		clear = function()
			if Hub.State then
				table.clear(Hub.State._debugLog)
			end
			return "logs cleared"
		end,
		panic = function()
			Gui.panic()
			return "panic"
		end,
		safe = function()
			Gui.safeMode(true)
			return "safe mode"
		end,
		recovery = function()
			Gui.recovery()
			return "recovery"
		end,
		profile = function(name)
			if Hub.ConfigX and name then
				Hub.ConfigX.applyProfile(name, true)
				return "profile " .. name
			end
			return "usage: /profile aggressive|balanced|stealth|low-resource|mobile|high-precision"
		end,
	}

	function Gui.runCommand(line: string): string
		local text = string.gsub(line, "^%s*/", "")
		local cmd, rest = string.match(text, "^(%S+)%s*(.*)$")
		if not cmd then
			return ""
		end
		local fn = COMMANDS[string.lower(cmd)]
		if not fn then
			return "unknown command"
		end
		local ok, result = pcall(fn, rest ~= "" and rest or nil)
		if not ok then
			return tostring(result)
		end
		return tostring(result or "ok")
	end

	Hub.Gui = Gui
	Hub.panic = Gui.panic
	Hub.safeMode = Gui.safeMode
	Hub.recovery = Gui.recovery
	return Hub
end
