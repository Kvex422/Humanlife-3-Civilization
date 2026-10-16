--!strict
-- Farm feature registration, a selectable scoring helper, and discovery helpers
-- for the game's crop farm layout.
--
-- Concrete layout (confirmed against the game):
--   workspace.Buildings.Farm####            (Model, one per plot)
--     RemoteEvent:FireServer(cropName, farmName, slot)   -- plant, slot 1..6
--     ProximityPrompt with "Water" text                  -- water (fireproximityprompt)
--     crop instances named after the crop                -- harvest via Remotes.Gathering
--
-- Harvest reuses the hub's existing Gathering remote: fire it with the crop
-- instance, exactly like a tree or rock.

return function(Hub: any)
	local FM = Hub.FeatureManager
	local clampNum = Hub.clampNum

	local Selector = {}

	-- Lower is better. Distance is penalized with a mild curve so clustered
	-- high-value nodes still beat a lone tree underfoot when PriorityWeight
	-- is high, without letting a gold node 800 studs away win every time.
	function Selector.score(dist: number, kind: string, opts: any?): number
		local State = Hub.State
		local weight = clampNum(State.PriorityWeight, 0, 200, 40)
		local prioMap = State.ResourcePriority
		local prio = 1
		if type(prioMap) == "table" then
			prio = tonumber(prioMap[kind]) or 1
		end
		local curve = 1.12
		if opts and type(opts.curve) == "number" then
			curve = opts.curve
		end
		local penalty = dist ^ curve
		return penalty - (prio * weight)
	end

	Hub.Selector = Selector

	-- ============================================================
	--  FARM DISCOVERY
	-- ============================================================
	local Farming = {}

	local BUILDINGS = "Buildings"
	local SLOT_COUNT = 6

	local function isFarmModel(inst: Instance): boolean
		return inst:IsA("Model") and string.sub(inst.Name, 1, 4) == "Farm"
	end

	-- Every plot model under workspace.Buildings whose name starts with "Farm".
	function Farming.farms(): { Model }
		local out: { Model } = {}
		local buildings = workspace:FindFirstChild(BUILDINGS)
		if not buildings then return out end
		for _, child in buildings:GetChildren() do
			if isFarmModel(child) then
				table.insert(out, child :: Model)
			end
		end
		return out
	end

	-- The per-plot RemoteEvent the game uses for planting.
	function Farming.farmRemote(farm: Model): RemoteEvent?
		local r = farm:FindFirstChild("RemoteEvent")
		if r and r:IsA("RemoteEvent") then
			return r
		end
		return nil
	end

	-- Grown/harvestable crops: descendants named after a catalog crop.
	function Farming.crops(farm: Model): { Instance }
		local out: { Instance } = {}
		local fd = Hub.FarmData
		if not fd then return out end
		for _, desc in farm:GetDescendants() do
			if (desc:IsA("Model") or desc:IsA("BasePart")) and fd.names[desc.Name] then
				table.insert(out, desc)
			end
		end
		return out
	end

	-- "Water" ProximityPrompts under a plot.
	function Farming.waterPrompts(farm: Model): { ProximityPrompt }
		local out: { ProximityPrompt } = {}
		for _, desc in farm:GetDescendants() do
			if desc:IsA("ProximityPrompt") then
				local text = string.lower(tostring(desc.ActionText) .. " " .. tostring(desc.ObjectText))
				if string.find(text, "water", 1, true) then
					table.insert(out, desc :: ProximityPrompt)
				end
			end
		end
		return out
	end

	function Farming.slotCount(): number
		return SLOT_COUNT
	end

	-- Totals for the UI: farms found, ready crops, water prompts.
	function Farming.stats(): { farms: number, crops: number, water: number }
		local farms, crops, water = 0, 0, 0
		for _, farm in Farming.farms() do
			farms += 1
			crops += #Farming.crops(farm)
			water += #Farming.waterPrompts(farm)
		end
		return { farms = farms, crops = crops, water = water }
	end

	Hub.Farming = Farming

	if FM then
		FM.register({
			name = "AutoGather",
			stateKey = "AutoGather",
			safe = false,
			getEnabled = function()
				return Hub.State.AutoGather == true
			end,
			setEnabled = function(on)
				Hub.State.AutoGather = on
			end,
		})
		FM.register({
			name = "TeleportGather",
			stateKey = "TeleportGather",
			safe = false,
			getEnabled = function()
				return Hub.State.TeleportGather == true
			end,
			setEnabled = function(on)
				Hub.State.TeleportGather = on
			end,
		})
		FM.register({
			name = "GatherAround",
			stateKey = "GatherAround",
			safe = false,
			getEnabled = function()
				return Hub.State.GatherAround == true
			end,
			setEnabled = function(on)
				Hub.State.GatherAround = on
			end,
		})
		FM.register({
			name = "LegitMode",
			stateKey = "LegitMode",
			safe = true,
			getEnabled = function()
				return Hub.State.LegitMode == true
			end,
			setEnabled = function(on)
				Hub.State.LegitMode = on
			end,
		})
		FM.register({
			name = "AutoFarm",
			stateKey = "AutoFarm",
			safe = false,
			getEnabled = function()
				return Hub.State.AutoFarm == true
			end,
			setEnabled = function(on)
				Hub.State.AutoFarm = on
			end,
		})
	end

	return Hub
end
