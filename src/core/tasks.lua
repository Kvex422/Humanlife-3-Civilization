--!strict
-- Every delayed callback and tween is owned here so Unload can cancel them.

return function(Hub: any)
	local TweenService = Hub.Services.TweenService
	local Flags = Hub.Flags

	local delays: { { cancelled: boolean } } = {}
	local tweens: { Tween } = {}

	local Tasks = {}

	function Tasks.delay(seconds: number, fn: () -> ())
		if Flags.Unloading then
			return nil
		end
		local token = { cancelled = false }
		table.insert(delays, token)
		task.delay(seconds, function()
			if token.cancelled or Flags.Unloading then
				return
			end
			pcall(fn)
		end)
		return token
	end

	function Tasks.tween(inst: Instance, props: any, time: number?, style: any?, dir: any?): Tween?
		if Flags.Unloading or not inst or not inst.Parent then
			return nil
		end
		local info = TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
		local tw = TweenService:Create(inst, info, props)
		table.insert(tweens, tw)
		tw.Completed:Connect(function()
			for i = #tweens, 1, -1 do
				if tweens[i] == tw then
					table.remove(tweens, i)
					break
				end
			end
		end)
		tw:Play()
		return tw
	end

	function Tasks.cancelAll()
		for _, token in delays do
			token.cancelled = true
		end
		table.clear(delays)
		for _, tw in tweens do
			pcall(function()
				tw:Cancel()
			end)
		end
		table.clear(tweens)
	end

	Hub.Tasks = Tasks
	return Hub
end
