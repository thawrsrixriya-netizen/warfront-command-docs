-- ReplicatedStorage.AircraftConfig  (ModuleScript)
-- AircraftConfig (shared): flying skills that enemies can shoot down. Owner: game owner.
-- Health 0 = cannot be shot down yet (HP not decided). Set a number to turn it on.
-- Shot-down cooldown penalty lives in EconomyConfig.ShotDownCooldownMultiplier.
return {
	Health = {
		AC130 = 0,
		Bomber = 0, -- SU-34
		FPV = 0,
	},
	-- invisible server hitboxes (studs, X = wingspan, Y = height, Z = length)
	HitboxSize = {
		AC130 = Vector3.new(54, 12, 40),
		Bomber = Vector3.new(38, 10, 60),
		FPV = Vector3.new(3, 2, 3.5),
	},
	CrashGravity = 40, -- studs/s^2 for the falling wreck (visual)
}
