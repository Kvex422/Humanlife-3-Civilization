--!strict
-- Combat feature registration. Aimbot implementation stays in the runtime
-- so prediction / FOV math is not duplicated.

return function(Hub: any)
	local FM = Hub.FeatureManager
	if not FM then
		return Hub
	end

	FM.register({
		name = "AimboT",
		stateKey = "AimboT",
		safe = false,
		dependencies = {},
		getEnabled = function()
			return Hub.State.AimboT == true
		end,
		setEnabled = function(on)
			Hub.State.AimboT = on
			if not on and Hub.hooks.aimbotCleanup then
				Hub.hooks.aimbotCleanup()
			end
		end,
		cleanup = function()
			if Hub.hooks.aimbotCleanup then
				Hub.hooks.aimbotCleanup()
			end
		end,
	})

	return Hub
end
