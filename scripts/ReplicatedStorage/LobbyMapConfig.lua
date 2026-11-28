-- ReplicatedStorage.LobbyMapConfig  (ModuleScript)
-- LobbyMapConfig (shared, owner): the country map on the lobby PLAY screen.
-- All positions are 0..1 across the map area (x = left -> right, y = top -> bottom). Names are placeholders.
-- Each location = one battlefield (match map). Playable = can be chosen; Weather = forecast shown in the panel
-- (later each weather will buff/nerf units: e.g. night = shorter sight, day = longer sight).
return {
	Title = "MAP",
	Country = "V E L M O R I A",
	SeaName = "K  A  R  A     S  E  A",

	-- coastline of the mainland (clockwise) and islands
	Land = {
		{ 0.04, 0.06 }, { 0.20, 0.03 }, { 0.33, 0.07 }, { 0.45, 0.04 }, { 0.56, 0.08 }, { 0.63, 0.15 }, { 0.67, 0.25 },
		{ 0.62, 0.31 }, { 0.66, 0.39 }, { 0.63, 0.47 }, { 0.58, 0.51 }, { 0.61, 0.58 }, { 0.56, 0.64 }, { 0.51, 0.69 },
		{ 0.50, 0.78 }, { 0.45, 0.84 }, { 0.43, 0.93 }, { 0.33, 0.97 }, { 0.22, 0.94 }, { 0.12, 0.97 }, { 0.04, 0.90 },
		{ 0.05, 0.76 }, { 0.02, 0.62 }, { 0.05, 0.47 }, { 0.02, 0.33 }, { 0.04, 0.18 },
	},
	Islands = {
		{ { 0.70, 0.55 }, { 0.74, 0.53 }, { 0.76, 0.58 }, { 0.73, 0.63 }, { 0.69, 0.60 } },
		{ { 0.60, 0.78 }, { 0.63, 0.76 }, { 0.65, 0.81 }, { 0.62, 0.86 }, { 0.59, 0.83 } },
		{ { 0.68, 0.33 }, { 0.70, 0.32 }, { 0.71, 0.35 }, { 0.69, 0.37 } },
	},
	-- mountain ranges: { x, y, radius (fraction of map height) }
	Mountains = {
		{ 0.10, 0.15, 0.10 }, { 0.17, 0.24, 0.12 }, { 0.09, 0.34, 0.10 }, { 0.22, 0.11, 0.08 }, { 0.15, 0.46, 0.09 },
		{ 0.28, 0.20, 0.07 }, { 0.10, 0.58, 0.08 }, { 0.20, 0.66, 0.07 }, { 0.08, 0.80, 0.08 }, { 0.33, 0.10, 0.06 },
		{ 0.24, 0.36, 0.06 }, { 0.50, 0.16, 0.05 },
	},
	Rivers = {
		{ { 0.20, 0.18 }, { 0.27, 0.30 }, { 0.31, 0.44 }, { 0.38, 0.58 }, { 0.46, 0.66 }, { 0.53, 0.67 } },
		{ { 0.13, 0.55 }, { 0.20, 0.72 }, { 0.27, 0.84 }, { 0.30, 0.96 } },
		{ { 0.45, 0.12 }, { 0.50, 0.24 }, { 0.58, 0.30 }, { 0.62, 0.31 } },
	},
	-- roads between locations (by Id)
	Roads = {
		{ "Northwatch", "Kravets" }, { "Kravets", "Dolvin" }, { "Dolvin", "Lumen" }, { "Dolvin", "PortSarin" },
		{ "Ironpeak", "Dolvin" }, { "Kravets", "PortSarin" },
	},

	Locations = {
		{ Id = "Dolvin", Name = "Dolvin Village", Pos = { 0.36, 0.50 }, Playable = true,
			Info = "Village on a crossroads. Capture the centre, hold it through the waves.",
			Weather = { Rain = true, Fog = false, Day = true, Night = true }, Image = "" },
		{ Id = "Kravets", Name = "Kravets Airbase", Pos = { 0.50, 0.32 }, Playable = false,
			Weather = { Rain = false, Fog = true, Day = true, Night = true }, Image = "" },
		{ Id = "PortSarin", Name = "Port Sarin", Pos = { 0.57, 0.57 }, Playable = false,
			Weather = { Rain = true, Fog = true, Day = true, Night = false }, Image = "" },
		{ Id = "Ironpeak", Name = "Ironpeak Pass", Pos = { 0.19, 0.30 }, Playable = false,
			Weather = { Rain = false, Fog = true, Day = false, Night = true }, Image = "" },
		{ Id = "Lumen", Name = "Lumen Refinery", Pos = { 0.43, 0.76 }, Playable = false,
			Weather = { Rain = true, Fog = false, Day = true, Night = false }, Image = "" },
		{ Id = "Northwatch", Name = "Northwatch Outpost", Pos = { 0.39, 0.14 }, Playable = false,
			Weather = { Rain = false, Fog = true, Day = true, Night = true }, Image = "" },
	},

	-- the 4 forecast slots, in order
	WeatherSlots = {
		{ Key = "Rain", Label = "RAIN", Icon = "\u{1F327}" },
		{ Key = "Fog", Label = "FOG", Icon = "\u{1F32B}" },
		{ Key = "Day", Label = "DAY", Icon = "\u{2600}" },
		{ Key = "Night", Label = "NIGHT", Icon = "\u{1F319}" },
	},
}
