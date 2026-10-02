--!strict
-- Control-center snapshot: features, jobs, signals, errors, FPS, ping.

return function(Hub: any)
	local Stats = Hub.Services.Stats
	local bag = Hub.Diagnostics or {}
	bag.LastError = bag.LastError or ""
	bag.LastWarn = bag.LastWarn or ""
	bag.History = bag.History or {}

	local function pushHistory(kind: string, line: string)
		table.insert(bag.History, 1, {
			kind = kind,
			line = line,
			at = os.clock(),
		})
		while #bag.History > 24 do
			table.remove(bag.History)
		end
	end

	function bag.noteError(line: string)
		bag.LastError = line
		bag.LastErrorAt = os.clock()
		pushHistory("error", line)
	end

	function bag.noteWarn(line: string)
		bag.LastWarn = line
		pushHistory("warn", line)
	end

	function bag.snapshot(): { [string]: any }
		local ping = Hub.getPingMs and Hub.getPingMs() or 0
		local fps = Hub.FrameRate and Hub.FrameRate.fps or 0
		local mem = 0
		pcall(function()
			mem = Stats:GetTotalMemoryUsageMb()
		end)
		local jobs = {}
		if Hub.Scheduler and Hub.Scheduler.snapshot then
			jobs = Hub.Scheduler.snapshot()
		end
		local isolated = 0
		for _, job in jobs do
			if job.disabled then
				isolated += 1
			end
		end
		return {
			version = Hub.Version and Hub.Version.script or "?",
			schema = Hub.Version and Hub.Version.configSchema or 0,
			page = Hub.Flags.ActivePage,
			uptime = os.clock() - (Hub.Flags.StartedAt or os.clock()),
			fps = fps,
			ping = ping,
			memoryMb = mem,
			jobs = Hub.Scheduler and Hub.Scheduler.count and Hub.Scheduler.count() or 0,
			isolatedJobs = isolated,
			jobHealth = jobs,
			features = Hub.Registry and Hub.Registry.active() or (Hub.FeatureManager and Hub.FeatureManager.active() or {}),
			declared = Hub.Registry and Hub.Registry.list() or {},
			signals = Hub.Connections and #Hub.Connections or 0,
			lastError = bag.LastError,
			lastWarn = bag.LastWarn,
			history = bag.History,
			unloading = Hub.Flags.Unloading == true,
			safe = Hub.State and Hub.State.SafeMode or false,
			panic = Hub.State and Hub.State.PanicMode or false,
		}
	end

	function bag.start()
		if not Hub.Scheduler then
			return
		end
		Hub.Scheduler.add("diagnostics", "logic", 1, function()
			if Hub.Flags.Unloading then
				return
			end
			bag.LastSnap = bag.snapshot()
		end, { priority = 90, budget = 0.004, owner = "Diagnostics" })
	end

	Hub.Diagnostics = bag
	return Hub
end
