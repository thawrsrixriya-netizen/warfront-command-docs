-- StarterPlayer.StarterPlayerScripts.VisionDisplay  (LocalScript)
-- VisionDisplay (client, OWNER system): draws ONE sight triangle per selected squad (at the squad centre)
-- and the weapon circle around each squad; marks enemies the team can currently see (attribute "Spotted").
-- Works for any unit with attributes VisionProfile + OwnerUserId (+ InfantrySlot for squads).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("VisionConfig"))
local Registry = require(RS:WaitForChild("WarShared"):WaitForChild("EnemyRegistry"))
local player = Players.LocalPlayer
local D = Config.Display
local Projection=require(RS.WarClient.GroundLineProjection)

local fx = workspace:FindFirstChild("ClientFX")
if not fx then fx = Instance.new("Folder") fx.Name = "ClientFX" fx.Parent = workspace end
local folder = Instance.new("Folder") folder.Name = "VisionDisplay" folder.Parent = fx

local pool, used = {}, 0
local function seg(a, b, color)
	used += 1
	local p = pool[used]
	if not p then
		p = Instance.new("Part")
		p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
		p.Material = Enum.Material.Neon p.Transparency = 0.35
		p.Parent = folder
		pool[used] = p
	end
	local len = (b - a).Magnitude
	local size=Vector3.new(0.15,0.025,math.max(len,.05))
	local cf=CFrame.lookAt((a+b)/2,b)
	if (p.Size-size).Magnitude>.0001 then p.Size=size end
	if p.CFrame~=cf then p.CFrame=cf end
	if p.Color~=Color3.new(1,1,1) then p.Color=Color3.new(1,1,1) end
	if p.Transparency~=.35 then p.Transparency=.35 end
end

local function selectedSlots()
	local s = player:GetAttribute("InfantrySelectedSlots")
	local set = {}
	if type(s) == "string" then for n in s:gmatch("[^,]+") do set[tonumber(n)] = true end end
	return set
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
-- lines follow the ground (hills/craters) so they are not hidden under terrain
local CollectionService = game:GetService("CollectionService")
local listAt = -1
local function castGround(p)
	if os.clock() - listAt > 2 then -- refresh the ignore list (units, players, trees) every 2 s
		listAt = os.clock()
		local list = { fx }
		local inf = workspace:FindFirstChild("CommandInfantry") if inf then table.insert(list, inf) end
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
		for _, tag in ipairs({ "TankReactiveTree", "TankPassThroughVegetation" }) do
			for _, v in ipairs(CollectionService:GetTagged(tag)) do table.insert(list, v) end
		end
		groundParams.FilterDescendantsInstances = list
	end
	local hit = workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -100, 0), groundParams)
	return hit
end
local projection=Projection.new(castGround,.2)
local function onGround(p) return projection:Project(p) end

local function dirOf(yaw) return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) end

-- spotted markers
local marks = {}
local function mark(model, on)
	local m = marks[model]
	if on and not m then
		local root = Registry.rootOf(model)
		if not root then return end
		m = Instance.new("BillboardGui")
		m.Name = "SpottedMark" m.Size = UDim2.fromOffset(18, 18) m.StudsOffset = Vector3.new(0, 4, 0)
		m.AlwaysOnTop = true m.Adornee = root
		local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1
		t.Text = "▼" t.TextScaled = true t.TextColor3 = D.RangeColor t.Font = Enum.Font.GothamBold t.Parent = m
		m.Parent = folder
		marks[model] = m
	elseif not on and m then
		m:Destroy() marks[model] = nil
	end
end

local units = workspace:WaitForChild("CommandInfantry")
RunService.RenderStepped:Connect(function(dt)
	used = 0
	projection:BeginFrame(dt)
	local slots = selectedSlots()
	local squads = {}
	for _, m in ipairs(units:GetChildren()) do
		local slot = m:GetAttribute("InfantrySlot")
		local root = m:FindFirstChild("HumanoidRootPart")
		local h = m:FindFirstChildOfClass("Humanoid")
		if root and h and h.Health > 0 and m:GetAttribute("OwnerUserId") == player.UserId and slots[slot] then
			-- one squad (6 soldiers) = one viewer: one triangle at the squad centre, average facing
			local prof = Config.Profiles[m:GetAttribute("VisionProfile") or "Infantry"] or Config.Profiles.Infantry
			local pos = root.Position
			local foot = Vector3.new(pos.X, pos.Y - 3 * m:GetScale(), pos.Z)
			local _, yaw = root.CFrame:ToOrientation()
			local sq = squads[slot] or { Sum = Vector3.zero, N = 0, Dir = Vector3.zero, Prof = prof }
			sq.Sum += foot sq.N += 1 sq.Dir += dirOf(yaw)
			squads[slot] = sq
		end
	end
	for _, sq in pairs(squads) do
		local prof = sq.Prof
		local c = sq.Sum / sq.N
		-- sight triangle
		local yaw = sq.Dir.Magnitude > 1e-3 and math.atan2(-sq.Dir.X, -sq.Dir.Z) or 0
		local half = math.rad(prof.VisionAngle / 2)
		local r = prof.VisionRange
		local left = onGround(c + dirOf(yaw + half) * r)
		local right = onGround(c + dirOf(yaw - half) * r)
		local base = onGround(c)
		seg(base, left, D.ConeColor)
		seg(base, right, D.ConeColor)
		local prev = left
		for i = 1, D.ArcSegments do
			local p = onGround(c + dirOf(yaw + half - (2 * half) * i / D.ArcSegments) * r)
			seg(prev, p, D.ConeColor)
			prev = p
		end
		-- weapon circle
		local range = prof.WeaponRange
		local n = D.RingSegments
		prev = onGround(c + Vector3.new(range, 0, 0))
		for i = 1, n do
			local a = 2 * math.pi * i / n
			local p = onGround(c + Vector3.new(math.cos(a) * range, 0, math.sin(a) * range))
			seg(prev, p, D.RangeColor)
			prev = p
		end
	end
	for i = used + 1, #pool do pool[i].Transparency = 1 end
	-- spotted enemies
	local live = {}
	for _, e in ipairs(Registry.all(false)) do
		local on = e.Model:GetAttribute("Spotted") == true
		mark(e.Model, on)
		live[e.Model] = true
	end
	for model in pairs(marks) do if not live[model] then mark(model, false) end end
end)
