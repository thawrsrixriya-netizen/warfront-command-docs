-- ReplicatedStorage.WarShared.EnemyRegistry  (ModuleScript)
-- EnemyRegistry (shared, server + client): ONE definition of "enemy" for every weapon.
-- Enemy = Model with a Humanoid that is NOT a player character, and is either
--   named BombDamageDummy, tagged "Enemy", or inside Workspace.Enemies.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WarConfig")).Enemies

local Registry = {}

function Registry.isEnemyModel(model)
	if not model or not model:IsA("Model") then
		return false
	end
	if Players:GetPlayerFromCharacter(model) then
		return false
	end
	if not model:FindFirstChildOfClass("Humanoid") then
		return false
	end
	if model.Name == Config.DummyName or CollectionService:HasTag(model, Config.Tag) then
		return true
	end
	local folder = workspace:FindFirstChild(Config.Folder)
	return folder ~= nil and model:IsDescendantOf(folder)
end

function Registry.rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

-- Track every Humanoid in Workspace; the enemy rule is re-checked on each query,
-- so tags/folders changed later are respected.
local tracked = {}
local function track(d)
	if d:IsA("Humanoid") then
		tracked[d] = true
	end
end
for _, d in ipairs(workspace:GetDescendants()) do
	track(d)
end
workspace.DescendantAdded:Connect(track)
workspace.DescendantRemoving:Connect(function(d)
	if d:IsA("Humanoid") then
		tracked[d] = nil
	end
end)

-- Returns array of { Model, Humanoid, Root, Position }.
function Registry.all(includeDead)
	local list = {}
	for humanoid in pairs(tracked) do
		local model = humanoid.Parent
		if model and humanoid:IsDescendantOf(workspace) and (includeDead or humanoid.Health > 0) and Registry.isEnemyModel(model) then
			local root = Registry.rootOf(model)
			if root then
				table.insert(list, { Model = model, Humanoid = humanoid, Root = root, Position = root.Position })
			end
		end
	end
	return list
end

-- Living enemies within radius. mode "XZ" (ground plane, default) or "3D".
-- Each entry gets .Distance.
function Registry.inRadius(center, radius, mode)
	local out = {}
	for _, e in ipairs(Registry.all(false)) do
		local delta = e.Position - center
		local d = (mode == "3D") and delta.Magnitude or Vector2.new(delta.X, delta.Z).Magnitude
		if d <= radius then
			e.Distance = d
			table.insert(out, e)
		end
	end
	return out
end

return Registry
