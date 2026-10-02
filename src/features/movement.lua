--!strict
-- Fly, Noclip, InfiniteJump, WalkSpeed. Jobs are owned by FeatureManager.set.

return function(Hub: any)
	local FM = Hub.FeatureManager
	if not FM then
		return Hub
	end

	local State = Hub.State
	local Flags = Hub.Flags
	local Scheduler = Hub.Scheduler
	local player = Hub.player
	local clampNum = Hub.clampNum
	local track = Hub.track
	local isKeyDown = Hub.isKeyDown
	local UserInputService = Hub.Services.UserInputService

	local flightCleanup: (() -> ())? = nil
	local noclipCleanup: (() -> ())? = nil
	local infJumpCleanup: (() -> ())? = nil

	local function applyWalkSettings(hum: Humanoid)
		hum.UseJumpPower = true
		hum.JumpPower = clampNum(State.JumpPower, 0, 500, 50)
		if not State.EnableWalkSpeed then
			hum.WalkSpeed = 16
			return
		end
		local method = State.WalkSpeedMethod
		if method == "Rigid" then
			hum.WalkSpeed = 0
		elseif method == "Boost" then
			hum.WalkSpeed = 16
		else
			hum.WalkSpeed = clampNum(State.WalkSpeed, 0, 500, 40)
		end
	end

	Hub.applyWalkSettings = applyWalkSettings

	local function setInfiniteJump(on: boolean)
		State.InfiniteJump = on
		if infJumpCleanup then
			infJumpCleanup()
			infJumpCleanup = nil
		end
		if not on then
			return
		end
		local conn = UserInputService.JumpRequest:Connect(function()
			if Flags.Unloading or not State.InfiniteJump then
				return
			end
			local hum = Hub.getHumanoid and Hub.getHumanoid()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
		track(conn)
		infJumpCleanup = function()
			pcall(function()
				conn:Disconnect()
			end)
		end
	end

	local function setFly(on: boolean)
		State.Fly = on
		if flightCleanup then
			flightCleanup()
			flightCleanup = nil
		end
		if not on then
			return
		end
		local bodyVelocity, bodyGyro
		Scheduler.add("fly", "render", 0, function()
			if Flags.Unloading or not State.Fly then
				return
			end
			-- Leftover BodyVelocity/Gyro will fight Auto Gather CFrame flight
			-- and cancel hits. Tear them down while the farm is flying.
			if State.TeleportGather or (State.AutoGather and not State.LegitMode) then
				if bodyVelocity then
					pcall(function()
						bodyVelocity:Destroy()
					end)
					bodyVelocity = nil
				end
				if bodyGyro then
					pcall(function()
						bodyGyro:Destroy()
					end)
					bodyGyro = nil
				end
				return
			end
			local root = Hub.getRoot and Hub.getRoot()
			if not root then
				return
			end
			if not bodyVelocity or not bodyVelocity.Parent then
				bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
				bodyVelocity.Velocity = Vector3.zero
				bodyVelocity.Parent = root
				bodyGyro = Instance.new("BodyGyro")
				bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
				bodyGyro.CFrame = root.CFrame
				bodyGyro.Parent = root
			end
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local camCF = cam.CFrame
			local dir = Vector3.zero
			if isKeyDown(Enum.KeyCode.W) then
				dir += camCF.LookVector
			end
			if isKeyDown(Enum.KeyCode.S) then
				dir -= camCF.LookVector
			end
			if isKeyDown(Enum.KeyCode.A) then
				dir -= camCF.RightVector
			end
			if isKeyDown(Enum.KeyCode.D) then
				dir += camCF.RightVector
			end
			if isKeyDown(Enum.KeyCode.Space) then
				dir += Vector3.new(0, 1, 0)
			end
			if isKeyDown(Enum.KeyCode.LeftControl) then
				dir -= Vector3.new(0, 1, 0)
			end
			local flySpeed = clampNum(State.FlySpeed, 1, 500, 100)
			bodyVelocity.Velocity = if dir.Magnitude > 0 then dir.Unit * flySpeed else Vector3.zero
			bodyGyro.CFrame = camCF
		end, { owner = "Fly" })
		flightCleanup = function()
			Scheduler.remove("fly")
			if bodyVelocity then
				pcall(function()
					bodyVelocity:Destroy()
				end)
			end
			if bodyGyro then
				pcall(function()
					bodyGyro:Destroy()
				end)
			end
			bodyVelocity, bodyGyro = nil, nil
		end
	end

	local function setNoclip(on: boolean)
		State.Noclip = on
		if noclipCleanup then
			noclipCleanup()
			noclipCleanup = nil
		end
		if not on then
			return
		end
		local restore = {}
		local cached: { BasePart } = {}
		local charRef: Model? = nil
		local addedConn: RBXScriptConnection? = nil

		local function rescan(char: Model)
			table.clear(cached)
			charRef = char
			for _, p in char:GetChildren() do
				if p:IsA("BasePart") then
					table.insert(cached, p)
				end
			end
			if addedConn then
				pcall(function()
					(addedConn :: RBXScriptConnection):Disconnect()
				end)
			end
			addedConn = char.ChildAdded:Connect(function(child)
				if child:IsA("BasePart") then
					table.insert(cached, child)
				end
			end)
			track(addedConn)
		end

		Scheduler.add("noclip", "logic", 0, function()
			if Flags.Unloading or not State.Noclip then
				return
			end
			local char = player.Character
			if not char then
				return
			end
			if char ~= charRef then
				rescan(char)
			end
			for _, p in cached do
				if p.Parent and p.CanCollide then
					restore[p] = true
					p.CanCollide = false
				end
			end
		end, { owner = "Noclip" })
		noclipCleanup = function()
			Scheduler.remove("noclip")
			if addedConn then
				pcall(function()
					(addedConn :: RBXScriptConnection):Disconnect()
				end)
			end
			addedConn = nil
			for p in restore do
				if p.Parent and p:IsDescendantOf(player.Character or player) then
					pcall(function()
						p.CanCollide = true
					end)
				end
			end
			table.clear(restore)
			table.clear(cached)
			charRef = nil
		end
	end

	Hub.hooks = Hub.hooks or {}
	Hub.hooks.flightCleanup = function()
		if flightCleanup then
			flightCleanup()
			flightCleanup = nil
		end
		State.Fly = false
	end
	Hub.hooks.noclipCleanup = function()
		if noclipCleanup then
			noclipCleanup()
			noclipCleanup = nil
		end
		State.Noclip = false
	end
	Hub.hooks.infJumpCleanup = function()
		if infJumpCleanup then
			infJumpCleanup()
			infJumpCleanup = nil
		end
		State.InfiniteJump = false
	end

	FM.register({
		name = "Fly",
		stateKey = "Fly",
		safe = false,
		getEnabled = function()
			return State.Fly == true
		end,
		setEnabled = setFly,
		cleanup = Hub.hooks.flightCleanup,
	})

	FM.register({
		name = "Noclip",
		stateKey = "Noclip",
		safe = false,
		getEnabled = function()
			return State.Noclip == true
		end,
		setEnabled = setNoclip,
		cleanup = Hub.hooks.noclipCleanup,
	})

	FM.register({
		name = "InfiniteJump",
		stateKey = "InfiniteJump",
		safe = true,
		getEnabled = function()
			return State.InfiniteJump == true
		end,
		setEnabled = setInfiniteJump,
		cleanup = Hub.hooks.infJumpCleanup,
	})

	FM.register({
		name = "WalkSpeed",
		stateKey = "EnableWalkSpeed",
		safe = true,
		getEnabled = function()
			return State.EnableWalkSpeed == true
		end,
		setEnabled = function(on)
			State.EnableWalkSpeed = on
			local hum = Hub.getHumanoid and Hub.getHumanoid()
			if hum then
				applyWalkSettings(hum)
			end
		end,
		cleanup = function()
			State.EnableWalkSpeed = false
			local hum = Hub.getHumanoid and Hub.getHumanoid()
			if hum then
				hum.WalkSpeed = 16
			end
		end,
	})

	Scheduler.add("walkspeed", "logic", 0, function(dt)
		if Flags.Unloading or not State.EnableWalkSpeed then
			return
		end
		local hum = Hub.getHumanoid and Hub.getHumanoid()
		local root = Hub.getRoot and Hub.getRoot()
		if not hum or not root or hum.Health <= 0 then
			return
		end
		if State.Fly or root.Anchored then
			return
		end
		if State.TeleportGather or (State.AutoGather and not State.LegitMode) then
			return
		end

		local method = State.WalkSpeedMethod
		local speed = math.max(State.WalkSpeed, 1)
		if method == "Normal" then
			if math.abs(hum.WalkSpeed - speed) > 0.05 then
				hum.WalkSpeed = speed
			end
			return
		end
		if method == "Boost" then
			if math.abs(hum.WalkSpeed - 16) > 0.05 then
				hum.WalkSpeed = 16
			end
			local dir = hum.MoveDirection
			if dir.Magnitude > 0.05 then
				local extra = math.max(speed, 16)
				root.AssemblyLinearVelocity = Vector3.new(dir.X * extra, root.AssemblyLinearVelocity.Y, dir.Z * extra)
			end
			return
		end
		if math.abs(hum.WalkSpeed) > 0.05 then
			hum.WalkSpeed = 0
		end
		local dir = hum.MoveDirection
		if dir.Magnitude > 0.05 then
			local step = dir.Unit * speed * dt
			root.CFrame = root.CFrame + Vector3.new(step.X, 0, step.Z)
		end
	end, { owner = "WalkSpeed" })

	return Hub
end
