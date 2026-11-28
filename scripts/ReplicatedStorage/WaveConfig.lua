-- ReplicatedStorage.WaveConfig  (ModuleScript)
-- WaveConfig (shared): enemy waves. Owner: game owner (waves are the owner's design). FIRST DRAFT numbers.
-- Waves start when the player captures the centre for the first time (CaptureServer).
-- Enemies spawn at the start of a random path in Workspace.MatchPoints.EnemyPaths, walk it to the
-- centre base, then hold a random spot inside the capture zone (so they can take it back).
local Config = {}

Config.TotalWaves = { Easy = 20, Normal = 30, Hard = 35, Nightmare = 40 } -- difficulty = EconomyConfig.Difficulty
Config.BreakEvery = 5 -- a long break after every 5th wave...
Config.LongBreak = 20 -- ...of this many seconds
Config.ShortBreak = 3 -- between the other waves
Config.SpawnInterval = 0.7 -- seconds between two enemies of the same wave
Config.SkipAfter = 60 -- SKIP WAVE appears once a wave has run this long and enemies are still alive
-- (AUTO SKIP presses it automatically at that moment; breaks cannot be skipped)
Config.LateralSpread = 3 -- studs: soldiers walk a little left/right of the road line
Config.HealthGrowthPerWave = 0.06 -- +6% health per wave after wave 1

-- unit types. Template = model in ServerStorage.WaveEnemies (placeholder: the yellow dummy).
-- UnitType is written on every spawned enemy (capture strength + kill money use it).
Config.Types = {
	Soldier = { Template = "WaveSoldier", Scale = 1, Health = 100, Speed = 8 },
	BMP = { Template = "WaveSoldier", Scale = 2.2, Health = 400, Speed = 12, Color = Color3.fromRGB(255, 150, 40) },
	MBT = { Template = "WaveSoldier", Scale = 2.8, Health = 900, Speed = 9, Color = Color3.fromRGB(210, 90, 40) },
	Boss = { Template = "WaveSoldier", Scale = 3.6, Health = 3000, Speed = 6, Color = Color3.fromRGB(170, 60, 200) },
}

-- what wave n contains (draft)
function Config.composition(n)
	local list = {}
	list.Soldier = math.min(6 + 2 * (n - 1), 40)
	if n >= 5 then
		list.BMP = math.min(1 + math.floor((n - 5) / 2), 8)
	end
	if n >= 15 then
		list.MBT = math.min(1 + math.floor((n - 15) / 3), 5)
	end
	if n % 10 == 0 then
		list.Boss = n // 10
	end
	return list
end

return Config
