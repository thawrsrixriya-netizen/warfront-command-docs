-- ReplicatedStorage.VisionConfig  (ModuleScript)
-- VisionConfig (OWNER sets these numbers). Used by WarServer.VisionService and the client VisionDisplay.
-- Each unit type has a Profile. To add a new unit type, add a new entry under Profiles
-- and register the unit with VisionService.register(model, {Profile = "<name>", ...}).
return {
	Tick = 0.2,             -- seconds between vision checks
	MemorySeconds = 5,      -- an enemy stays visible this long after every unit loses sight of it
	AlertSeconds = 3,       -- a unit that is shot keeps facing the shooter this long
	SeeThroughTransparency = 0.9, -- parts at least this transparent do not block sight

	Profiles = {
		BMP = { PassengerSideAngle = 90, PassengerSideRange = 110, VisionRange = 110, VisionAngle = 35, AwareRadius = 0, WeaponRange = 450, EyeHeight = 2 },
		Infantry = {
			VisionRange = 130,  -- how far the sight triangle reaches (studs)
			VisionAngle = 120,  -- full width of the sight triangle (degrees)
			AwareRadius = 15,   -- sees all around inside this radius (still needs a clear line)
			WeaponRange = 200,  -- max shooting distance; shooting still needs the target to be SEEN
			EyeHeight = 1.5,    -- eye height above the unit's root (standing)
		},
	},

	-- Client display (cones/rings shown for the selected squad)
	Display = {
		ConeColor = Color3.fromRGB(255, 220, 90),
		RangeColor = Color3.fromRGB(255, 90, 70),
		LineWidth = 0.6,
		ArcSegments = 14,
		RingSegments = 64,
	},
}
