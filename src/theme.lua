--!strict
-- Charcoal + gold by default. Extra presets expand the original Gold/Ember/Sage/Sand/Mono set.

return function(Hub: any)
	local Theme = {
		Bg = Color3.fromRGB(16, 16, 16),
		Glass = Color3.fromRGB(26, 26, 26),
		GlassHi = Color3.fromRGB(36, 36, 36),
		Stroke = Color3.fromRGB(48, 48, 48),
		StrokeHi = Color3.fromRGB(196, 148, 64),
		Accent = Color3.fromRGB(212, 160, 64),
		Accent2 = Color3.fromRGB(196, 112, 48),
		Success = Color3.fromRGB(92, 196, 128),
		Warn = Color3.fromRGB(232, 176, 72),
		Danger = Color3.fromRGB(224, 88, 88),
		Text = Color3.fromRGB(240, 238, 232),
		TextDim = Color3.fromRGB(160, 156, 148),
		TextFaint = Color3.fromRGB(104, 100, 94),
		TrackOff = Color3.fromRGB(48, 48, 48),
		Font = Enum.Font.Gotham,
		FontBold = Enum.Font.GothamMedium,
		FontBlack = Enum.Font.GothamBold,
	}

	local PRESETS = {
		dark = { Accent = Color3.fromRGB(200, 200, 200), Accent2 = Color3.fromRGB(120, 120, 120) },
		gold = { Accent = Color3.fromRGB(212, 160, 64), Accent2 = Color3.fromRGB(196, 112, 48) },
		crimson = { Accent = Color3.fromRGB(208, 64, 72), Accent2 = Color3.fromRGB(140, 36, 40) },
		emerald = { Accent = Color3.fromRGB(64, 180, 120), Accent2 = Color3.fromRGB(32, 120, 80) },
		neon = { Accent = Color3.fromRGB(80, 255, 200), Accent2 = Color3.fromRGB(40, 180, 255) },
		purple = { Accent = Color3.fromRGB(160, 96, 220), Accent2 = Color3.fromRGB(96, 48, 160) },
		ember = { Accent = Color3.fromRGB(220, 96, 48), Accent2 = Color3.fromRGB(160, 48, 32) },
		sage = { Accent = Color3.fromRGB(120, 160, 112), Accent2 = Color3.fromRGB(72, 112, 80) },
		sand = { Accent = Color3.fromRGB(196, 168, 112), Accent2 = Color3.fromRGB(148, 116, 72) },
		mono = { Accent = Color3.fromRGB(180, 180, 180), Accent2 = Color3.fromRGB(96, 96, 96) },
	}

	local function mix(a: Color3, b: Color3, t: number): Color3
		return Color3.new(
			a.R + (b.R - a.R) * t,
			a.G + (b.G - a.G) * t,
			a.B + (b.B - a.B) * t
		)
	end

	local function applyAccents(accent: Color3, accent2: Color3)
		Theme.Accent = accent
		Theme.Accent2 = accent2
		Theme.StrokeHi = mix(accent, Color3.fromRGB(48, 48, 48), 0.25)
		local State = Hub.State
		if State then
			State.ThemeAccent = accent
			State.ThemeAccent2 = accent2
			State.FOVColor = accent
		end
		local applyTheme = Hub.applyTheme
		if type(applyTheme) == "function" then
			pcall(applyTheme)
		end
	end

	local function applyPreset(name: string)
		local preset = PRESETS[string.lower(name)]
		if not preset then
			return
		end
		if Hub.State then
			Hub.State.ThemeName = string.lower(name)
		end
		applyAccents(preset.Accent, preset.Accent2)
	end

	Hub.Theme = Theme
	Hub.ThemePresets = PRESETS
	Hub.applyAccents = applyAccents
	Hub.applyThemePreset = applyPreset
	return Hub
end
