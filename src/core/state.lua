--!strict
-- Typed defaults, clamp/validation, nil-safe get, freeze-after-init for ConfigDefaults.

return function(Hub: any)
	local player = Hub.player
	local Lighting = Hub.Services.Lighting
	local clampNum = Hub.clampNum

	local ConfigDefaults = {
		AutoGather = false,
		TeleportGather = false,
		GatherAround = false,
		LegitMode = false,
		GatherSpeed = 80,
		HitRange = 45,
		LegitReach = 8,
		LegitHitDelay = 1.2,
		StatusEnabled = true,
		AutoSell = false,
		SellArgStyle = "name_amount",
		PlayerESP = false,
		PlayerBox = true,
		PlayerSkeleton = true,
		PlayerChams = true,
		PlayerName = true,
		PlayerDistance = true,
		PlayerHealth = true,
		PlayerHealthText = false,
		PlayerDeaths = true,
		PlayerGold = true,
		PlayerJob = true,
		PlayerAge = true,
		PlayerMaxDist = 700,
		ResourceESP = false,
		ResourceBox = true,
		ResourceName = true,
		ResourceDistance = true,
		ResourceHealth = true,
		ResourceHealthText = false,
		ResourceMaxDist = 500,
		ResourceLimit = 80,
		PriorityWeight = 40,
		Fullbright = false,
		NoShadows = false,
		XRay = false,
		FOV = 70,
		CamZoom = 128,
		AntiAFK = true,
		InfiniteJump = false,
		Fly = false,
		FlySpeed = 100,
		Noclip = false,
		EnableWalkSpeed = false,
		WalkSpeed = 40,
		WalkSpeedMethod = "Normal",
		JumpPower = 50,
		StealthProfile = "Balanced",
		SoftTeleport = false,
		SoftTeleportSpeed = 220,
		UsePin = true,
		PinMax = 6,
		VelocityClamp = false,
		MaxVelocity = 160,
		LandingJitter = true,
		TravelHops = false,
		HopDistance = 180,
		HitGap = 0.12,
		Overpower = true,
		HitsPerSwing = 3,
		PowerScale = 2,
		FireFloor = 0.03,
		LandSpread = 1.4,
		SkipSeconds = 8,
		ClusterRadius = 90,
		ClusterSeconds = 60,
		AutoRejoin = false,
		UIScale = 1,
		AutoUIScale = true,
		TouchButton = true,
		AimboT = false,
		AimKey = "Hold",
		AimPart = "Head",
		Smoothness = 0,
		AimMaxDist = 300,
		FOVCheck = true,
		FOVRadius = 120,
		WallCheck = true,
		AliveCheck = true,
		TeamCheck = false,
		FriendCheck = false,
		ShowFOVCircle = true,
		FOVFollowMouse = false,
		TargetIndicator = false,
		AimPrediction = false,
		AimPredictStrength = 12,
		AimCurve = "Ease",
		DebugMode = false,
		SafeMode = false,
		UIGlow = true,
		UITransparency = 0,
		ThemeName = "gold",
	}

	local State: { [string]: any } = {
		AutoGather = false,
		TeleportGather = false,
		GatherAround = false,
		LegitMode = false,
		GatherSpeed = 80,
		HitRange = 45,
		LegitReach = 8,
		LegitHitDelay = 1.2,
		ResourcesToCollect = {
			["Tree"] = true, ["Cherry Tree"] = true, ["Rubber Tree"] = true,
			["Rock"] = true, ["Sand"] = false, ["Clay"] = false,
			["Coal"] = false, ["Copper"] = false, ["Gold"] = false,
			["Iron"] = false, ["Tin"] = false, ["Sulfur"] = false,
		},
		StatusEnabled = true,

		AutoSell = false,
		SellArgStyle = "name_amount",

		PlayerESP = false,
		PlayerBox = true,
		PlayerSkeleton = true,
		PlayerChams = true,
		PlayerName = true,
		PlayerDistance = true,
		PlayerHealth = true,
		PlayerHealthText = false,
		PlayerDeaths = true,
		PlayerGold = true,
		PlayerJob = true,
		PlayerAge = true,
		PlayerMaxDist = 700,

		ResourceESP = false,
		ResourceBox = true,
		ResourceName = true,
		ResourceDistance = true,
		ResourceHealth = true,
		ResourceHealthText = false,
		ResourceMaxDist = 500,
		ResourceLimit = 80,
		ResourceTypeFilter = {
			["Tree"] = true, ["Cherry Tree"] = true, ["Rubber Tree"] = true,
			["Rock"] = true, ["Sand"] = false, ["Clay"] = false,
			["Coal"] = false, ["Copper"] = false, ["Gold"] = false,
			["Iron"] = false, ["Tin"] = false, ["Sulfur"] = false,
		},
		ResourcePriority = {
			["Gold"] = 9, ["Sulfur"] = 8, ["Iron"] = 7, ["Copper"] = 6,
			["Coal"] = 5, ["Tin"] = 5, ["Clay"] = 3, ["Sand"] = 3,
			["Rock"] = 2, ["Cherry Tree"] = 2, ["Rubber Tree"] = 2, ["Tree"] = 1,
		},
		PriorityWeight = 40,

		Fullbright = false,
		NoShadows = false,
		XRay = false,

		FOV = 70,
		CamZoom = 128,

		AntiAFK = true,
		InfiniteJump = false,
		InfJumpKey = Enum.KeyCode.V,
		Fly = false,
		FlyKey = Enum.KeyCode.F,
		FlySpeed = 100,
		Noclip = false,
		NoclipKey = Enum.KeyCode.N,

		EnableWalkSpeed = false,
		WalkSpeed = 40,
		WalkSpeedMethod = "Normal",
		JumpPower = 50,
		Gravity = workspace.Gravity,
		MenuKey = Enum.KeyCode.RightShift,
		GatherKey = Enum.KeyCode.G,
		PanicKey = Enum.KeyCode.End,

		StealthProfile = "Balanced",
		SoftTeleport = false,
		SoftTeleportSpeed = 220,
		UsePin = true,
		PinMax = 6,
		VelocityClamp = false,
		MaxVelocity = 160,
		LandingJitter = true,
		TravelHops = false,
		HopDistance = 180,
		HitGap = 0.12,
		Overpower = true,
		HitsPerSwing = 3,
		PowerScale = 2,
		FireFloor = 0.03,
		LandSpread = 1.4,
		SkipSeconds = 8,
		ClusterRadius = 90,
		ClusterSeconds = 60,

		AutoRejoin = false,

		UIScale = 1,
		AutoUIScale = true,
		TouchButton = true,
		ThemeAccent = Color3.fromRGB(212, 160, 64),
		ThemeAccent2 = Color3.fromRGB(196, 112, 48),
		ThemeName = "gold",
		UIGlow = true,
		UITransparency = 0,

		AimboT = false,
		AimKey = "Hold",
		AimKeyCode = Enum.UserInputType.MouseButton2,
		AimPart = "Head",
		Smoothness = 0,
		AimMaxDist = 300,
		FOVCheck = true,
		FOVRadius = 120,
		WallCheck = true,
		AliveCheck = true,
		TeamCheck = false,
		FriendCheck = false,
		ShowFOVCircle = true,
		FOVColor = Color3.fromRGB(212, 160, 64),
		FOVFollowMouse = false,
		TargetIndicator = false,
		AimPrediction = false,
		AimPredictStrength = 12,
		AimCurve = "Ease",

		DebugMode = false,
		SafeMode = false,
		PanicMode = false,

		_statusLabel = nil,
		_statusDot = nil,
		_debugLabel = nil,
		_debugLog = {},
		_rescanScheduled = false,
	}

	local EnvDefaults = {
		Gravity = workspace.Gravity,
		CameraZoom = player.CameraMaxZoomDistance,
		FieldOfView = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
		GlobalShadows = Lighting.GlobalShadows,
	}

	local CLAMPS: { [string]: { min: number, max: number, fallback: number } } = {
		FlySpeed = { min = 1, max = 500, fallback = 100 },
		JumpPower = { min = 1, max = 500, fallback = 50 },
		WalkSpeed = { min = 1, max = 500, fallback = 16 },
		FOV = { min = 40, max = 120, fallback = 70 },
		CamZoom = { min = 16, max = 400, fallback = 128 },
		HitRange = { min = 4, max = 200, fallback = 45 },
		LegitReach = { min = 2, max = 20, fallback = 8 },
		LegitHitDelay = { min = 0.05, max = 3, fallback = 1.2 },
		HitGap = { min = 0.05, max = 3, fallback = 0.12 },
		HitsPerSwing = { min = 1, max = 8, fallback = 3 },
		PowerScale = { min = 1, max = 10, fallback = 2 },
		FireFloor = { min = 0.01, max = 1, fallback = 0.03 },
		GatherSpeed = { min = 10, max = 400, fallback = 80 },
		SoftTeleportSpeed = { min = 20, max = 800, fallback = 220 },
		PinMax = { min = 0, max = 600, fallback = 6 },
		MaxVelocity = { min = 20, max = 600, fallback = 160 },
		HopDistance = { min = 20, max = 600, fallback = 180 },
		LandSpread = { min = 0, max = 8, fallback = 1.4 },
		SkipSeconds = { min = 1, max = 60, fallback = 8 },
		ClusterRadius = { min = 10, max = 400, fallback = 90 },
		ClusterSeconds = { min = 5, max = 300, fallback = 60 },
		PriorityWeight = { min = 0, max = 200, fallback = 40 },
		PlayerMaxDist = { min = 50, max = 2000, fallback = 700 },
		ResourceMaxDist = { min = 50, max = 2000, fallback = 500 },
		ResourceLimit = { min = 8, max = 200, fallback = 80 },
		UIScale = { min = 0.6, max = 1.6, fallback = 1 },
		UITransparency = { min = 0, max = 0.6, fallback = 0 },
		AimMaxDist = { min = 20, max = 2000, fallback = 300 },
		FOVRadius = { min = 20, max = 400, fallback = 120 },
		Smoothness = { min = 0, max = 1, fallback = 0 },
		AimPredictStrength = { min = 0, max = 40, fallback = 12 },
		Gravity = { min = 0, max = 500, fallback = 196.2 },
	}

	local function getState(key: string, fallback: any): any
		local v = State[key]
		if v == nil then
			return fallback
		end
		return v
	end

	local function validateState()
		for key, spec in CLAMPS do
			State[key] = clampNum(State[key], spec.min, spec.max, spec.fallback)
		end
		if type(State.ResourcesToCollect) ~= "table" then
			State.ResourcesToCollect = {
				["Tree"] = true, ["Cherry Tree"] = true, ["Rubber Tree"] = true,
				["Rock"] = true, ["Sand"] = false, ["Clay"] = false,
				["Coal"] = false, ["Copper"] = false, ["Gold"] = false,
				["Iron"] = false, ["Tin"] = false, ["Sulfur"] = false,
			}
		end
		local names = Hub.RESOURCE_NAMES
		if names then
			for k in State.ResourcesToCollect do
				if not names[k] then
					State.ResourcesToCollect[k] = nil
				end
			end
		end
		if State.FOVRadius ~= State.FOVRadius then
			State.FOVRadius = 120
		end
		local sell = State.SellArgStyle
		local styles = Hub.SELL_STYLES
		if styles then
			local ok = false
			for _, s in styles do
				if s == sell then
					ok = true
					break
				end
			end
			if not ok then
				State.SellArgStyle = "name_amount"
			end
		end
	end

	validateState()
	pcall(function()
		table.freeze(ConfigDefaults)
	end)

	Hub.State = State
	Hub.EnvDefaults = EnvDefaults
	Hub.ConfigDefaults = ConfigDefaults
	Hub.getState = getState
	Hub.validateState = validateState
	Hub.CLAMPS = CLAMPS
	return Hub
end
