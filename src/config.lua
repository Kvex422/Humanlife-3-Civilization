--!strict
-- Config persistence. JSON file is the user profile; Hub.Config is that API.
-- Schema migration and named profiles live here so farm code never encodes JSON.

return function(Hub: any)
	local HttpService = Hub.Services.HttpService
	local player = Hub.player
	local clampNum = Hub.clampNum
	local State = Hub.State
	local EnvDefaults = Hub.EnvDefaults

	local function toast(kind: string, title: string, message: string)
		local N = Hub.Notifications
		if N and N[kind] then
			pcall(N[kind], title, message)
		elseif Hub.log then
			Hub.log(title .. ": " .. message)
		end
	end

	local Config = {}
	local FILE = "TroyHub_config.json"
	local LEGACY_FILE = "SamuraiHub_config.json"

	local function enumToString(v: EnumItem): string
		return tostring(v)
	end

	local function enumFromString(s: string): EnumItem?
		local class, name = string.match(s, "^Enum%.([%w_]+)%.([%w_]+)$")
		if not class or not name then
			return nil
		end
		local ok, item = pcall(function()
			return (Enum :: any)[class][name]
		end)
		if ok and typeof(item) == "EnumItem" then
			return item
		end
		return nil
	end

	local function encodeValue(v: any): any
		local t = typeof(v)
		if t == "boolean" or t == "number" or t == "string" then
			return v
		end
		if t == "EnumItem" then
			return { __kind = "enum", v = enumToString(v) }
		end
		if t == "Color3" then
			return { __kind = "color", r = v.R, g = v.G, b = v.B }
		end
		if t == "table" then
			local out = {}
			local kind: string? = nil
			for k, sub in v do
				local st = type(sub)
				if type(k) ~= "string" or (st ~= "boolean" and st ~= "number") then
					return nil
				end
				if kind and kind ~= st then
					return nil
				end
				kind = st
				out[k] = sub
			end
			if kind == "boolean" then
				return { __kind = "flags", v = out }
			end
			if kind == "number" then
				return { __kind = "nums", v = out }
			end
		end
		return nil
	end

	local function decodeValue(stored: any, current: any): any
		local ct = typeof(current)
		if type(stored) ~= "table" then
			if typeof(stored) == ct then
				return stored
			end
			return nil
		end
		if stored.__kind == "enum" and ct == "EnumItem" then
			local item = enumFromString(tostring(stored.v))
			if item and item.EnumType == current.EnumType then
				return item
			end
			return nil
		end
		if stored.__kind == "color" and ct == "Color3" then
			return Color3.new(
				math.clamp(tonumber(stored.r) or 0, 0, 1),
				math.clamp(tonumber(stored.g) or 0, 0, 1),
				math.clamp(tonumber(stored.b) or 0, 0, 1)
			)
		end
		if stored.__kind == "flags" and ct == "table" then
			local out = {}
			for k, existing in current do
				local incoming = (stored.v or {})[k]
				out[k] = if type(incoming) == "boolean" then incoming else existing
			end
			return out
		end
		if stored.__kind == "nums" and ct == "table" then
			local out = {}
			for k, existing in current do
				local incoming = (stored.v or {})[k]
				out[k] = if type(incoming) == "number" and incoming == incoming
					then math.clamp(incoming, 0, 100)
					else existing
			end
			return out
		end
		return nil
	end

	local defaults = {}
	for key, value in State do
		if string.sub(key, 1, 1) ~= "_" then
			local enc = encodeValue(value)
			if enc ~= nil then
				defaults[key] = enc
			end
		end
	end

	function Config.serialize(): string?
		local payload = {
			version = 1,
			__schema = Hub.Version and Hub.Version.configSchema or 2,
			__brand = "TroyHub",
			saved = os.time(),
			state = {},
		}
		for key, value in State do
			if string.sub(key, 1, 1) ~= "_" then
				local enc = encodeValue(value)
				if enc ~= nil then
					payload.state[key] = enc
				end
			end
		end
		local ok, text = pcall(function()
			return HttpService:JSONEncode(payload)
		end)
		if ok and type(text) == "string" then
			return text
		end
		return nil
	end

	function Config.applyTable(incoming: any): number
		if type(incoming) ~= "table" then
			return 0
		end
		local applied = 0
		for key, stored in incoming do
			local current = State[key]
			if current ~= nil and string.sub(key, 1, 1) ~= "_" then
				local value = decodeValue(stored, current)
				if value ~= nil then
					State[key] = value
					applied += 1
				end
			end
		end
		if Hub.FeatureManager then
			for _, name in Hub.FeatureManager.list() do
				local spec = Hub.FeatureManager.get(name)
				if spec then
					local key = spec.stateKey or name
					pcall(function()
						Hub.FeatureManager.set(name, State[key] == true, false)
					end)
				end
			end
		end
		pcall(function()
			workspace.Gravity = clampNum(State.Gravity, 0, 1000, EnvDefaults.Gravity)
			player.CameraMaxZoomDistance = clampNum(State.CamZoom, 0.5, 5000, EnvDefaults.CameraZoom)
			local cam = workspace.CurrentCamera
			if cam then
				cam.FieldOfView = clampNum(State.FOV, 1, 120, EnvDefaults.FieldOfView)
			end
			local hum = Hub.getHumanoid and Hub.getHumanoid()
			if hum and Hub.applyWalkSettings then
				Hub.applyWalkSettings(hum)
			end
			local a = State.ThemeAccent
			local Theme = Hub.Theme
			if Theme and typeof(a) == "Color3" and a.B > 0.65 and a.B > a.R + 0.1 then
				State.ThemeAccent = Theme.Accent
				State.ThemeAccent2 = Theme.Accent2
				State.FOVColor = Theme.Accent
			end
		end)
		if Hub.validateState then
			pcall(Hub.validateState)
		end
		if Hub.Lifecycle and Hub.Lifecycle.emit then
			Hub.Lifecycle.emit("settingsReloaded")
		end
		task.defer(function()
			if Hub.Flags.Unloading then
				return
			end
			if Hub.rerenderCurrentPage then
				pcall(Hub.rerenderCurrentPage)
			end
		end)
		return applied
	end

	function Config.deserialize(text: string): number
		local ok, payload = pcall(function()
			return HttpService:JSONDecode(text)
		end)
		if not ok or type(payload) ~= "table" then
			toast("warn", "Config", "File is not valid JSON")
			return 0
		end
		if Hub.ConfigX and Hub.ConfigX.migrate then
			payload = Hub.ConfigX.migrate(payload)
		end
		return Config.applyTable(payload.state or payload)
	end

	function Config.save(): boolean
		local text = Config.serialize()
		if not text then
			toast("warn", "Config", "Could not encode settings")
			return false
		end
		local writer = rawget(_G, "writefile")
		if type(writer) == "function" then
			local ok = pcall(writer, FILE, text)
			if ok then
				toast("success", "Config", "Saved to " .. FILE)
				return true
			end
		end
		local clip = rawget(_G, "setclipboard")
		if type(clip) == "function" then
			pcall(clip, text)
			toast("info", "Config", "No file access — copied to clipboard")
			return true
		end
		toast("warn", "Config", "No file or clipboard access")
		return false
	end

	function Config.load(): boolean
		local reader = rawget(_G, "readfile")
		local exists = rawget(_G, "isfile")
		if type(reader) ~= "function" then
			toast("warn", "Config", "Executor has no readfile")
			return false
		end
		local function tryRead(path: string): string?
			if type(exists) == "function" then
				local ok, present = pcall(exists, path)
				if ok and not present then
					return nil
				end
			end
			local read, text = pcall(reader, path)
			if read and type(text) == "string" then
				return text
			end
			return nil
		end
		local text = tryRead(FILE) or tryRead(LEGACY_FILE)
		if not text then
			toast("info", "Config", "No saved config yet")
			return false
		end
		local applied = Config.deserialize(text)
		if applied > 0 then
			toast("success", "Config", string.format("Loaded %d settings", applied))
			return true
		end
		return false
	end

	function Config.autoLoad()
		local reader = rawget(_G, "readfile")
		local exists = rawget(_G, "isfile")
		if type(reader) ~= "function" then
			return
		end
		local function tryRead(path: string): string?
			if type(exists) == "function" then
				local ok, present = pcall(exists, path)
				if not ok or not present then
					return nil
				end
			end
			local read, text = pcall(reader, path)
			if read and type(text) == "string" then
				return text
			end
			return nil
		end
		local text = tryRead(FILE) or tryRead(LEGACY_FILE)
		if not text then
			return
		end
		local applied = Config.deserialize(text)
		if applied > 0 and Hub.log then
			Hub.log(string.format("config: restored %d settings", applied))
		end
	end

	function Config.loadFromText(text: string): boolean
		if type(text) ~= "string" or #text < 2 then
			toast("warn", "Config", "Paste a config first")
			return false
		end
		local applied = Config.deserialize(text)
		if applied > 0 then
			toast("success", "Config", string.format("Applied %d settings", applied))
			return true
		end
		return false
	end

	function Config.resetAll()
		Config.applyTable(defaults)
		toast("success", "Settings", "Restored shipped defaults")
	end

	function Config.fileName(): string
		return FILE
	end

	function Config.delete()
		local del = rawget(_G, "delfile")
		if type(del) == "function" then
			if pcall(del, FILE) then
				toast("info", "Config", "Deleted " .. FILE)
				return
			end
		end
		toast("warn", "Config", "Could not delete saved config")
	end

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
		if extra and State then
			for k, v in extra do
				State[k] = v
			end
		end
		if Hub.validateState then
			Hub.validateState()
		end
		if notify then
			toast("info", "Profile", name)
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
		pcall(Config.autoLoad)
		if Hub.validateState then
			Hub.validateState()
		end
	end

	local Persistence = {}
	local ATTR_SCHEMA = "TroyHubConfigSchema"
	local ATTR_SAVED = "TroyHubSavedAt"

	local function stampPlayer()
		pcall(function()
			player:SetAttribute(ATTR_SCHEMA, Hub.Version and Hub.Version.configSchema or 2)
			player:SetAttribute(ATTR_SAVED, os.time())
		end)
	end

	function Persistence.save(): boolean
		local ok = Config.save() == true
		if ok then
			stampPlayer()
		end
		return ok
	end

	function Persistence.load(): boolean
		return Config.load() == true
	end

	function Persistence.reload()
		ConfigX.reload()
	end

	function Persistence.export(): string?
		return Config.serialize()
	end

	function Persistence.applyProfile(name: string, notify: boolean?)
		ConfigX.applyProfile(name, notify)
		pcall(Config.save)
		stampPlayer()
	end

	function Persistence.lastSavedAt(): number?
		local v = player:GetAttribute(ATTR_SAVED)
		if type(v) == "number" then
			return v
		end
		return nil
	end

	Hub.Config = Config
	Hub.ConfigX = ConfigX
	Hub.Persistence = Persistence
	return Hub
end
