--!strict
-- Static game data, farm session stats, versioning, and changelog.

return function(Hub: any)
	local Version = {
		script = "2.0.6",
		configSchema = 2,
		builtAt = "2026-10-03",
		compat = { "Humanlife 3: Civilization" },
		changelog = {
			"2.0.6  Teleport Gather pins in place, farm picks from the player not the camera, gather burst per swing.",
			"2.0.5  Hub layout (core/features/ui/config). Simple registry and lifecycle. JSON settings only.",
			"2.0.4  Registry-only toggles, feature bodies in src/features, Config JSON module.",
			"2.0.3  Feature registry, lifecycle, diagnostics, persistence.",
		},
	}

	local RESOURCE_NAMES = {
		["Tree"] = true, ["Cherry Tree"] = true, ["Rubber Tree"] = true,
		["Rock"] = true, ["Sand"] = true, ["Clay"] = true, ["Coal"] = true,
		["Copper"] = true, ["Gold"] = true, ["Iron"] = true, ["Tin"] = true,
		["Sulfur"] = true,
	}

	local RESOURCE_LIST = {
		"Tree", "Cherry Tree", "Rubber Tree", "Rock", "Sand",
		"Clay", "Coal", "Copper", "Gold", "Iron", "Tin", "Sulfur",
	}

	local SELL_STYLES = { "name_amount", "name_only", "amount_only", "all_name", "action_name" }

	local function fireSell(market, style: string, resourceName: string): boolean
		if style == "name_amount" then
			market:FireServer(resourceName, 1)
		elseif style == "name_only" then
			market:FireServer(resourceName)
		elseif style == "amount_only" then
			market:FireServer(1)
		elseif style == "all_name" then
			market:FireServer(resourceName, "all")
		elseif style == "action_name" then
			market:FireServer("sell", resourceName, 1)
		else
			return false
		end
		return true
	end

	local FarmStats = {
		runSeconds = 0,
		nodes = 0,
		swings = 0,
		byKind = {} :: { [string]: number },
		startedAt = os.clock(),
		lastResetAt = os.clock(),
		bestCluster = 0,
		lastKind = "",
	}

	function FarmStats.reset()
		FarmStats.runSeconds = 0
		FarmStats.nodes = 0
		FarmStats.swings = 0
		table.clear(FarmStats.byKind)
		FarmStats.lastResetAt = os.clock()
		FarmStats.bestCluster = 0
		FarmStats.lastKind = ""
	end

	function FarmStats.nodesPerMinute(): number
		local secs = math.max(FarmStats.runSeconds, 1)
		return (FarmStats.nodes / secs) * 60
	end

	function FarmStats.avgSwings(): number
		if FarmStats.nodes <= 0 then
			return 0
		end
		return FarmStats.swings / FarmStats.nodes
	end

	function FarmStats.topKind(): string
		local best, n = "", 0
		for kind, count in FarmStats.byKind do
			if count > n then
				best = kind
				n = count
			end
		end
		return best
	end

	function FarmStats.noteSwing()
		FarmStats.swings += 1
	end

	function FarmStats.noteNode(kind: string?)
		FarmStats.nodes += 1
		if kind then
			FarmStats.byKind[kind] = (FarmStats.byKind[kind] or 0) + 1
			FarmStats.lastKind = kind
		end
	end

	function FarmStats.perMinute(): number
		return FarmStats.nodesPerMinute()
	end

	function FarmStats.clock(): string
		local total = math.floor(FarmStats.runSeconds)
		return string.format("%02d:%02d:%02d",
			math.floor(total / 3600), math.floor(total % 3600 / 60), total % 60)
	end

	function FarmStats.topKinds(limit: number): string
		local rows = {}
		for kind, n in FarmStats.byKind do
			table.insert(rows, { kind = kind, n = n })
		end
		table.sort(rows, function(a, b)
			return a.n > b.n
		end)
		local parts = {}
		for i = 1, math.min(#rows, limit) do
			table.insert(parts, string.format("%s x%d", rows[i].kind, rows[i].n))
		end
		if #parts == 0 then
			return "nothing yet"
		end
		return table.concat(parts, "  ·  ")
	end

	Hub.Version = Version
	Hub.RESOURCE_NAMES = RESOURCE_NAMES
	Hub.RESOURCE_LIST = RESOURCE_LIST
	Hub.SELL_STYLES = SELL_STYLES
	Hub.fireSell = fireSell
	Hub.FarmStats = FarmStats
	Hub.Data = {
		RESOURCE_NAMES = RESOURCE_NAMES,
		RESOURCE_LIST = RESOURCE_LIST,
		SELL_STYLES = SELL_STYLES,
		fireSell = fireSell,
		FarmStats = FarmStats,
		Version = Version,
	}
	return Hub
end
