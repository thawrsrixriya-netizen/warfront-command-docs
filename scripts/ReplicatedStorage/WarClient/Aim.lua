-- ReplicatedStorage.WarClient.Aim  (ModuleScript)
-- Aim (client): mouse-to-ground raycasts that match what the player sees.
-- Uses GetMouseLocation + ViewportPointToRay so the GUI inset is handled.
-- Preview/effect parts must use CanQuery=false; they are then skipped automatically.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Aim = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local extra = {}

function Aim.addExclude(instance)
	table.insert(extra, instance)
end

local function refresh()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for i = #extra, 1, -1 do
		if extra[i].Parent then
			table.insert(list, extra[i])
		else
			table.remove(extra, i)
		end
	end
	local fx = workspace:FindFirstChild("ClientFX")
	if fx then
		table.insert(list, fx)
	end
	local air = workspace:FindFirstChild("Aircraft") -- invisible hitboxes of flying skills
	if air then
		table.insert(list, air)
	end
	params.FilterDescendantsInstances = list
end

function Aim.mouseRay()
	local m = UserInputService:GetMouseLocation()
	return workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
end

-- Returns hit position (Vector3) and RaycastResult, or nil.
function Aim.groundHit(maxDistance)
	refresh()
	local ray = Aim.mouseRay()
	local result = workspace:Raycast(ray.Origin, ray.Direction * (maxDistance or 5000), params)
	if result then
		return result.Position, result
	end
	return nil
end

-- Ground point straight below/above an XZ position.
function Aim.groundAt(position)
	refresh()
	local origin = Vector3.new(position.X, position.Y + 500, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -2000, 0), params)
	if result then
		return result.Position, result
	end
	return nil
end

return Aim
