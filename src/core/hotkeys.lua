--!strict
-- One keybind manager: hold vs toggle, conflict warnings, status-bar preview.

return function(Hub: any)
	local UserInputService = Hub.Services.UserInputService

	type Bind = {
		id: string,
		label: string,
		stateKey: string,
		mode: string, -- "toggle" | "hold"
		aliases: { any },
		onPress: (() -> ())?,
		onRelease: (() -> ())?,
	}

	local binds: { [string]: Bind } = {}
	local byCode: { [string]: string } = {}
	local capturing: string? = nil

	local function codeKey(bind): string
		if typeof(bind) ~= "EnumItem" then
			return ""
		end
		return tostring(bind)
	end

	local function pretty(bind): string
		if typeof(bind) ~= "EnumItem" then
			return "None"
		end
		local s = tostring(bind)
		s = string.gsub(s, "^Enum%.KeyCode%.", "")
		s = string.gsub(s, "^Enum%.UserInputType%.", "")
		return s
	end

	local Hotkeys = {}

	function Hotkeys.register(spec: Bind)
		if binds[spec.id] then
			Hotkeys.unbind(spec.id)
		end
		binds[spec.id] = spec
		for _, alias in spec.aliases do
			local key = codeKey(alias)
			if key ~= "" then
				local existing = byCode[key]
				if existing and existing ~= spec.id then
					if Hub.Notifications then
						Hub.Notifications.warn(
							"Hotkey",
							pretty(alias) .. " already bound to " .. (binds[existing] and binds[existing].label or existing)
						)
					end
				else
					byCode[key] = spec.id
				end
			end
		end
	end

	function Hotkeys.unbind(id: string)
		local spec = binds[id]
		if not spec then
			return
		end
		for key, owner in byCode do
			if owner == id then
				byCode[key] = nil
			end
		end
		binds[id] = nil
	end

	function Hotkeys.clear()
		table.clear(binds)
		table.clear(byCode)
		capturing = nil
	end

	function Hotkeys.beginCapture(id: string)
		capturing = id
		Hub.Flags.keybindCapturing = true
	end

	function Hotkeys.endCapture()
		capturing = nil
		Hub.Flags.keybindCapturing = false
	end

	function Hotkeys.isCapturing(): boolean
		return capturing ~= nil or Hub.Flags.keybindCapturing == true
	end

	function Hotkeys.preview(): string
		local parts = {}
		for _, spec in binds do
			local first = spec.aliases[1]
			table.insert(parts, spec.label .. " " .. pretty(first))
		end
		table.sort(parts)
		return table.concat(parts, "  ·  ")
	end

	function Hotkeys.adoptState()
		local State = Hub.State
		if not State then
			return
		end
		Hotkeys.register({
			id = "menu",
			label = "Menu",
			stateKey = "MenuKey",
			mode = "toggle",
			aliases = { State.MenuKey },
		})
		Hotkeys.register({
			id = "gather",
			label = "Gather",
			stateKey = "GatherKey",
			mode = "toggle",
			aliases = { State.GatherKey },
		})
		Hotkeys.register({
			id = "panic",
			label = "Panic",
			stateKey = "PanicKey",
			mode = "toggle",
			aliases = { State.PanicKey },
		})
		Hotkeys.register({
			id = "fly",
			label = "Fly",
			stateKey = "FlyKey",
			mode = "toggle",
			aliases = { State.FlyKey },
		})
		Hotkeys.register({
			id = "noclip",
			label = "Noclip",
			stateKey = "NoclipKey",
			mode = "toggle",
			aliases = { State.NoclipKey },
		})
		Hotkeys.register({
			id = "infjump",
			label = "InfJump",
			stateKey = "InfJumpKey",
			mode = "toggle",
			aliases = { State.InfJumpKey },
		})
		Hotkeys.register({
			id = "aim",
			label = "Aim",
			stateKey = "AimKeyCode",
			mode = State.AimKey == "Hold" and "hold" or "toggle",
			aliases = { State.AimKeyCode },
		})
	end

	function Hotkeys.matches(input, bind): boolean
		return Hub.inputMatches(input, bind)
	end

	Hub.Hotkeys = Hotkeys
	Hub.prettyKey = pretty
	return Hub
end
