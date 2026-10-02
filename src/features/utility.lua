--!strict
-- Fullbright, X-Ray, NoShadows, AntiAFK.

return function(Hub: any)
	local FM = Hub.FeatureManager
	if not FM then
		return Hub
	end

	local State = Hub.State
	local Flags = Hub.Flags
	local Scheduler = Hub.Scheduler
	local Lighting = Hub.Services.Lighting
	local RunService = Hub.Services.RunService
	local EnvDefaults = Hub.EnvDefaults
	local XRAY_RANGE = (Hub.Constants and Hub.Constants.XRayRange) or 300

	local LIGHT_BIND = "TroyHubLighting"
	local lightingBound = false
	local lightingPropConns = {}
	local lightingApplying = false
	local fbSaved = nil
	local fxSaved = {}
	local fullbrightCleanup: (() -> ())? = nil
	local xrayCleanup: (() -> ())? = nil

	local function unbindLightingStep()
		Scheduler.remove("lighting")
		for _, c in lightingPropConns do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(lightingPropConns)
		pcall(function()
			RunService:UnbindFromRenderStep(LIGHT_BIND)
		end)
		pcall(function()
			RunService:UnbindFromRenderStep("TroyHubLighting")
		end)
		lightingBound = false
	end

	local function restoreTamedEffects()
		for inst, props in fxSaved do
			if inst.Parent then
				pcall(function()
					for k, v in props do
						inst[k] = v
					end
				end)
			end
		end
		table.clear(fxSaved)
	end

	local function restoreFullbrightSaved()
		local saved = fbSaved
		fbSaved = nil
		restoreTamedEffects()
		if not saved then
			return
		end
		pcall(function()
			Lighting.Ambient = saved.Ambient
			Lighting.OutdoorAmbient = saved.OutdoorAmbient
			Lighting.Brightness = saved.Brightness
			Lighting.ClockTime = saved.ClockTime
			Lighting.FogEnd = saved.FogEnd
			Lighting.FogStart = saved.FogStart
			Lighting.FogColor = saved.FogColor
			Lighting.GlobalShadows = saved.GlobalShadows
			Lighting.ExposureCompensation = saved.Exposure
			Lighting.ColorShift_Top = saved.ColorShiftTop
			Lighting.ColorShift_Bottom = saved.ColorShiftBottom
			if saved.EnvDiff ~= nil then
				Lighting.EnvironmentDiffuseScale = saved.EnvDiff
			end
			if saved.EnvSpec ~= nil then
				Lighting.EnvironmentSpecularScale = saved.EnvSpec
			end
			if saved.Clouds and saved.Clouds.inst and saved.Clouds.inst.Parent then
				saved.Clouds.inst.Cover = saved.Clouds.Cover
				saved.Clouds.inst.Density = saved.Clouds.Density
			end
		end)
		if State.NoShadows then
			Lighting.GlobalShadows = false
		end
	end

	local function rememberFx(inst: Instance, props: { [string]: any })
		if fxSaved[inst] then
			return
		end
		local snap = {}
		for k in props do
			local ok, v = pcall(function()
				return (inst :: any)[k]
			end)
			if ok then
				snap[k] = v
			end
		end
		fxSaved[inst] = snap
	end

	local function killAtmosphere(atmo: Atmosphere)
		rememberFx(atmo, { Density = true, Haze = true, Glare = true, Offset = true })
		atmo.Density = 0
		atmo.Haze = 0
		atmo.Glare = 0
		pcall(function()
			atmo.Offset = 0
		end)
	end

	local function killPostEffect(inst: Instance)
		if not inst:IsA("PostEffect") then
			return
		end
		rememberFx(inst, { Enabled = true })
		inst.Enabled = false
	end

	local function killClouds(clouds: Instance)
		rememberFx(clouds, { Cover = true, Density = true, Enabled = true })
		pcall(function()
			(clouds :: any).Cover = 0
			(clouds :: any).Density = 0
			if (clouds :: any).Enabled ~= nil then
				(clouds :: any).Enabled = false
			end
		end)
	end

	local function tameLightingChild(inst: Instance)
		if inst:IsA("Atmosphere") then
			killAtmosphere(inst)
		elseif inst:IsA("PostEffect") then
			killPostEffect(inst)
		end
	end

	local FB_WHITE = Color3.new(1, 1, 1)
	local FB_AMBIENT = Color3.fromRGB(210, 210, 210)

	local function applyFullbrightFrame()
		if lightingApplying then
			return
		end
		lightingApplying = true
		local L = Lighting
		L.ClockTime = 12.5
		L.Brightness = 2
		L.Ambient = FB_AMBIENT
		L.OutdoorAmbient = FB_WHITE
		L.FogStart = 1e5
		L.FogEnd = 1e6
		L.FogColor = FB_WHITE
		L.GlobalShadows = false
		L.ColorShift_Top = FB_WHITE
		L.ColorShift_Bottom = FB_WHITE
		pcall(function()
			L.ExposureCompensation = 0
		end)
		pcall(function()
			L.EnvironmentDiffuseScale = 0
		end)
		pcall(function()
			L.EnvironmentSpecularScale = 0
		end)
		pcall(function()
			L.ShadowSoftness = 0
		end)

		local atmo = L:FindFirstChildOfClass("Atmosphere")
		if atmo then
			killAtmosphere(atmo)
		end
		for _, inst in L:GetChildren() do
			if inst:IsA("PostEffect") then
				killPostEffect(inst)
			elseif inst:IsA("Atmosphere") then
				killAtmosphere(inst)
			end
		end
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			killClouds(clouds)
		end
		lightingApplying = false
	end

	local function lightingStep()
		if Flags.Unloading then
			return
		end
		if State.Fullbright then
			applyFullbrightFrame()
		elseif State.NoShadows then
			Lighting.GlobalShadows = false
		end
	end

	local function bindLightingStep()
		if lightingBound or Flags.Unloading then
			return
		end
		lightingBound = true
		pcall(function()
			RunService:UnbindFromRenderStep(LIGHT_BIND)
		end)
		Scheduler.add("lighting", "logic", 0, lightingStep, { owner = "Fullbright" })
		pcall(function()
			RunService:BindToRenderStep(LIGHT_BIND, Enum.RenderPriority.Last.Value + 100, lightingStep)
		end)
		table.insert(lightingPropConns, Lighting.ChildAdded:Connect(function(inst)
			if Flags.Unloading or not State.Fullbright then
				return
			end
			tameLightingChild(inst)
		end))
	end

	local function setFullbright(on: boolean)
		State.Fullbright = on
		if on then
			if not fbSaved then
				local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
				fbSaved = {
					Ambient = Lighting.Ambient,
					OutdoorAmbient = Lighting.OutdoorAmbient,
					Brightness = Lighting.Brightness,
					ClockTime = Lighting.ClockTime,
					FogEnd = Lighting.FogEnd,
					FogStart = Lighting.FogStart,
					FogColor = Lighting.FogColor,
					GlobalShadows = Lighting.GlobalShadows,
					Exposure = Lighting.ExposureCompensation,
					ColorShiftTop = Lighting.ColorShift_Top,
					ColorShiftBottom = Lighting.ColorShift_Bottom,
					EnvDiff = Lighting.EnvironmentDiffuseScale,
					EnvSpec = Lighting.EnvironmentSpecularScale,
					Clouds = clouds and { inst = clouds, Cover = clouds.Cover, Density = clouds.Density } or nil,
				}
			end
			applyFullbrightFrame()
			bindLightingStep()
			fullbrightCleanup = function()
				restoreFullbrightSaved()
				unbindLightingStep()
				if not Flags.Unloading and State.NoShadows then
					Lighting.GlobalShadows = false
					bindLightingStep()
				end
			end
		else
			restoreFullbrightSaved()
			if State.NoShadows then
				Lighting.GlobalShadows = false
				bindLightingStep()
				fullbrightCleanup = function()
					unbindLightingStep()
				end
			else
				fullbrightCleanup = nil
				unbindLightingStep()
			end
		end
	end

	local function setNoShadows(on: boolean)
		State.NoShadows = on
		if on then
			Lighting.GlobalShadows = false
			bindLightingStep()
			if not fullbrightCleanup then
				fullbrightCleanup = function()
					restoreFullbrightSaved()
					unbindLightingStep()
				end
			end
		else
			if not State.Fullbright then
				Lighting.GlobalShadows = EnvDefaults.GlobalShadows
				unbindLightingStep()
				if not fbSaved then
					fullbrightCleanup = nil
				end
			end
		end
	end

	local function setXRay(on: boolean)
		State.XRay = on
		if xrayCleanup then
			xrayCleanup()
			xrayCleanup = nil
		end
		if not on then
			return
		end
		local touched = {}
		local inRange = {}
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.MaxParts = 500
		Scheduler.add("xray", "logic", 0.3, function()
			if Flags.Unloading or not State.XRay then
				return
			end
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local char = Hub.player.Character
			local camPos = cam.CFrame.Position
			params.FilterDescendantsInstances = char and { char } or {}
			local ok, parts = pcall(function()
				return workspace:GetPartBoundsInRadius(camPos, XRAY_RANGE, params)
			end)
			if not ok or not parts then
				return
			end

			table.clear(inRange)
			for _, d in parts do
				if not d:IsA("BasePart") then
					continue
				end
				if d.Size.Magnitude <= 6 then
					continue
				end
				if (d.Position - camPos).Magnitude <= 3 then
					continue
				end
				inRange[d] = true
				if not touched[d] then
					touched[d] = d.LocalTransparencyModifier
				end
				d.LocalTransparencyModifier = 0.7
			end

			for p, original in touched do
				if not inRange[p] then
					if p.Parent then
						pcall(function()
							p.LocalTransparencyModifier = original
						end)
					end
					touched[p] = nil
				end
			end
		end, { owner = "XRay" })
		xrayCleanup = function()
			Scheduler.remove("xray")
			for p, original in touched do
				if p.Parent then
					pcall(function()
						p.LocalTransparencyModifier = original
					end)
				end
			end
			table.clear(touched)
			table.clear(inRange)
		end
	end

	Hub.hooks = Hub.hooks or {}
	Hub.hooks.fullbrightCleanup = function()
		if fullbrightCleanup then
			fullbrightCleanup()
			fullbrightCleanup = nil
		end
		State.Fullbright = false
		unbindLightingStep()
	end
	Hub.hooks.xrayCleanup = function()
		if xrayCleanup then
			xrayCleanup()
			xrayCleanup = nil
		end
		State.XRay = false
	end

	FM.register({
		name = "XRay",
		stateKey = "XRay",
		safe = true,
		getEnabled = function()
			return State.XRay == true
		end,
		setEnabled = setXRay,
		cleanup = Hub.hooks.xrayCleanup,
	})

	FM.register({
		name = "Fullbright",
		stateKey = "Fullbright",
		safe = true,
		getEnabled = function()
			return State.Fullbright == true
		end,
		setEnabled = setFullbright,
		cleanup = Hub.hooks.fullbrightCleanup,
	})

	FM.register({
		name = "NoShadows",
		stateKey = "NoShadows",
		safe = true,
		getEnabled = function()
			return State.NoShadows == true
		end,
		setEnabled = setNoShadows,
	})

	FM.register({
		name = "AntiAFK",
		stateKey = "AntiAFK",
		safe = true,
		getEnabled = function()
			return State.AntiAFK == true
		end,
		setEnabled = function(on)
			State.AntiAFK = on
		end,
	})

	return Hub
end
