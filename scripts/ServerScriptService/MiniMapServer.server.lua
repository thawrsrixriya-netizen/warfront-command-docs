-- ServerScriptService.MiniMapServer  (Script)
-- MiniMapServer: measures the map once on the server (clients may not have it all streamed in)
-- and publishes it as Workspace attributes MiniMapCenter / MiniMapSize (Vector3, Y unused).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MiniMapConfig"))

local center, size
if Config.Center and Config.Size then
	center, size = Vector3.new(Config.Center.X, 0, Config.Center.Y), Vector3.new(Config.Size.X, 0, Config.Size.Y)
else
	local ground = workspace:FindFirstChild(Config.GroundModel)
	if ground and ground:IsA("Model") then
		local cf, s = ground:GetBoundingBox()
		center, size = cf.Position, s
	elseif ground and ground:IsA("BasePart") then
		center, size = ground.Position, ground.Size
	else
		local base = workspace:FindFirstChild("Baseplate")
		center, size = base and base.Position or Vector3.zero, base and base.Size or Vector3.new(1000, 0, 1000)
	end
end
workspace:SetAttribute("MiniMapCenter", center)
workspace:SetAttribute("MiniMapSize", size)
