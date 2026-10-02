--!strict
-- Public feature registry. Features declare enable / disable / cleanup once;
-- UI, hotkeys, Unload, and diagnostics all go through this API.

return function(Hub: any)
	local FM = Hub.FeatureManager
	if not FM then
		return Hub
	end

	local Registry = {}

	function Registry.declare(spec: any)
		FM.register(spec)
		return spec.name
	end

	function Registry.enable(name: string, notify: boolean?)
		FM.set(name, true, notify)
	end

	function Registry.disable(name: string, notify: boolean?)
		FM.set(name, false, notify)
	end

	function Registry.toggle(name: string, notify: boolean?)
		FM.set(name, not FM.isEnabled(name), if notify == nil then true else notify)
	end

	function Registry.isEnabled(name: string): boolean
		return FM.isEnabled(name)
	end

	function Registry.list(): { string }
		return FM.list()
	end

	function Registry.active(): { string }
		return FM.active()
	end

	function Registry.get(name: string)
		return FM.get(name)
	end

	Hub.Registry = Registry
	return Hub
end
