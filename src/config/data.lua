--!strict
-- Static game data, farm session stats, versioning, and changelog.

return function(Hub: any)
	local Version = {
		script = "2.0.15",
		configSchema = 2,
		builtAt = "2026-10-15",
		compat = { "Humanlife 3: Civilization" },
		changelog = {
			"2.0.15  Crop farm: plant per-plot RemoteEvent, water via prompt, harvest via gathering remote.",
			"2.0.14  Farming page: auto-harvest crops and animals, learned farm remote, anti-cheat WalkSpeed guard.",
			"2.0.13  Fix accent recolour recursion, smoothness clamp, cham slot leak, stale aim toggle and pin state.",
			"2.0.12  Harvest is always a bare node hit. Tool spoof is bonus damage only.",
			"2.0.11  Catalog tool spoof without owning one. Single gather fire path, no duplicate payloads.",
			"2.0.10  Shop tools: Flint/Bronze pick vs axe by node type.",
			"2.0.9  Teleport Gather unanchors to harvest, resource HP reads native bars, pickaxe spoof.",
			"2.0.8  Player ESP skeleton, chams, deaths/gold/job/age. Resource health bar.",
			"2.0.7  Overpower: same-tick gather burst, learned payload, client power spoof.",
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

	-- Farming catalog, mirrored from the game's ReplicatedStorage.Farming_Module.
	-- Crops carry a grow Time (s), a temperature band, a level gate and the
	-- classes/regions allowed to plant them. Animals carry a feed Cost instead
	-- of a temperature band. Names must match the instances the game spawns in
	-- the world, because the scanner matches on Name.
	local CROPS: { [string]: any } = {
		Wheat = { Name = "Wheat", Time = 4, MinTemp = 0, MaxTemp = 30, Level = 3, Class = { "Farmer", "Chef" }, Ethnicity = { "Europe", "Africa", "India", "Oceania", "Middle East", "China", "North America", "South America", "North America Euro" } },
		Carrot = { Name = "Carrot", Time = 2, MinTemp = 0, MaxTemp = 30, Level = 0, Class = { "Farmer", "Chef" }, Ethnicity = { "Europe", "Africa", "Oceania", "North America Euro" } },
		Cabbage = { Name = "Cabbage", Time = 6, MinTemp = 0, MaxTemp = 30, Level = 5, Class = { "Farmer", "Chef" }, Ethnicity = { "Europe", "North America Euro" } },
		Berry = { Name = "Berry", Time = 2, MinTemp = 0, MaxTemp = 32, Level = 0, Class = { "Farmer", "Chef" }, Ethnicity = { "North America", "North America Euro" } },
		Corn = { Name = "Corn", Time = 4, MinTemp = 0, MaxTemp = 32, Level = 3, Class = { "Farmer", "Chef" }, Ethnicity = { "North America", "South America", "North America Euro" } },
		Pumpkin = { Name = "Pumpkin", Time = 8, MinTemp = 0, MaxTemp = 32, Level = 5, Class = { "Farmer", "Chef" }, Ethnicity = { "North America", "North America Euro" } },
		Tomato = { Name = "Tomato", Time = 2, MinTemp = 0, MaxTemp = 32, Level = 0, Class = { "Farmer", "Chef" }, Ethnicity = { "South America" } },
		Potato = { Name = "Potato", Time = 6, MinTemp = 0, MaxTemp = 32, Level = 5, Class = { "Farmer", "Chef" }, Ethnicity = { "South America", "Africa" } },
		Coffee = { Name = "Coffee", Time = 2, MinTemp = 0, MaxTemp = 32, Level = 0, Class = { "Farmer", "Chef", "Doctor" }, Ethnicity = { "Africa" } },
		Watermelon = { Name = "Watermelon", Time = 8, MinTemp = 0, MaxTemp = 32, Level = 5, Class = { "Farmer", "Chef" }, Ethnicity = { "Africa" } },
		["Soy Beans"] = { Name = "Soy Beans", Time = 2, MinTemp = 0, MaxTemp = 32, Level = 0, Class = { "Farmer", "Chef" }, Ethnicity = { "China" } },
		Rice = { Name = "Rice", Time = 4, MinTemp = 0, MaxTemp = 32, Level = 3, Class = { "Farmer", "Chef" }, Ethnicity = { "China", "Oceania" } },
		["Bok Choy"] = { Name = "Bok Choy", Time = 6, MinTemp = 0, MaxTemp = 32, Level = 5, Class = { "Farmer", "Chef" }, Ethnicity = { "China" } },
		Beet = { Name = "Beet", Time = 2, MinTemp = 0, MaxTemp = 32, Level = 0, Class = { "Farmer", "Chef" }, Ethnicity = { "Middle East" } },
		Onion = { Name = "Onion", Time = 4, MinTemp = 0, MaxTemp = 32, Level = 5, Class = { "Farmer", "Chef" }, Ethnicity = { "Middle East" } },
		Cucumber = { Name = "Cucumber", Time = 2, MinTemp = 0, MaxTemp = 32, Level = 0, Class = { "Farmer", "Chef" }, Ethnicity = { "India" } },
		Eggplant = { Name = "Eggplant", Time = 4, MinTemp = 0, MaxTemp = 32, Level = 5, Class = { "Farmer" }, Ethnicity = { "India" } },
		["Tea Leaf"] = { Name = "Tea Leaf", Time = 4, MinTemp = 0, MaxTemp = 32, Level = 15, Class = { "Farmer", "Doctor" }, Ethnicity = { "India" } },
		Banana = { Name = "Banana", Time = 8, MinTemp = 0, MaxTemp = 32, Level = 6, Class = { "Farmer" }, Ethnicity = { "Oceania" } },
		["Heal Root"] = { Name = "Heal Root", Time = 5, MinTemp = 0, MaxTemp = 30, Level = 6, Class = { "Farmer", "Doctor" }, Ethnicity = { "Europe", "Africa", "China", "North America", "South America", "India", "Oceania", "Middle East", "North America Euro" } },
		Cotton = { Name = "Cotton", Time = 6, MinTemp = 0, MaxTemp = 30, Level = 10, Class = { "Farmer", "Doctor" }, Ethnicity = { "Europe", "Africa", "China", "North America", "South America", "India", "Oceania", "Middle East", "North America Euro" } },
		Sage = { Name = "Sage", Time = 5, MinTemp = 0, MaxTemp = 32, Level = 15, Class = { "Farmer", "Doctor" }, Ethnicity = { "Europe", "Africa", "China", "North America", "South America", "India", "Oceania", "Middle East", "North America Euro" } },
	}

	local ANIMALS: { [string]: any } = {
		Cow = { Name = "Cow", Time = 5, Level = 0, Class = { "Rancher" }, Cost = { Name = "Wheat", Amount = 2 }, Ethnicity = { "Europe", "Africa", "India", "Oceania", "Middle East", "China", "North America", "South America", "North America Euro" } },
		Bull = { Name = "Bull", Time = 5, Level = 3, Class = { "Rancher" }, Cost = { Name = "Wheat", Amount = 2 }, Ethnicity = { "Europe", "Africa", "India", "Oceania", "Middle East", "China", "North America", "South America", "North America Euro" } },
		["Dairy Cow"] = { Name = "Dairy Cow", Time = 5, Level = 5, Class = { "Rancher" }, Cost = { Name = "Wheat", Amount = 2 }, Ethnicity = { "Europe", "Africa", "India", "Oceania", "Middle East", "China", "North America", "South America", "North America Euro" } },
	}

	-- Ordered list for dropdowns and the scanner, plus a name -> kind lookup so a
	-- single workspace Name is enough to classify an instance.
	local FARM_LIST: { string } = {}
	local FARM_NAMES: { [string]: string } = {}
	for name, def in CROPS do
		table.insert(FARM_LIST, name)
		FARM_NAMES[name] = "Crop"
		def.Kind = "Crop"
	end
	for name, def in ANIMALS do
		table.insert(FARM_LIST, name)
		FARM_NAMES[name] = "Animal"
		def.Kind = "Animal"
	end
	table.sort(FARM_LIST, function(a: string, b: string)
		local ka, kb = FARM_NAMES[a], FARM_NAMES[b]
		if ka ~= kb then return ka < kb end
		return a < b
	end)

	local FarmData = {
		crops = CROPS,
		animals = ANIMALS,
		list = FARM_LIST,
		names = FARM_NAMES,
		isCrop = function(name: string): boolean
			return FARM_NAMES[name] == "Crop"
		end,
		isAnimal = function(name: string): boolean
			return FARM_NAMES[name] == "Animal"
		end,
		kindOf = function(name: string): string?
			return FARM_NAMES[name]
		end,
		def = function(name: string): any?
			return CROPS[name] or ANIMALS[name]
		end,
	}

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
	Hub.FarmData = FarmData
	Hub.Data = {
		RESOURCE_NAMES = RESOURCE_NAMES,
		RESOURCE_LIST = RESOURCE_LIST,
		SELL_STYLES = SELL_STYLES,
		fireSell = fireSell,
		FarmStats = FarmStats,
		FarmData = FarmData,
		Version = Version,
	}
	return Hub
end
