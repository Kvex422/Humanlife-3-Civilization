--!strict
-- FeatureTemplate for Fly / Noclip / InfiniteJump / WalkSpeed.

return function(Hub: any)
	local FM = Hub.FeatureManager
	if not FM then
		return Hub
	end

	FM.register({
		name = "Fly",
		stateKey = "Fly",
		safe = false,
		getEnabled = function()
			return Hub.State.Fly == true
		end,
		setEnabled = function(on)
			if Hub.Features and Hub.Features.setFly then
				Hub.Features.setFly(on)
			end
		end,
		cleanup = function()
			if Hub.hooks.flightCleanup then
				Hub.hooks.flightCleanup()
			end
		end,
	})

	FM.register({
		name = "Noclip",
		stateKey = "Noclip",
		safe = false,
		getEnabled = function()
			return Hub.State.Noclip == true
		end,
		setEnabled = function(on)
			if Hub.Features and Hub.Features.setNoclip then
				Hub.Features.setNoclip(on)
			end
		end,
		cleanup = function()
			if Hub.hooks.noclipCleanup then
				Hub.hooks.noclipCleanup()
			end
		end,
	})

	FM.register({
		name = "InfiniteJump",
		stateKey = "InfiniteJump",
		safe = true,
		getEnabled = function()
			return Hub.State.InfiniteJump == true
		end,
		setEnabled = function(on)
			if Hub.Features and Hub.Features.setInfiniteJump then
				Hub.Features.setInfiniteJump(on)
			end
		end,
		cleanup = function()
			if Hub.hooks.infJumpCleanup then
				Hub.hooks.infJumpCleanup()
			end
		end,
	})

	FM.register({
		name = "WalkSpeed",
		stateKey = "EnableWalkSpeed",
		safe = true,
		getEnabled = function()
			return Hub.State.EnableWalkSpeed == true
		end,
		setEnabled = function(on)
			Hub.State.EnableWalkSpeed = on
			local hum = Hub.getHumanoid and Hub.getHumanoid()
			if hum and Hub.applyWalkSettings then
				Hub.applyWalkSettings(hum)
			end
		end,
		cleanup = function()
			Hub.State.EnableWalkSpeed = false
		end,
	})

	return Hub
end
