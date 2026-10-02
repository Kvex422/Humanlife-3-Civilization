--!strict
-- Shared helpers. Everything here is pure or service-light so feature modules
-- can call it without pulling GUI or farm code.

return function(Hub: any)
	local TweenService = Hub.Services.TweenService
	local UserInputService = Hub.Services.UserInputService
	local Stats = Hub.Services.Stats
	local player = Hub.player

	local function clampNum(v: any, min: number, max: number, fallback: number): number
		if type(v) ~= "number" or v ~= v then
			return fallback
		end
		return math.clamp(v, min, max)
	end

	local function new(class: string, props: any, children: any?)
		local inst = Instance.new(class)
		if inst:IsA("GuiButton") and props.Selectable == nil then
			inst.Selectable = false
		end
		local parent = props.Parent
		for k, v in props do
			if k ~= "Parent" then
				inst[k] = v
				if Hub.bindIfThemed and typeof(v) == "Color3" then
					if k == "BackgroundColor3" or k == "TextColor3" or k == "ImageColor3"
						or k == "ScrollBarImageColor3" or k == "Color" then
						Hub.bindIfThemed(inst, v, k)
					end
				end
			end
		end
		if children then
			for _, c in children do
				c.Parent = inst
			end
		end
		if parent ~= nil then
			inst.Parent = parent
		end
		return inst
	end

	local function corner(r, parent)
		return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
	end

	local function stroke(color, thickness, parent)
		return new("UIStroke", {
			Color = color or Hub.Theme.Stroke,
			Thickness = thickness or 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = parent,
		})
	end

	local function pad(px, parent)
		return new("UIPadding", {
			PaddingTop = UDim.new(0, px),
			PaddingBottom = UDim.new(0, px),
			PaddingLeft = UDim.new(0, px),
			PaddingRight = UDim.new(0, px),
			Parent = parent,
		})
	end

	local function gradient(c1, c2, rotation, parent)
		return new("UIGradient", {
			Color = ColorSequence.new(c1, c2),
			Rotation = rotation or 0,
			Parent = parent,
		})
	end

	local function tween(inst, props, time, style, dir)
		if Hub.Tasks and Hub.Tasks.tween then
			return Hub.Tasks.tween(inst, props, time, style, dir)
		end
		local t = TweenService:Create(
			inst,
			TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
			props
		)
		t:Play()
		return t
	end

	local function isPointerBegin(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	local function isPointerMove(input)
		return input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
	end

	local function isKeyDown(key: Enum.KeyCode): boolean
		local ok, down = pcall(function()
			return UserInputService:IsKeyDown(key)
		end)
		return ok and down or false
	end

	local function inputMatches(input, bind): boolean
		if typeof(bind) ~= "EnumItem" then
			return false
		end
		if bind.EnumType == Enum.UserInputType then
			return input.UserInputType == bind
		end
		return bind ~= Enum.KeyCode.Unknown and input.KeyCode == bind
	end

	local function getPingMs(): number
		local ms = 0
		local ok = pcall(function()
			ms = math.floor((player:GetNetworkPing() or 0) * 1000 + 0.5)
		end)
		if ok and ms > 0 then
			return ms
		end
		pcall(function()
			local item = Stats.Network.ServerStatsItem["Data Ping"]
			if item then
				ms = math.floor(item:GetValue() + 0.5)
			end
		end)
		return ms
	end

	local function getCharacter(): Model?
		return player.Character
	end

	local function getHumanoid(): Humanoid?
		local char = player.Character
		if not char then
			return nil
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum:IsA("Humanoid") then
			return hum
		end
		return nil
	end

	local function getRoot(): BasePart?
		local char = player.Character
		if not char then
			return nil
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end
		return nil
	end

	Hub.clampNum = clampNum
	Hub.new = new
	Hub.corner = corner
	Hub.stroke = stroke
	Hub.pad = pad
	Hub.gradient = gradient
	Hub.tween = tween
	Hub.isPointerBegin = isPointerBegin
	Hub.isPointerMove = isPointerMove
	Hub.isKeyDown = isKeyDown
	Hub.inputMatches = inputMatches
	Hub.getPingMs = getPingMs
	Hub.getCharacter = getCharacter
	Hub.getHumanoid = getHumanoid
	Hub.getRoot = getRoot
	Hub.FrameRate = Hub.FrameRate or { fps = 60 }
	return Hub
end
