--!strict
-- ESP feature registration. Widget pooling lives in the runtime so grace /
-- cap behaviour cannot drift from a second copy.

return function(Hub: any)
	local FM = Hub.FeatureManager
	if not FM then
		return Hub
	end

	FM.register({
		name = "PlayerESP",
		stateKey = "PlayerESP",
		safe = true,
		getEnabled = function()
			return Hub.State.PlayerESP == true
		end,
		setEnabled = function(on)
			Hub.State.PlayerESP = on
		end,
	})

	FM.register({
		name = "ResourceESP",
		stateKey = "ResourceESP",
		safe = true,
		getEnabled = function()
			return Hub.State.ResourceESP == true
		end,
		setEnabled = function(on)
			Hub.State.ResourceESP = on
		end,
	})

	return Hub
end
