--!strict
-- Feature list: register, enable, disable, cleanup. No dependency/conflict graph.

return function(Hub: any)
	type Feature = {
		name: string,
		enable: (() -> ())?,
		disable: (() -> ())?,
		cleanup: (() -> ())?,
		getEnabled: (() -> boolean)?,
		setEnabled: ((boolean) -> ())?,
		stateKey: string?,
		safe: boolean?,
	}

	local registry: { [string]: Feature } = {}
	local order: { string } = {}

	local FeatureManager = {}

	function FeatureManager.register(nameOrSpec: any, enable: any?, disable: any?, cleanup: any?)
		local spec: Feature
		if type(nameOrSpec) == "table" then
			spec = nameOrSpec
		else
			spec = {
				name = nameOrSpec,
				enable = enable,
				disable = disable,
				cleanup = cleanup,
			}
		end
		assert(type(spec.name) == "string" and spec.name ~= "", "feature needs a name")
		if not registry[spec.name] then
			table.insert(order, spec.name)
		end
		registry[spec.name] = spec
		if spec.cleanup and Hub.Lifecycle and Hub.Lifecycle.onUnload then
			Hub.Lifecycle.onUnload(function()
				pcall(spec.cleanup)
			end)
		end
	end

	function FeatureManager.get(name: string): Feature?
		return registry[name]
	end

	function FeatureManager.list(): { string }
		return table.clone(order)
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
		if spec.setEnabled then
			Hub.Flags.SchedulingOwner = name
			spec.setEnabled(on)
			Hub.Flags.SchedulingOwner = nil
		elseif on and spec.enable then
			Hub.Flags.SchedulingOwner = name
			spec.enable()
			Hub.Flags.SchedulingOwner = nil
		elseif (not on) and spec.disable then
			spec.disable()
		end
		if not on and Hub.Scheduler and Hub.Scheduler.removeByOwner then
			Hub.Scheduler.removeByOwner(name)
		end
		if Hub.validateState then
			pcall(Hub.validateState)
		end
		local sync = Hub.toggleSync and Hub.toggleSync[name]
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

	Hub.FeatureManager = FeatureManager
	Hub.Registry = {
		declare = FeatureManager.register,
		enable = function(name: string, notify: boolean?)
			FeatureManager.set(name, true, notify)
		end,
		disable = function(name: string, notify: boolean?)
			FeatureManager.set(name, false, notify)
		end,
		toggle = function(name: string, notify: boolean?)
			FeatureManager.set(name, not FeatureManager.isEnabled(name), if notify == nil then true else notify)
		end,
		isEnabled = FeatureManager.isEnabled,
		list = FeatureManager.list,
		active = FeatureManager.active,
		get = FeatureManager.get,
	}
	return Hub
end
