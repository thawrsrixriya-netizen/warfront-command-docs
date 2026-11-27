-- ReplicatedStorage.CaptureConfig  (ModuleScript)
-- CaptureConfig (shared): capturing the centre base. Owner: game owner. Numbers are a first draft.
-- Zone = Workspace.MatchPoints.CenterBase (the friend's red box; only its X/Z footprint matters).
return {
	ZoneFolder = "MatchPoints",
	ZoneName = "CenterBase",
	StartOwner = "Enemy", -- the bots hold the centre at the start

	-- One control bar: full BLUE = we hold it, full RED = enemy holds it.
	-- The attacker first drains the holder's colour (DrainSpeed x faster), then fills its own colour.
	CaptureTime = 15, -- seconds to fill an empty bar with the minimum winning force
	DrainSpeed = 2, -- draining the holder's colour is this many times faster than filling
	AdvantageRatio = 1.2, -- the capturing side needs > 20% more strength than the holders inside the zone
	SpeedBonusPerPoint = 0.05, -- each strength point above the first squad: +5% capture speed...
	MaxSpeedMultiplier = 1.5, -- ...up to x1.5
	DecayTime = 20, -- with nobody capturing, the bar returns to its holder's side at 1 bar per this many seconds
	Tick = 0.25,

	-- strength of OUR units (draft = the loadout point values)
	PlayerStrength = {
		InfantrySquad = 2, -- a full squad of SquadSize soldiers; each soldier counts 2 / SquadSize
		SquadSize = 6,
		BMP = 3, -- CommandTanks models without a UnitType attribute count as BMP
		Tank = 3,
		SpecialForces = 3,
		MBT = 5,
	},
	-- strength of ENEMY units, by the enemy model's "UnitType" attribute (missing = Soldier)
	EnemyStrength = {
		Soldier = 2 / 6,
		BMP = 3,
		Tank = 3,
		MBT = 5,
		Boss = 5,
	},

	GroundModel = "GroundAndTrenches", -- the outline dashes sit on this model only (not on trees/houses)

	-- first time the player captures the centre: wave 1 starts (ReplicatedStorage MatchWave / MatchPhase)
	FirstCaptureStartsWave = true,

	Visual = {
		DashLength = 6,
		GapLength = 4,
		LineWidth = 0.7,
		LineColor = Color3.fromRGB(255, 45, 45),
		LineTransparency = 0.68, -- (was 0.35: half as strong)
		FillColor = Color3.fromRGB(255, 40, 40),
		FillTransparency = 0.97, -- (was 0.94: half as strong)
	},
}
