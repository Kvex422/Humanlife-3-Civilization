--!strict
-- One Character / Humanoid / camera / death bus. Features subscribe here
-- instead of each attaching their own CharacterAdded.

return function(Hub: any)
	local player = Hub.player
	local Flags = Hub.Flags

	local onCharacter: { (Model) -> () } = {}
	local onRemoving: { (Model) -> () } = {}
	local onHumanoid: { (Humanoid, Model) -> () } = {}
	local onDied: { (Humanoid, Model) -> () } = {}
	local onCamera: { (Camera) -> () } = {}

	local currentChar: Model? = nil
	local currentHum: Humanoid? = nil
	local diedConn: RBXScriptConnection? = nil
	local childConn: RBXScriptConnection? = nil

	local function fire(list: { any }, ...)
		for _, fn in list do
			pcall(fn, ...)
		end
	end

	local function bindHumanoid(char: Model, hum: Humanoid)
		currentHum = hum
		if diedConn then
			pcall(function()
				(diedConn :: RBXScriptConnection):Disconnect()
			end)
			diedConn = nil
		end
		diedConn = hum.Died:Connect(function()
			if Flags.Unloading then
				return
			end
			fire(onDied, hum, char)
		end)
		Hub.track(diedConn)
		fire(onHumanoid, hum, char)
	end

	local function bindCharacter(char: Model)
		if Flags.Unloading then
			return
		end
		currentChar = char
		if childConn then
			pcall(function()
				(childConn :: RBXScriptConnection):Disconnect()
			end)
			childConn = nil
		end
		childConn = char.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				bindHumanoid(char, child)
			end
		end)
		Hub.track(childConn)
		fire(onCharacter, char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			local waited = char:WaitForChild("Humanoid", 10)
			if waited and waited:IsA("Humanoid") then
				hum = waited
			end
		end
		if hum and hum:IsA("Humanoid") then
			bindHumanoid(char, hum)
		end
	end

	Hub.track(player.CharacterAdded:Connect(function(char)
		if Flags.Unloading then
			return
		end
		task.spawn(function()
			bindCharacter(char)
		end)
	end))

	Hub.track(player.CharacterRemoving:Connect(function(char)
		fire(onRemoving, char)
		if currentChar == char then
			currentChar = nil
			currentHum = nil
		end
	end))

	local function bindCamera(cam: Camera)
		fire(onCamera, cam)
	end

	if workspace.CurrentCamera then
		bindCamera(workspace.CurrentCamera)
	end
	Hub.track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			bindCamera(cam)
		end
	end))

	task.defer(function()
		if Flags.Unloading then
			return
		end
		if player.Character then
			bindCharacter(player.Character)
		end
	end)

	local function listen(list: { any }, fn: any, replay: any?)
		table.insert(list, fn)
		if replay ~= nil then
			pcall(fn, table.unpack(replay))
		end
		return fn
	end

	Hub.Lifecycle = {
		onCharacter = function(fn)
			return listen(onCharacter, fn, currentChar and { currentChar } or nil)
		end,
		onRemoving = function(fn)
			return listen(onRemoving, fn, nil)
		end,
		onHumanoid = function(fn)
			return listen(onHumanoid, fn, (currentHum and currentChar) and { currentHum, currentChar } or nil)
		end,
		onDied = function(fn)
			return listen(onDied, fn, nil)
		end,
		onCamera = function(fn)
			local cam = workspace.CurrentCamera
			return listen(onCamera, fn, cam and { cam } or nil)
		end,
		character = function()
			return currentChar
		end,
		humanoid = function()
			return currentHum
		end,
	}

	return Hub
end
