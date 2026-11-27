-- ReplicatedStorage.WarShared.WarUtil  (ModuleScript)
-- WarUtil (shared): small helpers used by server and client systems.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local U = {}

U.EFFECT_FOLDERS = { "ClientFX", "WarFX", "FPVFlights", "CommandTanks", "CommandInfantry", "AC130Visuals", "BomberVisuals", "Aircraft" }

function U.isFiniteVector(v)
	return typeof(v) == "Vector3"
		and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

function U.isFiniteNumber(n)
	return type(n) == "number" and n == n and math.abs(n) < 1e9
end

-- Horizontal unit vector or nil.
function U.flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-6 then
		return nil
	end
	return f.Unit
end

function U.wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- yaw for CFrame.Angles(0, yaw, 0) whose LookVector points along dir
function U.yawOf(dir)
	return math.atan2(-dir.X, -dir.Z)
end

function U.dirOf(yaw)
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function U.folder(name, parent)
	parent = parent or workspace
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- Turn a model into a pure visual: anchored, no collision/touch/query, no scripts/prompts/seats.
function U.makeVisual(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("BaseScript") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	return model
end

-- Raycast params that see only "ground": excludes characters, effects, vehicles, reactive trees, enemies.
function U.groundParams(extra)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.IgnoreWater = true
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(list, pl.Character)
		end
	end
	for _, name in ipairs(U.EFFECT_FOLDERS) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, t in ipairs(CollectionService:GetTagged("TankReactiveTree")) do
		table.insert(list, t)
	end
	for _, vegetation in ipairs(CollectionService:GetTagged("TankPassThroughVegetation")) do
		table.insert(list, vegetation)
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(list, enemies)
	end
	for _, d in ipairs(CollectionService:GetTagged("Enemy")) do
		table.insert(list, d)
	end
	if extra then
		for _, e in ipairs(extra) do
			table.insert(list, e)
		end
	end
	p.FilterDescendantsInstances = list
	return p
end

-- Ground height at (x, z), casting down from fromY (keep fromY low enough to stay under sky meshes).
function U.groundY(x, z, fromY, params)
	local r = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -(fromY + 2000), 0), params or U.groundParams())
	if r then
		return r.Position.Y, r
	end
	return 0, nil
end

-- Rotation that maps a model's local nose direction onto -Z (CFrame forward).
function U.noseFix(noseLocal)
	local n = U.flat(noseLocal) or Vector3.new(0, 0, -1)
	return CFrame.lookAlong(Vector3.zero, n):Inverse()
end

return U
