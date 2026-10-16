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

	-- Keys checked on the plot model, both as attributes and as child instances.
	-- Owner data in this game is not documented, so match anything plausible.
	local OWNER_KEYS = {
		"Owner", "owner", "OwnerName", "OwnerId", "OwnerUserId",
		"Player", "PlayerName", "UserId", "User", "Username",
		"Farmer", "FarmOwner", "OwnerPlayer", "PlotOwner",
	}

	local farmCache: { list: { Model }, at: number } = { list = {}, at = 0 }
	local ownerCache: { [Instance]: { cands: { any }, at: number } } = {}

	local function isFarmModel(inst: Instance): boolean
		return inst:IsA("Model") and string.sub(inst.Name, 1, 4) == "Farm"
	end

	-- Every plot model named "Farm*". Cached briefly: the farm loop asks for this
	-- several times a second and the plot set rarely changes.
	function Farming.farms(): { Model }
		local now = os.clock()
		if now - farmCache.at < 1 and #farmCache.list > 0 then
			local live = true
			for _, m in farmCache.list do
				if not m.Parent then
					live = false
					break
				end
			end
			if live then return farmCache.list end
		end
		farmCache.at = now
		local out: { Model } = {}
		local seen: { [Instance]: boolean } = {}
		local function add(inst: Instance)
			if isFarmModel(inst) and not seen[inst] then
				seen[inst] = true
				table.insert(out, inst :: Model)
			end
		end
		-- Preferred home, then fallbacks, then a shallow workspace sweep so a
		-- renamed container does not hide every plot.
		for _, name in { "Buildings", "Farms", "Plots", "FarmPlots" } do
			local container = workspace:FindFirstChild(name)
			if container then
				for _, child in container:GetChildren() do
					add(child)
				end
			end
		end
		if #out == 0 then
			for _, child in workspace:GetChildren() do
				if isFarmModel(child) then
					add(child)
				elseif child:IsA("Folder") or child:IsA("Model") then
					for _, sub in child:GetChildren() do
						add(sub)
					end
				end
			end
		end
		farmCache.list = out
		return out
	end

	-- The per-plot RemoteEvent the game uses for planting.
	function Farming.farmRemote(farm: Model): RemoteEvent?
		local r = farm:FindFirstChild("RemoteEvent")
		if r and r:IsA("RemoteEvent") then
			return r
		end
		local any = farm:FindFirstChildOfClass("RemoteEvent")
		if any then return any end
		return nil
	end

	-- Every plausible owner value on a plot (attributes first, then children).
	-- Cached briefly so the per-pass filter does no repeated FindFirstChild work.
	function Farming.ownerCandidates(farm: Model): { any }
		local now = os.clock()
		local hit = ownerCache[farm]
		if hit and now - hit.at < 2 then return hit.cands end
		local out: { any } = {}
		for _, key in OWNER_KEYS do
			local a = farm:GetAttribute(key)
			if a ~= nil then
				table.insert(out, a)
			end
		end
		for _, child in farm:GetChildren() do
			if child:IsA("ValueBase") then
				local cname = string.lower(child.Name)
				if string.find(cname, "owner", 1, true)
					or string.find(cname, "player", 1, true)
					or string.find(cname, "user", 1, true)
					or string.find(cname, "farmer", 1, true) then
					table.insert(out, (child :: any).Value)
				end
			end
		end
		local entry = { cands = out, at = os.clock() }
		ownerCache[farm] = entry
		return entry.cands
	end

	function Farming.hasOwnerInfo(farm: Model): boolean
		return #Farming.ownerCandidates(farm) > 0
	end

	local function identityMatches(candidate: any, name: string, display: string, uid: number): boolean
		if candidate == nil then return false end
		local kind = type(candidate)
		if kind == "number" then
			return candidate == uid
		end
		if kind == "string" then
			local c = string.lower(candidate)
			return c == string.lower(name) or c == string.lower(display) or c == tostring(uid)
		end
		if typeof(candidate) == "Instance" then
			local inst = candidate :: any
			if inst:IsA("Player") then
				return inst.UserId == uid
			end
			if inst:IsA("ValueBase") then
				return identityMatches(inst.Value, name, display, uid)
			end
			return inst.Name == name
		end
		return false
	end

	-- True only when a plot carries ownership info naming this player. A plot
	-- with no ownership info returns false, so "only my plots" never grabs a
	-- stranger's farm just because the owner field was missing.
	function Farming.ownedBy(farm: Model, player: any): boolean
		if not player then return false end
		local name = player.Name
		local display = player.DisplayName or name
		local uid = player.UserId
		for _, c in Farming.ownerCandidates(farm) do
			if identityMatches(c, name, display, uid) then
				return true
			end
		end
		return false
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
		return 6
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

	function Farming.resetCache()
		farmCache.at = 0
		table.clear(farmCache.list)
		table.clear(ownerCache)
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
