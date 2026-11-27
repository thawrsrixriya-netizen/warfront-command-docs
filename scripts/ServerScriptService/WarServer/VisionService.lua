-- ServerScriptService.WarServer.VisionService  (ModuleScript)
-- VisionService (server, OWNER system). Shared sight for every unit.
-- Rules: a unit sees an enemy when the enemy is inside its sight triangle (VisionRange / VisionAngle,
-- facing the unit's yaw) or inside AwareRadius, AND nothing solid blocks the line between them.
-- Whatever ANY unit of a team sees, the whole team sees (all units, all players).
-- An enemy stays visible MemorySeconds after the last unit loses sight.
--
-- API (use these from unit scripts):
--   VisionService.register(model, opts)   -- opts: Team ("Player"/"Enemy"), Profile (VisionConfig.Profiles key),
--        GetYaw()   -> number (radians, same convention as atan2(-dx,-dz)),
--        GetEye()   -> Vector3 or nil (nil = cannot see right now, e.g. inside a vehicle),
--        OnAttacked(fromPosition) optional callback
--        Group  optional string: units with the same Group (e.g. one 6-soldier squad) count as ONE viewer:
--               one sight triangle at the group's centre, facing the group's average facing
--   VisionService.isVisible(target, team) -> bool
--   VisionService.nearestVisible(position, range, team) -> model, distance
--   VisionService.notifyAttacked(victimModel, fromPosition)  -- call from any enemy weapon when it hits a unit
--      (or set attribute victimModel:SetAttribute("AttackedFrom", shooterPosition))
--   VisionService.profile(name) -> profile table
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.VisionConfig)
local Registry = require(RS.WarShared.EnemyRegistry)

local Vision = {}
local viewers = {}   -- model -> info
local lastSeen = {}  -- team -> { [targetModel] = time }
local started = false

function Vision.profile(name)
	return Config.Profiles[name] or Config.Profiles.Infantry
end

local function alive(model)
	if not model or not model.Parent then return false end
	local h = model:FindFirstChildOfClass("Humanoid")
	return h == nil or h.Health > 0
end

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

-- Targets a team can see: Player team -> registered enemies (EnemyRegistry);
-- any other team -> registered units of other teams.
local function targetsFor(team)
	local list = {}
	if team == "Player" then
		for _, e in ipairs(Registry.all(false)) do
			table.insert(list, { Model = e.Model, Position = e.Position })
		end
	end
	for model, info in pairs(viewers) do
		if info.Team ~= team and alive(model) and not (team == "Player" and Registry.isEnemyModel(model)) then
			local r = rootOf(model)
			if r then table.insert(list, { Model = model, Position = r.Position }) end
		end
	end
	return list
end

