-- ServerScriptService.WarServer.TankTreeImpact  (ModuleScript)
-- TankTreeImpact (server): explicit trunk collision for tanks + independent tree reactions.
-- Leafy tree (TreeHitsRequired=3): hit 1 -> ~8 deg, hit 2 -> ~18 deg (both block), hit 3 -> ~88 deg fall (passable).
-- Dry tree (TreeHitsRequired=1): one hit -> gradual fall.
-- Sustained contact counts once; the tank must back off beyond ContactHysteresis to count again.
-- Hit count is shared on the tree (attribute TreeHitCount), so different tanks add to it.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local C = require(ReplicatedStorage:WaitForChild("WarConfig")).Trees

local Trees = {}

local trees = {} -- [Model] = state
local DRY_MESHES = { ["740998664"] = true, ["740991432"] = true, ["740946948"] = true }

local function isFoliage(part)
	local n = part.Name:lower()
	return n:find("lea") or n:find("leaf") or n:find("лист") or n:find("foliage") or n:find("bush")
end

local function meshIdOf(part)
	local id = ""
	if part:IsA("MeshPart") then
		id = part.MeshId
	else
		local sm = part:FindFirstChildOfClass("SpecialMesh")
		if sm then
			id = sm.MeshId
		end
	end
	return id:match("%d+") or ""
end

-- One-time setup for a tree model (also used for trees tagged at runtime / cloned later).
function Trees.setup(model)
	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	local dry = false
	for _, p in ipairs(parts) do
		if DRY_MESHES[meshIdOf(p)] then
			dry = true
		end
	end
	local trunk, best = nil, math.huge
	for _, p in ipairs(parts) do
		local area = p.Size.X * p.Size.Z
		if not isFoliage(p) and area < best then
			trunk, best = p, area
		end
	end
	if not trunk then
		for _, p in ipairs(parts) do
			local area = p.Size.X * p.Size.Z
			if area < best then
				trunk, best = p, area
			end
		end
	end
	local att = trunk:FindFirstChild("TankTrunk1")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "TankTrunk1"
		att.Parent = trunk
		local bottom = trunk.Position - Vector3.new(0, trunk.Size.Y / 2, 0)
		att.WorldPosition = Vector3.new(trunk.Position.X, bottom.Y, trunk.Position.Z)
		att:SetAttribute("TankTreeTrunk", true)
		local radius = math.clamp(math.min(trunk.Size.X, trunk.Size.Z) * 0.2, 0.6, 2.2)
		att:SetAttribute("TreeCollisionRadius", radius)
	end
	if model:GetAttribute("TreeHitsRequired") == nil then
		model:SetAttribute("TreeHitsRequired", dry and 1 or 3)
	end
	if model:GetAttribute("TreeHitCount") == nil then
		model:SetAttribute("TreeHitCount", 0)
	end
	if model:GetAttribute("TreeFallen") == nil then
		model:SetAttribute("TreeFallen", false)
	end
	model:SetAttribute("TreeSystemVersion", 2)
	CollectionService:AddTag(model, C.Tag)
	return att
end

local function register(model)
	if trees[model] or not (model:IsA("Model") or model:IsA("BasePart")) or not model:IsDescendantOf(workspace) then
		return
	end
	local att = model:FindFirstChild("TankTrunk1", true) or Trees.setup(model)
	if not att then
		return
	end
	trees[model] = {
		Base = att.WorldPosition,
		Radius = att:GetAttribute("TreeCollisionRadius") or 1,
		Required = model:GetAttribute("TreeHitsRequired") or 3,
		Hits = model:GetAttribute("TreeHitCount") or 0,
		Fallen = model:GetAttribute("TreeFallen") == true,
		Orig = model:GetPivot(),
		Rot = CFrame.new(), -- current tilt rotation about Base
		Contact = {},
		LastImpact = -math.huge,
	}
end

-- Recognize the actual tree assets in this place, including untagged dry-tree Models.
local TREE_NAMES = {Tree=true, Tree_01=true, Tree_02=true, Tree_03=true, Big_tree_01=true, Big_tree_02=true, Pine=true}
local function discover(instance)
 if not instance:IsDescendantOf(workspace) then return end
 local candidate = instance
 if instance:IsA("BasePart") and instance.Parent and instance.Parent:IsA("Model") and TREE_NAMES[instance.Parent.Name] then
  candidate = instance.Parent
 end
 if not (candidate:IsA("Model") or candidate:IsA("BasePart")) then return end
 if not TREE_NAMES[candidate.Name] and not (candidate:IsA("BasePart") and DRY_MESHES[meshIdOf(candidate)]) then return end
 local ancestor = candidate.Parent
 while ancestor and ancestor ~= workspace do
  if CollectionService:HasTag(ancestor, C.Tag) or (ancestor:IsA("Model") and TREE_NAMES[ancestor.Name]) then return end
  ancestor = ancestor.Parent
 end
 if CollectionService:HasTag(candidate, C.Tag) then register(candidate) else
  local att = Trees.setup(candidate)
  if att then register(candidate) end
 end
