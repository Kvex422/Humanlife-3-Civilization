--!strict
-- One registration path for every toggleable system:
-- name, enable, disable, cleanup, state metadata, UI toggle binding, dependencies.

return function(Hub: any)
	type Feature = {
		name: string,
		enable: (() -> ())?,
		disable: (() -> ())?,
		cleanup: (() -> ())?,
		getEnabled: (() -> boolean)?,
		setEnabled: ((boolean) -> ())?,
		stateKey: string?,
		dependencies: { string }?,
		safe: boolean?,
		bindToggle: ((boolean) -> ())?,
	}

	local registry: { [string]: Feature } = {}
	local order: { string } = {}

	local FeatureManager = {}

	function FeatureManager.register(spec: Feature)
		assert(type(spec.name) == "string" and spec.name ~= "", "feature needs a name")
		if not registry[spec.name] then
			table.insert(order, spec.name)
		end
		registry[spec.name] = spec
	end

	function FeatureManager.get(name: string): Feature?
		return registry[name]
	end

	function FeatureManager.list(): { string }
		local copy = table.clone(order)
		return copy
	end

	function FeatureManager.isEnabled(name: string): boolean
		local spec = registry[name]
		if not spec then
			return false
		end
		if spec.getEnabled then
			return spec.getEnabled()
		end
		local key = spec.stateKey
		if key and Hub.State then
			return Hub.State[key] == true
		end
		return false
	end

	function FeatureManager.set(name: string, on: boolean, notify: boolean?)
		local spec = registry[name]
		if not spec then
			return
		end
		if Hub.Flags.Unloading and on then
			return
		end
		if on and Hub.State and Hub.State.SafeMode and spec.safe == false then
			if Hub.Logger then
				Hub.Logger.warn("Safe Mode blocked " .. name)
			end
			return
		end
		if on and spec.dependencies then
			for _, dep in spec.dependencies do
				if not FeatureManager.isEnabled(dep) then
					FeatureManager.set(dep, true, false)
				end
			end
		end
		if spec.setEnabled then
			spec.setEnabled(on)
		elseif on and spec.enable then
			spec.enable()
		elseif (not on) and spec.disable then
			spec.disable()
		end
		local sync = (Hub.toggleSync and Hub.toggleSync[name]) or spec.bindToggle
		if sync then
			pcall(sync, on)
		end
		if notify and Hub.Notifications then
			Hub.Notifications.info(name, on and "Enabled" or "Disabled")
		end
	end

	function FeatureManager.disableAll()
		for i = #order, 1, -1 do
			local spec = registry[order[i]]
			if spec then
				pcall(function()
					FeatureManager.set(spec.name, false, false)
					if spec.cleanup then
						spec.cleanup()
					end
				end)
			end
		end
	end

	function FeatureManager.cleanupAll()
		for i = #order, 1, -1 do
			local spec = registry[order[i]]
			if spec and spec.cleanup then
				pcall(spec.cleanup)
			end
		end
	end

	function FeatureManager.clear()
		table.clear(registry)
		table.clear(order)
	end

	function FeatureManager.active(): { string }
		local live = {}
		for _, name in order do
			if FeatureManager.isEnabled(name) then
				table.insert(live, name)
			end
		end
		return live
	end

	-- Wrap the original FEATURE_SETTERS table once app.lua has defined it.
	function FeatureManager.adoptSetters(setters: { [string]: (boolean) -> () }, toggleSync: { [string]: (boolean) -> () }?)
		for name, setter in setters do
			FeatureManager.register({
				name = name,
				stateKey = name,
				setEnabled = setter,
				getEnabled = function()
					return Hub.State[name] == true
				end,
				cleanup = function()
					setter(false)
				end,
				safe = name ~= "AimboT" and name ~= "Fly" and name ~= "Noclip",
			})
		end
	end

	Hub.FeatureManager = FeatureManager
	return Hub
end
