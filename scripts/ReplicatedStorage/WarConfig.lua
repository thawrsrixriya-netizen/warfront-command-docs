-- ReplicatedStorage.WarConfig  (ModuleScript)
-- WarConfig: single source of tuning values for the War TD prototype.
-- Units: studs, seconds, studs/second, degrees (unless named *Rad).
-- Circle sizes are DIAMETERS unless the key says Radius.
local Config = {}

Config.Enemies = {
	Folder = "Enemies", -- Workspace.Enemies holds real enemies
	Tag = "Enemy",
	DummyName = "BombDamageDummy",
}

Config.Camera = {
	ToggleKey = Enum.KeyCode.M,
	InitialHeight = 160, -- above reference player position
	MinHeight = 20,
	MaxHeight = 2000,
	PanSpeed = 100,
	WheelStep = 20, -- per scroll unit
	LookDirection = Vector3.new(0.156383827, -0.987688184, 0.004028329), -- nearly vertical; keep as-is
}

Config.Bomber = {
	RectWidth = 40, -- bombs scatter inside this width (was 30)
	AimCircleDiameter = 40, -- aim circle = strike width
	RectLength = 80, -- (was 60)
	BombCount = 5,
 PrecisionSpread = 1.5,
	FlightSpeed = 225, -- (was 450)
 BombRunSpeed = 225, -- (was 450)
 BombRunTransition = 400,
 BombRunLead = 120,
 BombRunExit = 80,
 FlyoutDistance = 3000,
 BombMinInterval = .28,
 BombFirstFallDuration = 2.2,
 BombReleaseDrop = 6,
	StartDistance = 3500, -- before the anchor
	FirstRelease = 11.3, -- fallback; live release times use BomberPath
	ReleaseInterval = 0.3, -- fallback; live gaps are at least BombMinInterval
	FallDuration = 0.95,
	PlaneLifetime = 25.46, -- live duration uses BomberPath
	DefaultAltitude = 125, -- (was 115.54)
	MinAltitudeAboveGround = 14,
	DamageRadius = 25, -- (was 15)
	MaxDamage = 75, -- (was 100) damage = MaxDamage * (1 - d / DamageRadius)
	MaxActivePerPlayer = 1,
}

Config.AC130 = {
	OrbitRadius = 200, -- diameter 400
	SelectRadius = 100, -- diameter 200
	BankAngle = 40,
	AttackDuration = 40,
	EmptyTimeout = 10,
	OrbitAngularSpeedRad = math.pi / 16,
	TransitSpeed = 130,
	MinMapSpan = 1000,
	EntryExtra = 400,
	MinAltitudeAboveGround = 650,
	PropellerSpeedRad = math.pi * 24,
	ReplanInterval = 0.25,
	Guns = {
		Heavy = { Count = 1, BlastRadius = 25, Interval = 1.5, Damage = 30 },
		Secondary = { Count = 1, BlastRadius = 15, Interval = 3, Damage = 15 },
		Machine = { Count = 2, BlastRadius = 0, Interval = 0.2, Damage = 2 },
	},
	Announcement = "Alliance AC-130 above!!!",
	AnnouncementTextSize = 25,
	AnnouncementDuration = 4,
}

Config.Tank = {
	MainGunClipStart = 0.15,
	EngineSoundId = "rbxassetid://74696122886056",
	MainGunSoundId = "rbxassetid://115567133047135",
	MovementSoundId = "rbxassetid://104146505505677",
	MainGunClipEnd = 2.22,
	MaxPerPlayer = 3,
	IconSpinSpeed = 15,
	PlaceRotateSpeed = 60,
	MaxSpeed = 16,
	Accel = 10,
	BrakeDecel = 12,
	MaxTurnSpeed = 45,
	RollingTurnSpeed = 28, -- broader visible steering arc while moving
	TurnInPlaceAngle = 110, -- front/side destinations can be approached on an arc
	CloseTurnDistance = 10,
	CloseTurnAngle = 35,
	RedirectBrakeAngle = 110,
	RedirectPause = 1.5,
	PitchNormal = 4,
	PitchBrake = 6,
	RoadAlignAngle = 5,
	RoadTag = "TankRoad",
	RoadMergeDistance = 2,
	TurretSpeed = 30,
	GunElevationSpeed = 20,
	GunMinElevation = -15,
	GunMaxElevation = 45,
	GunElevationTolerance = 1,
	TurretTolerance = 1,
	Bursts = 3,
	RoundsPerBurst = 3,
	RoundInterval = 0.1,
	BurstPause = 1.5,
	FireInterval = 0.4, -- automatic fire: one round every 0.4 seconds
	OverheatShots = 50, -- after 50 rounds the gun overheats...
	OverheatTime = 10, -- ...and must cool for 10 s (an idle gun also cools fully after 10 s)
	ShotDamage = 20, -- per round, AOE within ShellRadius
	ShellRadius = 5, -- AOE radius of each round (diameter 10 = the white target circle)
	ShellSpeed = 1013,
	AimBaseDiameter = 10,
	AimRectWidth = 10,
	AimRectLength = 450,
	MinRange = 25,
	TargetCircleDiameter = 10,
	LabelOffsetY = 7,
	LabelStuds = 3,
	LabelMaxPixels = 26,
	LabelMaxTextSize = 18,
	LabelMaxDistance = 1500,
	CollisionStep = 0.4,
}

Config.Trees = {
	Tag = "TankReactiveTree",
	LeafyAngles = { 8, 18, 88 },
	LeanTime = 0.5,
	FallTime = 1.35,
	ContactHysteresis = 1,
	MinImpactInterval = 0.5,
}

Config.Dummies = {
	RespawnTime = 60,
	BarSize = Vector2.new(6, 0.8),
	OffsetY = 2.4,
	MaxDistance = 1200,
	TextHideDistance = 85,
	CheckInterval = 0.1,
}

Config.FPV = {
	Length = 200, -- (was 400)
	Width = 40, -- 20 each side = aim circle diameter
	AimCircleDiameter = 40, -- radius 20, first-click circle
	Height = 12, -- flies 12 studs above the ground (was 8)
	Speed = 50, -- (was 80)
	BlastRadius = 10, -- diameter 20
	Damage = 50, -- at the centre of the blast (was flat 30)
	MinDamage = 25, -- at the edge of BlastRadius (linear in between)
	ClimbRate = 20, -- studs/s the drone can climb/sink to follow the ground
	-- walls/buildings taller than Height crash the drone (it explodes there); lower ones are flown over
	DroneScale = 0.5, -- drone model size vs the original template
	DiveDistance = 22, -- starts a curved nose-dive this far before the enemy (or the path end)
	DiveSpeedMul = 1.4, -- speeds up while diving
	AimRotateSpeed = 90,
	InputBlockAfterConfirm = 0.25,
}

return Config
