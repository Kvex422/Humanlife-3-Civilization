--!strict
-- Extra profile layer on top of the in-app Config / Stealth tables.
-- Schema versioning + migration live here so future State shape changes
-- can rewrite old JSON without touching farm code.

return function(Hub: any)
	local ConfigX = {}

	ConfigX.profiles = {
		aggressive = "Fast",
		balanced = "Balanced",
		stealth = "Safe",
		["low-resource"] = "Safe",
		mobile = "Balanced",
		["high-precision"] = "Balanced",
	}

	local PROFILE_OVERRIDES = {
		["low-resource"] = {
			ResourceLimit = 32,
			PlayerMaxDist = 280,
			ResourceMaxDist = 220,
			TouchButton = true,
			UIScale = 1.1,
			AimboT = false,
		},
		mobile = {
			TouchButton = true,
			AutoUIScale = true,
			UIScale = 1.15,
			ShowFOVCircle = false,
		},
		["high-precision"] = {
			HitGap = 0.18,
			LegitHitDelay = 1.4,
			AimPrediction = true,
			AimPredictStrength = 10,
			FOVCheck = true,
			FOVRadius = 80,
		},
		aggressive = {
			PriorityWeight = 70,
			ClusterRadius = 70,
			SkipSeconds = 5,
		},
	}

	function ConfigX.applyProfile(name: string, notify: boolean?)
		local key = string.lower(name)
		local stealthName = ConfigX.profiles[key]
		if stealthName and Hub.Stealth and Hub.Stealth.apply then
			Hub.Stealth.apply(stealthName, false)
		end
		local extra = PROFILE_OVERRIDES[key]
		if extra and Hub.State then
			for k, v in extra do
				Hub.State[k] = v
			end
		end
		if Hub.validateState then
			Hub.validateState()
		end
		if notify and Hub.Notifications then
			Hub.Notifications.info("Profile", name)
		end
	end

	function ConfigX.migrate(blob: any): any
		if type(blob) ~= "table" then
			return blob
		end
		local schema = tonumber(blob.__schema) or 1
		if schema < 2 then
			blob.__schema = 2
			blob.__brand = "TroyHub"
		end
		return blob
	end

	function ConfigX.reload()
		if Hub.Config and Hub.Config.autoLoad then
			pcall(Hub.Config.autoLoad)
		end
		if Hub.validateState then
			Hub.validateState()
		end
	end

	Hub.ConfigX = ConfigX
	return Hub
end