local function lineClear(from, target, toPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(exclude, p.Character) end
	end
	for model in pairs(viewers) do table.insert(exclude, model) end
	local fx = workspace:FindFirstChild("ClientFX")
	if fx then table.insert(exclude, fx) end
	local origin = from
	for _ = 1, 6 do
		params.FilterDescendantsInstances = exclude
		local dir = toPos - origin
		local hit = workspace:Raycast(origin, dir, params)
		if not hit then return true end
		if hit.Instance:IsDescendantOf(target) then return true end
		if hit.Instance.Transparency >= Config.SeeThroughTransparency then
			table.insert(exclude, hit.Instance)
			origin = hit.Position
		else
			return false
		end
	end
	return false
end

local function canSee(info, model, targetPos)
	local eye = info.GetEye and info.GetEye()
	if not eye then return false end
	local prof = Vision.profile(info.Profile)
	local delta = targetPos - eye
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local dist = flat.Magnitude
 local extra=info.GetCones and info.GetCones() or {}
 local maxRange=prof.VisionRange
 for _,c in ipairs(extra) do maxRange=math.max(maxRange,c.Range) end
 if dist>maxRange then return false end
	if dist > prof.AwareRadius then
		local yaws = info.GetYaws and info.GetYaws() or { info.GetYaw and info.GetYaw() or 0 }
		local cosHalf = math.cos(math.rad(prof.VisionAngle / 2))
		local inCone = false
		for _, yaw in ipairs(yaws) do
			local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
			if dist<=prof.VisionRange and flat.Unit:Dot(forward) >= cosHalf then inCone = true break end
		end
  if not inCone then
   for _,c in ipairs(extra) do
    local forward=Vector3.new(-math.sin(c.Yaw),0,-math.cos(c.Yaw))
    if dist<=c.Range and flat.Unit:Dot(forward)>=math.cos(math.rad(c.Angle/2)) then inCone=true break end
   end
  end
  if not inCone then return false end
	end
	return lineClear(eye, model, targetPos)
end

local function step()
	local now = os.clock()
	local teams = {}
	local groups = {}
	for model, info in pairs(viewers) do
		if not model.Parent then
			viewers[model] = nil
		elseif alive(model) then
			teams[info.Team] = teams[info.Team] or {}
			if info.Group then
				-- squad: merge members into one viewer at the centre
				local eye = info.GetEye and info.GetEye()
				if eye then
					local key = info.Team .. "|" .. info.Group
					local g = groups[key]
					if not g then
						g = { Sum = Vector3.zero, N = 0, Dir = Vector3.zero }
						groups[key] = g
						table.insert(teams[info.Team], {
							Profile = info.Profile,
							GetEye = function() return g.Sum / g.N end,
							GetYaw = function()
								local d = g.Dir
								if d.Magnitude < 1e-3 then return 0 end
								return math.atan2(-d.X, -d.Z)
							end,
						})
					end
					local yaw = info.GetYaw and info.GetYaw() or 0
					g.Sum += eye
					g.N += 1
					g.Dir += Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
				end
			else
				table.insert(teams[info.Team], info)
			end
		end
	end
	for team, list in pairs(teams) do
		local seen = lastSeen[team] or {}
		lastSeen[team] = seen
		for _, t in ipairs(targetsFor(team)) do
			for _, info in ipairs(list) do
				if canSee(info, t.Model, t.Position) then
					seen[t.Model] = now
					break
				end
			end
		end
	end
	-- forget old entries and publish "Spotted" for the Player team (clients use it for display)
	for team, seen in pairs(lastSeen) do
		for model, t in pairs(seen) do
			local visible = model.Parent ~= nil and alive(model) and now - t <= Config.MemorySeconds
			if team == "Player" then model:SetAttribute("Spotted", visible or nil) end
			if not visible then seen[model] = nil end
		end
	end
end

local function start()
	if started then return end
	started = true
	task.spawn(function()
		while true do
			local ok, err = pcall(step)
			if not ok then warn("VisionService:", err) end
			task.wait(Config.Tick)
		end
	end)
end

function Vision.register(model, opts)
	start()
	viewers[model] = {
		Team = opts.Team or "Player",
		Profile = opts.Profile or "Infantry",
		GetYaw = opts.GetYaw,
  GetCones = opts.GetCones, -- optional extra cones with independent angles/ranges
		GetYaws = opts.GetYaws, -- optional multiple independent sight cones
		GetEye = opts.GetEye,
		OnAttacked = opts.OnAttacked,
		Group = opts.Group,
	}
	if opts.Group then model:SetAttribute("VisionGroup", opts.Group) end
	model:SetAttribute("VisionProfile", opts.Profile or "Infantry")
	model:SetAttribute("VisionTeam", opts.Team or "Player")
	-- Any script (even one that cannot require this module) can also report a hit by setting
	-- the Vector3 attribute "AttackedFrom" on the unit model.
	model:GetAttributeChangedSignal("AttackedFrom"):Connect(function()
		local from = model:GetAttribute("AttackedFrom")
		if typeof(from) == "Vector3" then Vision.notifyAttacked(model, from) end
	end)
end

function Vision.unregister(model)
	viewers[model] = nil
end

function Vision.isVisible(target, team)
	local seen = lastSeen[team or "Player"]
	local t = seen and seen[target]
	return t ~= nil and os.clock() - t <= Config.MemorySeconds and alive(target)
end

function Vision.nearestVisible(position, range, team)
	local seen = lastSeen[team or "Player"]
	if not seen then return nil end
	local best, bestD
	local now = os.clock()
	for model, t in pairs(seen) do
		if now - t <= Config.MemorySeconds and alive(model) then
			local r = rootOf(model)
			if r then
				local d = (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
				if d <= range and (not bestD or d < bestD) then best, bestD = model, d end
			end
		end
	end
	return best, bestD
end

function Vision.notifyAttacked(victim, fromPosition)
	local info = viewers[victim]
	if info and info.OnAttacked and typeof(fromPosition) == "Vector3" then
		info.OnAttacked(fromPosition)
	end
end

return Vision
