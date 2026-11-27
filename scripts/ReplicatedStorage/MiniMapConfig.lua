-- ReplicatedStorage.MiniMapConfig  (ModuleScript)
-- MiniMapConfig (shared): the round minimap at the top-left. Owner: game owner.
return {
	Diameter = 150, -- px, small map (was a 230 px hexagon; -35%)
	Position = UDim2.fromOffset(16, 16),
	-- click the small map -> big map in the middle of the screen (drag to move, wheel to zoom,
	-- click outside it or press X to close)
	ExpandedScreenFraction = 0.8, -- big map diameter = this x the shorter screen side
	ExpandedZoom = 1.5, -- big map starts this many times closer than "whole map fits"
	MaxZoom = 5,
	-- world area shown. nil = automatic: measured on the server (MiniMapServer) from Workspace[GroundModel]
	Center = nil, -- Vector2.new(x, z)
	Size = nil, -- Vector2.new(sizeX, sizeZ) in studs
	GroundModel = "GroundAndTrenches",
	Fill = 0.92, -- small map: how much of the circle the map uses
	UpdateInterval = 0.1,
	Colors = {
		Background = Color3.fromRGB(18, 21, 26),
		Ground = Color3.fromRGB(58, 52, 44),
		Outline = Color3.fromRGB(110, 120, 135),
		Mine = Color3.fromRGB(80, 190, 255),
		Ally = Color3.fromRGB(110, 220, 120),
		Enemy = Color3.fromRGB(240, 70, 60),
		PlayerBase = Color3.fromRGB(80, 190, 255),
		CenterBase = Color3.fromRGB(255, 205, 70),
		EnemyBase = Color3.fromRGB(240, 70, 60),
	},
	-- Workspace.MatchPoints children shown as base markers (Part or Model), name -> colour key
	Bases = { "PlayerBase", "CenterBase", "EnemyBase" },
}