end
for _, instance in ipairs(workspace:GetDescendants()) do discover(instance) end
workspace.DescendantAdded:Connect(function(instance)
 if instance:IsA("Model") or instance:IsA("BasePart") then task.defer(discover, instance) end
end)

for _, m in ipairs(CollectionService:GetTagged(C.Tag)) do
	register(m)
end
CollectionService:GetInstanceAddedSignal(C.Tag):Connect(function(m)
	task.defer(register, m)
end)
CollectionService:GetInstanceRemovedSignal(C.Tag):Connect(function(m)
	local tr = trees[m]
	if tr and tr.Animation then tr.Animation:Disconnect() end
	trees[m] = nil
end)

local function animate(model, tr, targetRot, duration, accelerate)
	if tr.Animation then
		tr.Animation:Disconnect()
	end
	local fromRot = tr.Rot
	local start = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - start) / duration, 0, 1)
		local e = accelerate and a * a or (a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2)
		local r = fromRot:Lerp(targetRot, e)
		tr.Rot = r
		model:PivotTo(CFrame.new(tr.Base) * r * CFrame.new(-tr.Base) * tr.Orig)
		if a >= 1 then
			conn:Disconnect()
			tr.Animation = nil
		end
	end)
	tr.Animation = conn
end

local function hit(model, tr, awayDir)
	tr.Hits += 1
	tr.LastImpact = os.clock()
	model:SetAttribute("TreeHitCount", tr.Hits)
	local angle
	if tr.Required <= 1 then
		angle = 88
	else
		angle = C.LeafyAngles[math.min(tr.Hits, #C.LeafyAngles)]
	end
	local fallen = tr.Hits >= tr.Required
	if fallen then
		tr.Fallen = true
		model:SetAttribute("TreeFallen", true)
		-- Command tanks use explicit trunk blocking; fallen geometry must be passable too.
		if model:IsA("BasePart") then model.CanCollide = false end
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
	-- tilt away from the tank: rotate about horizontal axis perpendicular to the push
	local axis = Vector3.yAxis:Cross(awayDir)
	if axis.Magnitude < 1e-3 then
		axis = Vector3.xAxis
	end
	local target = CFrame.fromAxisAngle(axis.Unit, math.rad(angle))
	animate(model, tr, target, fallen and C.FallTime or C.LeanTime, fallen)
end

-- Tank footprint (OBB) at pos/heading vs every standing trunk.
-- Returns true when the move must be blocked.
function Trees.check(tankKey, pos, heading, width, length, allowImpact)
	local blocked = false
	local blocker
	local right = Vector3.new(-heading.Z, 0, heading.X)
	local reach = length / 2 + width / 2 + 3 + C.ContactHysteresis
	for model, tr in pairs(trees) do
		local d = tr.Base - pos
		if math.abs(d.X) < reach + tr.Radius and math.abs(d.Z) < reach + tr.Radius then
			local lx = d.X * right.X + d.Z * right.Z
			local lz = d.X * heading.X + d.Z * heading.Z
			local ex = math.max(math.abs(lx) - width / 2, 0)
			local ez = math.max(math.abs(lz) - length / 2, 0)
			local gap = math.sqrt(ex * ex + ez * ez) - tr.Radius
			if gap <= 0 then
				if not tr.Fallen then
					if allowImpact ~= false and not tr.Contact[tankKey] and os.clock() - tr.LastImpact >= C.MinImpactInterval then
						local away = Vector3.new(heading.X, 0, heading.Z)
						away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
						hit(model, tr, away)
					end
					tr.Contact[tankKey] = true
					if not tr.Fallen then
						blocked = true
						blocker = model
					end
				end
			elseif gap > C.ContactHysteresis then
				tr.Contact[tankKey] = nil
			end
		elseif tr.Contact[tankKey] then
			tr.Contact[tankKey] = nil
		end
	end
	return blocked, blocker
end

function Trees.forget(tankKey)
	for _, tr in pairs(trees) do
		tr.Contact[tankKey] = nil
	end
end

return Trees
