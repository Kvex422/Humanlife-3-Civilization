--!strict
-- Tunables that used to live as magic numbers inside widgets and jobs.

return function(Hub: any)
	Hub.Constants = {
		Window = { Width = 760, Height = 520, Header = 58, Sidebar = 204 },
		Notify = { Width = 300, Duration = 3, Fade = 0.22 },
		Scheduler = {
			Farm = 0.08,
			Discover = 0.2,
			Dashboard = 0.4,
			Diagnostics = 0.5,
			Touch = 0.4,
			XRay = 0.3,
			GuiFocus = 0.1,
		},
		Esp = { Grace = 0.8, Pool = 120 },
		XRayRange = 300,
		Farming = { PlantDelay = 0.35, WaterDelay = 0.4, HarvestDelay = 0.25, CycleDelay = 2.5 },
		-- Humanlife 3 kicks if Humanoid.WalkSpeed stays above 26 while the
		-- in-game Main_Menu is closed. 25 leaves a margin for the Changed delay.
		AntiCheat = { WalkSpeedMax = 25 },
	}
	return Hub
end
