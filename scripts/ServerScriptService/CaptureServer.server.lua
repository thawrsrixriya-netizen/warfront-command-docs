-- ServerScriptService.CaptureServer  (Script)
-- CaptureServer: who holds the centre base (Workspace.MatchPoints.CenterBase).
-- One control value from -1 (full RED = enemy holds) to +1 (full BLUE = we hold).
-- Every Tick it adds up the strength of our units and of the enemies inside the zone. A side pushes the
-- bar toward its colour when its strength > the other side's x AdvantageRatio (more strength = a bit faster).
-- Draining the other colour is DrainSpeed x faster than filling; at 0 the centre becomes NEUTRAL, at the
-- end it is captured. Contested (both inside, nobody strong enough): the bar holds.
-- Nobody pushing: the bar slowly returns to its holder's end (neutral: stays).
-- Published on the zone part:
--   CaptureOwner "Enemy"|"Player"|"None", CaptureControl -1..1, CaptureProgress = |CaptureControl|,
--   CaptureBy "Player"|"Enemy"|"" (who is pushing now), PlayerStrength, EnemyStrength, Contested (bool)
-- ReplicatedStorage attributes (always replicated, unlike the streamed zone part): CenterOwner,
--   CenterControl, CenterBy, CenterPlayerStrength, CenterEnemyStrength, CenterContested,
--   CenterZoneCFrame, CenterZoneSize, CenterCapturedOnce (bool).
-- First player capture -> ReplicatedStorage MatchWave = 1, MatchPhase = "Wave" (wave system reads these).
-- Other scripts can listen: ServerScriptService.CaptureServer.Changed (BindableEvent: newOwner, oldOwner).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("CaptureConfig"))
local Registry = require(ReplicatedStorage:WaitForChild("WarShared"):WaitForChild("EnemyRegistry"))

local changed = Instance.new("BindableEvent")
changed.Name = "Changed"
changed.Parent = script

local zone = workspace:WaitForChild(Config.ZoneFolder):WaitForChild(Config.ZoneName)
zone.Transparency = 1 -- the outline is drawn by CaptureZoneClient
zone.CanCollide, zone.CanQuery, zone.CanTouch = false, false, false
zone.Anchored = true

ReplicatedStorage:SetAttribute("CenterZoneCFrame", zone.CFrame)
ReplicatedStorage:SetAttribute("CenterZoneSize", zone.Size)

local owner = Config.StartOwner
local control = owner == "Player" and 1 or owner == "Enemy" and -1 or 0
zone:SetAttribute("CaptureOwner", owner)
ReplicatedStorage:SetAttribute("CenterOwner", owner)
ReplicatedStorage:SetAttribute("CenterCapturedOnce", false)

local function inside(pos)
	local rel = zone.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2
end

local PS, ES = Config.PlayerStrength, Config.EnemyStrength
local function playerStrength()
	local total = 0
	local infantry = workspace:FindFirstChild("CommandInfantry")
	if infantry then
		for _, m in ipairs(infantry:GetChildren()) do
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if m:GetAttribute("OwnerUserId") and hum and hum.Health > 0 and root and not m:GetAttribute("Embarked") and inside(root.Position) then
				total += PS.InfantrySquad / PS.SquadSize
			end
		end
	end
	local vehicles = workspace:FindFirstChild("CommandTanks")
	if vehicles then
		for _, m in ipairs(vehicles:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("OwnerUserId") and inside(m:GetPivot().Position) then
				total += PS[m:GetAttribute("UnitType") or "BMP"] or PS.BMP
			end
		end
	end
	return total
end

local function enemyStrength()
	local total = 0
	for _, e in ipairs(Registry.all(false)) do
		if e.Model and inside(e.Position) then
			total += ES[e.Model:GetAttribute("UnitType") or "Soldier"] or ES.Soldier
		end
	end
	return total
end

local function setOwner(newOwner)
	if newOwner == owner then
		return
	end
	local old = owner
	owner = newOwner
	zone:SetAttribute("CaptureOwner", owner)
	ReplicatedStorage:SetAttribute("CenterOwner", owner)
	if owner == "Player" and not ReplicatedStorage:GetAttribute("CenterCapturedOnce") then
		ReplicatedStorage:SetAttribute("CenterCapturedOnce", true)
		if Config.FirstCaptureStartsWave and (ReplicatedStorage:GetAttribute("MatchWave") or 0) == 0 then
			ReplicatedStorage:SetAttribute("MatchWave", 1)
			ReplicatedStorage:SetAttribute("MatchPhase", "Wave")
		end
	end
	changed:Fire(owner, old)
end

-- move control toward `sign` (+1 blue / -1 red) at the fill rate; draining the other colour is faster
local function push(sign, rate, dt)
	local fill = dt / Config.CaptureTime * rate
	local before = control
	if control * sign < 0 then
		-- still the other side's colour: drain it fast
		control += sign * fill * Config.DrainSpeed
		if control * sign >= 0 then
			control = 0
		end
	else
		control = math.clamp(control + sign * fill, -1, 1)
	end
	if before ~= 0 and control == 0 then
		setOwner("None")
	end
	if control >= 1 then
		setOwner("Player")
	elseif control <= -1 then
		setOwner("Enemy")
	end
end

while true do
	local dt = task.wait(Config.Tick)
	local ps, es = playerStrength(), enemyStrength()
	local by = ""
	local function rate(s)
		return math.clamp(1 + Config.SpeedBonusPerPoint * math.max(s - PS.InfantrySquad, 0), 1, Config.MaxSpeedMultiplier)
	end
	if ps > 0 and ps > es * Config.AdvantageRatio and control < 1 then
		by = "Player"
		push(1, rate(ps), dt)
	elseif es > 0 and es > ps * Config.AdvantageRatio and control > -1 then
		by = "Enemy"
		push(-1, rate(es), dt)
	elseif ps == 0 and es == 0 then
		-- nobody inside: slowly back to the holder's end (no change while neutral)
		local home = owner == "Player" and 1 or owner == "Enemy" and -1 or nil
		if home and control ~= home then
			local step = dt / Config.DecayTime
			control = home > 0 and math.min(control + step, 1) or math.max(control - step, -1)
		end
	end
	zone:SetAttribute("CaptureControl", control)
	zone:SetAttribute("CaptureProgress", math.abs(control))
	zone:SetAttribute("CaptureBy", by)
	zone:SetAttribute("PlayerStrength", math.floor(ps * 100 + 0.5) / 100)
	zone:SetAttribute("EnemyStrength", math.floor(es * 100 + 0.5) / 100)
	zone:SetAttribute("Contested", ps > 0 and es > 0 and by == "")
	-- mirror for clients
	ReplicatedStorage:SetAttribute("CenterControl", control)
	ReplicatedStorage:SetAttribute("CenterBy", by)
	ReplicatedStorage:SetAttribute("CenterPlayerStrength", zone:GetAttribute("PlayerStrength"))
	ReplicatedStorage:SetAttribute("CenterEnemyStrength", zone:GetAttribute("EnemyStrength"))
	ReplicatedStorage:SetAttribute("CenterContested", zone:GetAttribute("Contested"))
end
