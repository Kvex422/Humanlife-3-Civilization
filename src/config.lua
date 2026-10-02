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

	local Persistence = {}
	local ATTR_SCHEMA = "TroyHubConfigSchema"
	local ATTR_SAVED = "TroyHubSavedAt"

	local function stampPlayer()
		pcall(function()
			Hub.player:SetAttribute(ATTR_SCHEMA, Hub.Version and Hub.Version.configSchema or 2)
			Hub.player:SetAttribute(ATTR_SAVED, os.time())
		end)
	end

	function Persistence.save(): boolean
		local ok = false
		if Hub.Config and Hub.Config.save then
			ok = Hub.Config.save() == true
		end
		if ok then
			stampPlayer()
		end
		return ok
	end

	function Persistence.load(): boolean
		if Hub.Config and Hub.Config.load then
			return Hub.Config.load() == true
		end
		return false
	end

	function Persistence.reload()
		ConfigX.reload()
	end

	function Persistence.export(): string?
		if Hub.Config and Hub.Config.serialize then
			return Hub.Config.serialize()
		end
		return nil
	end

	function Persistence.applyProfile(name: string, notify: boolean?)
		ConfigX.applyProfile(name, notify)
		if Hub.Config and Hub.Config.save then
			pcall(Hub.Config.save)
		end
		stampPlayer()
	end

	function Persistence.lastSavedAt(): number?
		local v = Hub.player:GetAttribute(ATTR_SAVED)
		if type(v) == "number" then
			return v
		end
		return nil
	end

	Hub.ConfigX = ConfigX
	Hub.Persistence = Persistence
	return Hub
end
