-- ReplicatedStorage.EconomyConfig  (ModuleScript)
-- EconomyConfig (shared): in-match money, points, prices and cooldowns. Owner: game owner.
-- Draft numbers from the direction doc; change them here, no code changes needed.
return {
	-- testing: every player starts with these instead of the real start values
	TestMode = true,
	TestMoney = 9999,
	TestPoints = 9999,

	Difficulty = "Normal", -- until the lobby picks one
	StartMoney = { Easy = 800, Normal = 600, Hard = 500 },
	StartPoints = 0,
	MoneyMultiplier = 1.5, -- attacker bonus on money earned (moves to the enemy after capture, later)
	KillsPerPoint = 100, -- 1 skill point for every N kills

	-- summoned units (key = the Economy field of a hotbar slot)
	Units = {
		BMP = { Label = "BMP", Cost = 250, Cooldown = 5 },
		Infantry = { Label = "Infantry squad", Cost = 100, Cooldown = 5 },
		MBT = { Label = "MBT", Cost = 500, Cooldown = 5 },
	},

	-- skills (key = SkillActions id); cooldown starts when the skill has ended
	Skills = {
		FPV = { Points = 1, Cooldown = 30 },
		Bomber = { Points = 2, Cooldown = 60 },
		AC130 = { Points = 3, Cooldown = 120 },
	},
	-- SU-34 and FPV start their cooldown when called; AC-130 when it has left.
	-- A flying skill that gets shot down: cooldown x this, rounded to whole seconds (60 -> 105).
	ShotDownCooldownMultiplier = 1.75,

	-- money per kill, by the enemy model's "UnitType" attribute
	KillReward = { Default = 5, Soldier = 5, BMP = 25, Tank = 25, MBT = 50, Boss = 200 },

	-- may use /money, /points, /cooldowns in chat
	Admins = {
		[0] = true, -- (admin UserId removed from the public snapshot)
		[0] = true, -- (admin UserId removed from the public snapshot)
	},
}
