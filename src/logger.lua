--!strict
-- Leveled logger. Debug stays quiet unless State.DebugMode is on.
-- Errors also land in Hub.Diagnostics.LastError for the debug panel.

return function(Hub: any)
	local LEVEL = {
		debug = 10,
		info = 20,
		warn = 30,
		error = 40,
		fatal = 50,
	}

	local Logger = {
		LEVEL = LEVEL,
		minLevel = LEVEL.info,
	}

	local function emit(levelName: string, line: string)
		local State = Hub.State
		if not State then
			print("[Troy]", line)
			return
		end
		local level = LEVEL[levelName] or LEVEL.info
		if levelName == "debug" and not State.DebugMode then
			return
		end
		if level < Logger.minLevel and not State.DebugMode then
			return
		end

		table.insert(State._debugLog, 1, line)
		while #State._debugLog > 12 do
			table.remove(State._debugLog)
		end
		local label = State._debugLabel
		if label and label.Parent then
			label.Text = table.concat(State._debugLog, "\n")
		end

		local prefix = "[Troy]"
		if levelName == "warn" then
			prefix = "[Troy][warn]"
		elseif levelName == "error" or levelName == "fatal" then
			prefix = "[Troy][error]"
		elseif levelName == "debug" then
			prefix = "[Troy][debug]"
		end
		print(prefix, line)

		if level >= LEVEL.error then
			Hub.Diagnostics = Hub.Diagnostics or {}
			Hub.Diagnostics.LastError = line
			Hub.Diagnostics.LastErrorAt = os.clock()
			if Hub.Diagnostics.noteError then
				pcall(Hub.Diagnostics.noteError, line)
			end
			local Notifications = Hub.Notifications
			if Notifications and Notifications.error then
				pcall(function()
					Notifications.error("Error", line, 5)
				end)
			end
		elseif level >= LEVEL.warn then
			Hub.Diagnostics = Hub.Diagnostics or {}
			Hub.Diagnostics.LastWarn = line
		end
	end

	function Logger.debug(line: string)
		emit("debug", line)
	end
	function Logger.info(line: string)
		emit("info", line)
	end
	function Logger.warn(line: string)
		emit("warn", line)
	end
	function Logger.error(line: string)
		emit("error", line)
	end
	function Logger.fatal(line: string)
		emit("fatal", line)
	end

	-- Compatibility with the original log() helper.
	local function log(line: string)
		Logger.info(line)
	end

	Hub.Logger = Logger
	Hub.log = log
	return Hub
end
