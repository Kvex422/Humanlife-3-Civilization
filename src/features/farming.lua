--!strict
-- Farm feature registration plus a selectable scoring helper the runtime
-- can call without duplicating the live scanner.

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
	end

	return Hub
end
