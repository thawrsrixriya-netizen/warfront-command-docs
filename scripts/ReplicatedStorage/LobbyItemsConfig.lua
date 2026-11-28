-- ReplicatedStorage.LobbyItemsConfig  (ModuleScript)
-- LobbyItemsConfig (shared, owner): what the lobby SQUAD screen shows. PLACEHOLDER data — nothing is saved yet
-- and the shop does not exist yet ("Owned" is fixed here until the lobby shop + saving are built).
return {
	UnitSlots = 6,
	SkillSlots = 3,
	DefenseSlots = 4,
	LoadoutPoints = 10, -- units cost loadout points (draft: soldier 2, tank 3, special forces 3, MBT 5)

	Difficulties = {
		{ Id = "Easy", Label = "EASY", Waves = 20 },
		{ Id = "Normal", Label = "NORMAL", Waves = 30 },
		{ Id = "Hard", Label = "HARD", Waves = 35 },
		{ Id = "Nightmare", Label = "NIGHTMARE", Waves = 40 },
	},
	DefaultDifficulty = "Normal",

	-- Kind = "Unit" | "Skill" | "Defense". Short = text on the card until real icons exist.
	Items = {
		{ Id = "Infantry", Kind = "Unit", Name = "Infantry Squad", Short = "INF", Points = 2, Owned = true,
			Desc = "6 riflemen. Shared sight, auto-fire, trenches, can ride the BMP." },
		{ Id = "BMP", Kind = "Unit", Name = "BMP", Short = "BMP", Points = 3, Owned = true,
			Desc = "Infantry fighting vehicle. Auto-cannon, carries one squad." },
		{ Id = "SpecialForces", Kind = "Unit", Name = "Special Forces", Short = "SF", Points = 3, Owned = false,
			Desc = "Elite squad. Not in the game yet." },
		{ Id = "MBT", Kind = "Unit", Name = "Main Battle Tank", Short = "MBT", Points = 5, Owned = false,
			Desc = "Heavy tank. Not in the game yet." },

		{ Id = "Bomber", Kind = "Skill", Name = "SU-34 Bomber", Short = "SU-34", Owned = true,
			Desc = "5 bombs on a 40 x 80 area. 2 points, 60 s cooldown." },
		{ Id = "FPV", Kind = "Skill", Name = "FPV Drone", Short = "FPV", Owned = true,
			Desc = "Kamikaze drone along a 200-stud corridor. 1 point, 30 s cooldown." },
		{ Id = "AC130", Kind = "Skill", Name = "AC-130 Gunship", Short = "AC-130", Owned = true,
			Desc = "Orbits a 200-wide circle for 40 s with 4 guns. 3 points, 120 s cooldown." },

		{ Id = "AA", Kind = "Defense", Name = "AA Gun", Short = "AA", Owned = false,
			Desc = "Anti-air gun. Not in the game yet." },
		{ Id = "HMG", Kind = "Defense", Name = "Heavy Machine Gun", Short = "HMG", Owned = false,
			Desc = "Fixed machine-gun nest. Not in the game yet." },
		{ Id = "Sandbags", Kind = "Defense", Name = "Sandbag Wall", Short = "SAND", Owned = false,
			Desc = "Cover for infantry. Not in the game yet." },
	},

	-- starting loadout shown on the screen (Ids per slot)
	Default = {
		Units = { "BMP", "Infantry" },
		Skills = { "Bomber", "FPV", "AC130" },
		Defense = {},
	},
}
