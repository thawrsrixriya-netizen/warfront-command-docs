-- ServerScriptService.DummyRespawn  (Script)
-- DummyRespawn: EVERY BombDamageDummy is registered on its own and respawns
-- at its own spawn pivot, with its own original values, RespawnTime seconds after death.
-- Optional per-dummy override: Attribute "RespawnTime" (number).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("WarConfig"))

local DUMMY_NAME = Config.Enemies.DummyName
local registered = {}

local function register(model)
	if registered[model] or not model:IsDescendantOf(workspace) then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	registered[model] = true

	local wasArchivable = model.Archivable
	model.Archivable = true
	local template = model:Clone()
	model.Archivable = wasArchivable
	local spawnPivot = model:GetPivot()
	local spawnParent = model.Parent

	local ancestryConn
	ancestryConn = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) and humanoid.Health > 0 then
			-- Removed by hand while alive: stop tracking, do not respawn.
			registered[model] = nil
			ancestryConn:Disconnect()
		end
	end)

	humanoid.Died:Once(function()
		local delay = model:GetAttribute("RespawnTime") or Config.Dummies.RespawnTime
		task.wait(delay)
		ancestryConn:Disconnect()
		registered[model] = nil
		if model.Parent then
			model:Destroy()
		end
		local fresh = template:Clone()
		local freshHumanoid = fresh:FindFirstChildOfClass("Humanoid")
		if freshHumanoid then
			freshHumanoid.Health = freshHumanoid.MaxHealth
		end
		fresh:PivotTo(spawnPivot)
		fresh.Parent = (spawnParent and spawnParent:IsDescendantOf(workspace)) and spawnParent or workspace
		-- the new copy is registered by DescendantAdded below
	end)
end

local function consider(instance)
	if instance:IsA("Model") and instance.Name == DUMMY_NAME then
		task.defer(register, instance)
	end
end

for _, d in ipairs(workspace:GetDescendants()) do
	consider(d)
end
workspace.DescendantAdded:Connect(consider)
