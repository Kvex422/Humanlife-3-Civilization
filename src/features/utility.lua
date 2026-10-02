--!strict
-- Fullbright, X-Ray, NoShadows, AntiAFK.

return function(Hub: any)
	local FM = Hub.FeatureManager
	if not FM then
		return Hub
	end

	FM.register({
		name = "XRay",
		stateKey = "XRay",
		safe = true,
		getEnabled = function()
			return Hub.State.XRay == true
		end,
		setEnabled = function(on)
			if Hub.Features and Hub.Features.setXRay then
				Hub.Features.setXRay(on)
			end
		end,
		cleanup = function()
			if Hub.hooks.xrayCleanup then
				Hub.hooks.xrayCleanup()
			end
		end,
	})

	FM.register({
		name = "Fullbright",
		stateKey = "Fullbright",
		safe = true,
		getEnabled = function()
			return Hub.State.Fullbright == true
		end,
		setEnabled = function(on)
			if Hub.Features and Hub.Features.setFullbright then
				Hub.Features.setFullbright(on)
			end
		end,
		cleanup = function()
			if Hub.hooks.fullbrightCleanup then
				Hub.hooks.fullbrightCleanup()
			end
		end,
	})

	FM.register({
		name = "NoShadows",
		stateKey = "NoShadows",
		safe = true,
		getEnabled = function()
			return Hub.State.NoShadows == true
		end,
		setEnabled = function(on)
			if Hub.Features and Hub.Features.setNoShadows then
				Hub.Features.setNoShadows(on)
			end
		end,
	})

	FM.register({
		name = "AntiAFK",
		stateKey = "AntiAFK",
		safe = true,
		getEnabled = function()
			return Hub.State.AntiAFK == true
		end,
		setEnabled = function(on)
			Hub.State.AntiAFK = on
		end,
	})

	return Hub
end
