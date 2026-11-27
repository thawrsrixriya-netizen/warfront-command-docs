-- ServerScriptService.WaveServer  (Script)
-- WaveServer: runs the enemy waves (owner). Settings: ReplicatedStorage.WaveConfig.
-- Publishes ReplicatedStorage attributes read by MatchHUD: MatchWave, MatchWaveTotal, MatchEnemiesLeft,
-- MatchPhase "Waiting"|"Wave"|"Break"|"Victory", MatchBreakEnds (server time), MatchCanSkip (bool).
-- Remotes.MatchCommand "Skip": only while MatchCanSkip (the wave has run SkipAfter s and enemies are still
-- alive) -> the next wave starts now. AUTO SKIP (every player's AutoSkip attribute on) does the same
-- automatically. Breaks are not skippable.
-- Enemies: models in Workspace.Enemies, attributes WaveEnemy=true, UnitType, Wave. PLACEHOLDER movement:
-- the anchored yellow dummy glides along the path (real bots with AI will replace this later).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("WaveConfig"))
local CaptureConfig = require(ReplicatedStorage:WaitForChild("CaptureConfig"))
local EconomyConfig = require(ReplicatedStorage:WaitForChild("EconomyConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local command = Remotes:FindFirstChild("MatchCommand") or Instance.new("RemoteEvent")
command.Name = "MatchCommand"
command.Parent = Remotes

local enemiesFolder = workspace:FindFirstChild("Enemies") or Instance.new("Folder")
enemiesFolder.Name = "Enemies"
enemiesFolder.Parent = workspace
local templates = ServerStorage:WaitForChild("WaveEnemies")

local total = Config.TotalWaves[EconomyConfig.Difficulty] or Config.TotalWaves.Normal
ReplicatedStorage:SetAttribute("MatchWaveTotal", total)
ReplicatedStorage:SetAttribute("MatchWave", ReplicatedStorage:GetAttribute("MatchWave") or 0)
ReplicatedStorage:SetAttribute("MatchPhase", ReplicatedStorage:GetAttribute("MatchPhase") or "Waiting")
ReplicatedStorage:SetAttribute("MatchEnemiesLeft", 0)

---------------------------------------------------------------- paths
local pathsFolder = workspace:WaitForChild("MatchPoints"):WaitForChild("EnemyPaths")
local paths = {}
for _, f in ipairs(pathsFolder:GetChildren()) do
	local pts = {}
	for _, p in ipairs(f:GetChildren()) do
		if p:IsA("BasePart") and tonumber(p.Name) then
			table.insert(pts, p)
			p.Transparency = 1 -- markers only show in Studio
		end
	end
	table.sort(pts, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)
	local list = {}
	for _, p in ipairs(pts) do
		table.insert(list, p.Position - Vector3.new(0, p.Size.Y / 2, 0)) -- ground point
	end
	if #list >= 2 then
		table.insert(paths, list)
	end
end
assert(#paths > 0, "WaveServer: no paths in Workspace.MatchPoints.EnemyPaths")

local ground = workspace:FindFirstChild(CaptureConfig.GroundModel or "GroundAndTrenches")
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { ground or workspace.Terrain }
local function groundAt(x, z, fallbackY)
	local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rayParams)
	return Vector3.new(x, r and r.Position.Y or fallbackY, z)
end

-- a free spot inside the zone that the (placeholder, straight-line) walker can reach from `from`:
-- nothing solid around it, nothing solid above it (no roof), nothing solid on the straight way there.
local function blockers()
	local list = { enemiesFolder, workspace:FindFirstChild("MatchPoints"), ground }
	for _, name in ipairs({ "CommandInfantry", "CommandTanks", "ClientFX", "WarFX", "Aircraft" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local CollectionService = game:GetService("CollectionService")
	for _, tag in ipairs({ "TankReactiveTree", "TankPassThroughVegetation" }) do
		for _, t in ipairs(CollectionService:GetTagged(tag)) do
			table.insert(list, t)
		end
	end
	return list
end
local function zoneSpot(from)
	local zone = workspace.MatchPoints:FindFirstChild(CaptureConfig.ZoneName)
	if not zone then
		return nil
	end
	local list = blockers()
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = list
	overlap.RespectCanCollide = true
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = list
	ray.RespectCanCollide = true
	for _ = 1, 40 do
		-- short hop from `from` in a random direction, kept inside the zone
		local a = math.random() * math.pi * 2
		local d = 10 + math.random() * 50
		local p = from + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local rel = zone.CFrame:PointToObjectSpace(p)
		p = zone.CFrame:PointToWorldSpace(Vector3.new(math.clamp(rel.X, -zone.Size.X * 0.45, zone.Size.X * 0.45), 0, math.clamp(rel.Z, -zone.Size.Z * 0.45, zone.Size.Z * 0.45)))
		local spot = groundAt(p.X, p.Z, zone.Position.Y)
		local free = #workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 3.5, 0)), Vector3.new(5, 6, 5), overlap) == 0
		local openSky = free and workspace:Raycast(spot + Vector3.new(0, 1, 0), Vector3.new(0, 60, 0), ray) == nil
		local way = Vector3.new(spot.X - from.X, 0, spot.Z - from.Z)
		local reachable = openSky and workspace:Raycast(from + Vector3.new(0, 2, 0), way, ray) == nil
			and workspace:Raycast(from + Vector3.new(0, 0.8, 0), way, ray) == nil
		if reachable then
			return spot
		end
	end
	return nil -- no good spot: stay at the end of the road
end

---------------------------------------------------------------- enemies
local walkers = {} -- [model] = { Route = {Vector3}, Index, Speed, Lift }
local alive = 0
local function updateLeft()
	ReplicatedStorage:SetAttribute("MatchEnemiesLeft", alive)
end

local function spawnEnemy(kind, wave)
	local def = Config.Types[kind]
	local template = templates:FindFirstChild(def.Template)
	if not template then
		warn("WaveServer: missing template", def.Template)
		return
	end
	local m = template:Clone()
	m.Name = "Wave" .. kind
	if def.Scale and def.Scale ~= 1 then
		m:ScaleTo(m:GetScale() * def.Scale)
	end
	if def.Color then
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Color = def.Color
			end
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true -- placeholder: glides, no physics
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	local hp = math.floor(def.Health * (1 + Config.HealthGrowthPerWave * (wave - 1)) + 0.5)
	if hum then
		hum.MaxHealth = hp
		hum.Health = hp
	end
	m:SetAttribute("WaveEnemy", true)
	m:SetAttribute("UnitType", kind)
	m:SetAttribute("Wave", wave)
	-- route: the path with a small sideways offset, then a spot inside the centre zone
	local path = paths[math.random(1, #paths)]
	local side = (kind == "Soldier") and (math.random() * 2 - 1) * Config.LateralSpread or 0
	local route = {}
	for i, p in ipairs(path) do
		local nxt = path[math.min(i + 1, #path)]
		local prev = path[math.max(i - 1, 1)]
		local dir = Vector3.new(nxt.X - prev.X, 0, nxt.Z - prev.Z)
		local right = dir.Magnitude > 0.01 and Vector3.new(-dir.Unit.Z, 0, dir.Unit.X) or Vector3.zero
		table.insert(route, p + right * side)
	end
	-- then up to 3 straight, unblocked hops inside the zone so they spread out (never into houses)
	local hops = math.random(1, 3)
	for _ = 1, hops do
		local spot = zoneSpot(route[#route])
		if not spot then
			break
		end
		table.insert(route, spot)
	end
	local cf, size = m:GetBoundingBox()
	local lift = m:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	local start = route[1]
	m:PivotTo(CFrame.lookAt(start + Vector3.new(0, lift, 0), route[2] + Vector3.new(0, lift, 0)))
	m.Parent = enemiesFolder
	alive += 1
	updateLeft()
	walkers[m] = { Route = route, Index = 2, Speed = def.Speed, Lift = lift, Pos = start }
	if hum then
		hum.Died:Once(function()
			walkers[m] = nil
			alive -= 1
			updateLeft()
			task.delay(2, function()
				if m.Parent then
					m:Destroy()
				end
			end)
		end)
	end
	m.AncestryChanged:Connect(function(_, parent)
		if not parent and walkers[m] then
			walkers[m] = nil
			alive -= 1
			updateLeft()
		end
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for m, w in pairs(walkers) do
		local target = w.Route[w.Index]
		if target then
			local flat = Vector3.new(target.X - w.Pos.X, 0, target.Z - w.Pos.Z)
			local step = w.Speed * dt
			if flat.Magnitude <= step then
				w.Pos = target
				w.Index += 1
			else
				local dir = flat.Unit
				local nextPos = w.Pos + dir * step
				-- height: blend between waypoints
				local a, b = w.Route[w.Index - 1], target
				local total = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
				local done = Vector3.new(nextPos.X - a.X, 0, nextPos.Z - a.Z).Magnitude
				local y = a.Y + (b.Y - a.Y) * math.clamp(total > 0 and done / total or 1, 0, 1)
				w.Pos = Vector3.new(nextPos.X, y, nextPos.Z)
				local at = w.Pos + Vector3.new(0, w.Lift, 0)
				m:PivotTo(CFrame.lookAt(at, at + dir))
			end
		end
	end
end)

---------------------------------------------------------------- wave flow
local phase = "Waiting"
local skipRequested = false
local canSkip = false
local function setCanSkip(v)
	if canSkip ~= v then
		canSkip = v
		ReplicatedStorage:SetAttribute("MatchCanSkip", v)
	end
end
ReplicatedStorage:SetAttribute("MatchCanSkip", false)
local spawning = 0 -- waves still spawning

local function setPhase(p)
	phase = p
	ReplicatedStorage:SetAttribute("MatchPhase", p)
end

local function runWave(n)
	spawning += 1
	local queue = {}
	for kind, count in pairs(Config.composition(n)) do
		for _ = 1, count do
			table.insert(queue, kind)
		end
	end
	-- shuffle so types mix
	for i = #queue, 2, -1 do
		local j = math.random(1, i)
		queue[i], queue[j] = queue[j], queue[i]
	end
	task.spawn(function()
		for _, kind in ipairs(queue) do
			spawnEnemy(kind, n)
			task.wait(Config.SpawnInterval)
		end
		spawning -= 1
	end)
end

local function allAutoSkip()
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, p in ipairs(players) do
		if p:GetAttribute("AutoSkip") ~= true then
			return false
		end
	end
	return true
end

command.OnServerEvent:Connect(function(player, action, value)
	if action == "AutoSkip" then
		player:SetAttribute("AutoSkip", value == true)
		return
	end
	if action == "Skip" and phase == "Wave" and canSkip then
		skipRequested = true
	end
end)

-- wait for the first capture of the centre
while not ReplicatedStorage:GetAttribute("CenterCapturedOnce") do
	task.wait(0.5)
end

local wave = 1
while true do
	ReplicatedStorage:SetAttribute("MatchWave", wave)
	setPhase("Wave")
	skipRequested = false
	setCanSkip(false)
	runWave(wave)
	local waveStart = os.clock()
	-- wait until this wave (and any earlier) is spawned and cleared, or the wave is skipped
	-- (SKIP becomes possible after SkipAfter seconds while enemies are still alive)
	task.wait(0.5)
	while not (spawning == 0 and alive == 0) do
		setCanSkip(wave < total and os.clock() - waveStart >= Config.SkipAfter and alive > 0)
		if canSkip and allAutoSkip() then
			skipRequested = true
		end
		if skipRequested and canSkip then
			break
		end
		task.wait(0.25)
	end
	setCanSkip(false)
	if skipRequested and wave < total and alive > 0 then
		wave += 1 -- skipped: next wave comes now, current enemies stay
		continue
	end
	if wave >= total then
		setPhase("Victory")
		break
	end
	-- break
	local length = (wave % Config.BreakEvery == 0) and Config.LongBreak or Config.ShortBreak
	setPhase("Break")
	skipRequested = false
	local ends = workspace:GetServerTimeNow() + length
	ReplicatedStorage:SetAttribute("MatchBreakEnds", ends)
	while workspace:GetServerTimeNow() < ends do
		task.wait(0.2)
	end
	wave += 1
end
