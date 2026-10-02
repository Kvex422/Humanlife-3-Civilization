--!strict
-- Two root connections (Heartbeat / RenderStepped). Jobs are namespaced,
-- prioritized, isolated after repeated errors, and cannot re-enter add()
-- from inside their own callback.

return function(Hub: any)
	local RunService = Hub.Services.RunService
	local Flags = Hub.Flags

	type Job = {
		fn: (number) -> (),
		interval: number,
		last: number,
		errors: number,
		priority: number,
		group: string,
		owner: string?,
		budget: number,
		disabled: boolean,
		totalMs: number,
		runs: number,
		lastMs: number,
	}

	local Scheduler = {}
	local phases: { [string]: { [string]: Job } } = { render = {}, logic = {} }
	local runningName: string? = nil
	local MAX_ERRORS = 12
	local DEFAULT_BUDGET = 0.008

	local function jobKey(group: string, name: string): string
		if group == "" or group == "root" then
			return name
		end
		return group .. ":" .. name
	end

	local function sortedNames(list: { [string]: Job }): { string }
		local names = {}
		for name in list do
			table.insert(names, name)
		end
		table.sort(names, function(a, b)
			local ja, jb = list[a], list[b]
			if ja.priority == jb.priority then
				return a < b
			end
			return ja.priority < jb.priority
		end)
		return names
	end

	local function runPhase(phaseName: string, dt: number)
		if Flags.Unloading then
			return
		end
		local now = os.clock()
		local list = phases[phaseName]
		for _, name in sortedNames(list) do
			local job = list[name]
			if not job or job.disabled then
				continue
			end
			if job.owner and Hub.FeatureManager and Hub.FeatureManager.get(job.owner) then
				if not Hub.FeatureManager.isEnabled(job.owner) then
					continue
				end
			end
			if job.interval > 0 and (now - job.last) < job.interval then
				continue
			end
			job.last = now
			runningName = name
			local started = os.clock()
			local ok, err = pcall(job.fn, dt)
			local elapsed = os.clock() - started
			runningName = nil
			job.lastMs = elapsed * 1000
			job.totalMs += elapsed * 1000
			job.runs += 1
			if elapsed > job.budget and Hub.Logger then
				Hub.Logger.debug(string.format("Job '%s' over budget %.2fms", name, job.lastMs))
			end
			if not ok then
				job.errors += 1
				if job.errors <= 2 and Hub.log then
					Hub.log("Task '" .. name .. "' error: " .. tostring(err))
				end
				if job.errors >= MAX_ERRORS then
					job.disabled = true
					if Hub.log then
						Hub.log("Task '" .. name .. "' isolated after repeated errors")
					end
				end
			end
		end
	end

	function Scheduler.add(name: string, phaseName: string, interval: number, fn: (number) -> (), opts: any?)
		if Flags.Unloading then
			return
		end
		local options = opts or {}
		local group = options.group or "root"
		local key = jobKey(group, name)
		if runningName == key then
			if Hub.Logger then
				Hub.Logger.warn("Scheduler.add('" .. key .. "') ignored (job re-entered itself)")
			end
			return
		end
		local phase = phases[phaseName]
		if not phase then
			return
		end
		phase[key] = {
			fn = fn,
			interval = interval,
			last = 0,
			errors = 0,
			priority = options.priority or 50,
			group = group,
			owner = options.owner or Flags.SchedulingOwner,
			budget = options.budget or DEFAULT_BUDGET,
			disabled = false,
			totalMs = 0,
			runs = 0,
			lastMs = 0,
		}
	end

	function Scheduler.remove(name: string)
		phases.render[name] = nil
		phases.logic[name] = nil
	end

	function Scheduler.removeGroup(group: string)
		local prefix = group .. ":"
		for _, list in phases do
			for name in list do
				if string.sub(name, 1, #prefix) == prefix then
					list[name] = nil
				end
			end
		end
	end

	function Scheduler.removeByOwner(owner: string)
		for _, list in phases do
			for name, job in list do
				if job.owner == owner then
					list[name] = nil
				end
			end
		end
	end

	function Scheduler.removePages()
		Scheduler.removeGroup("page")
		for _, list in phases do
			for name in list do
				if string.sub(name, 1, 5) == "page:" then
					list[name] = nil
				end
			end
		end
	end

	function Scheduler.clear()
		table.clear(phases.render)
		table.clear(phases.logic)
	end

	function Scheduler.snapshot(): { { name: string, phase: string, errors: number, lastMs: number, disabled: boolean } }
		local out = {}
		for phaseName, list in phases do
			for name, job in list do
				table.insert(out, {
					name = name,
					phase = phaseName,
					errors = job.errors,
					lastMs = job.lastMs,
					disabled = job.disabled,
					runs = job.runs,
					priority = job.priority,
				})
			end
		end
		return out
	end

	function Scheduler.count(): number
		local n = 0
		for _, list in phases do
			for _ in list do
				n += 1
			end
		end
		return n
	end

	function Scheduler.start()
		Hub.track(RunService.RenderStepped:Connect(function(dt)
			runPhase("render", dt)
		end))
		Hub.track(RunService.Heartbeat:Connect(function(dt)
			runPhase("logic", dt)
		end))
	end

	Hub.Scheduler = Scheduler
	return Hub
end
