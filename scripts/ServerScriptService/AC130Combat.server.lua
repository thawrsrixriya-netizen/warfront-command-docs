-- ServerScriptService.AC130Combat  (Script)
-- AC130Combat: one AC-130 per player. Lifecycle entry -> attack (40 s, or 10 s with no
-- enemies, or R) -> departure beyond the map. Damage is server-side via Damage module.
-- The plane itself is rendered by every client from AC130Path (smooth, no per-frame replication).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("WarConfig")).AC130
local U = require(ReplicatedStorage.WarShared.WarUtil)
local Path = require(ReplicatedStorage.WarShared.AC130Path)
local Registry = require(ReplicatedStorage.WarShared.EnemyRegistry)
local Damage = require(ServerScriptService.WarServer.Damage)
local Targeting = require(ServerScriptService.WarServer.AC130Targeting)
local Economy = require(ServerScriptService.WarServer.Economy)
local Air = require(ServerScriptService.WarServer.AircraftService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AC130Command = Remotes.AC130Command
local CombatFX = Remotes.CombatFX

local states = {} -- [Player] = state
local SHELL_SPEED = 700

local function now()
	return workspace:GetServerTimeNow()
end

local mapSpanCache
local function mapSpan()
	if mapSpanCache then
		return mapSpanCache
	end
	local span = Config.MinMapSpan
	for _, c in ipairs(workspace:GetChildren()) do
		if c:IsA("BasePart") and c.Anchored and not c:IsA("Terrain") then
			span = math.max(span, c.Size.X, c.Size.Z)
		end
	end
	mapSpanCache = span
	return span
end

local function depart(player, st)
	if st.Phase == "depart" then
		return
	end
	st.Phase = "depart"
	st.Params.TDepart = now()
	CombatFX:FireAllClients("AC130Depart", player.UserId, st.Params.TDepart)
	task.spawn(function()
		while not Path.departDone(st.Params, now()) do
			task.wait(0.2)
		end
		if st.Phase == "down" then
			return -- shot down while leaving: already handled
		end
		Air.unregister(st.Air)
		if states[player] == st then
			states[player] = nil
		end
		CombatFX:FireAllClients("AC130End", player.UserId)
		Economy.skillEnded(player, "AC130")
	end)
end

-- shot down by enemy fire (AircraftService): wreck falls on every client, cooldown x1.75
local function shotDown(player, st, pos)
	if st.Phase == "down" or st.Phase == "gone" then
		return
	end
	st.Phase = "down"
	if states[player] == st then
		states[player] = nil
	end
	local _, fwd, _, _, speed = Path.state(st.Params, now())
	CombatFX:FireAllClients("AC130Down", player.UserId, pos, fwd * (speed or Path.OrbitSpeed))
	Economy.skillShotDown(player, "AC130")
end

local function groundAt(xz, st)
	local y = U.groundY(xz.X, xz.Y, st.Params.GroundY + 40)
	return Vector3.new(xz.X, y, xz.Y)
end

local GUNS = {
	{ Id = "Heavy", Kind = "AOE", Spec = Config.Guns.Heavy, Style = "Heavy" },
	{ Id = "Secondary", Kind = "AOE", Spec = Config.Guns.Secondary, Style = "Secondary" },
	{ Id = "MG1", Kind = "Single", Spec = Config.Guns.Machine, Style = "MG" },
	{ Id = "MG2", Kind = "Single", Spec = Config.Guns.Machine, Style = "MG" },
}

local function plan(st)
	local p = st.Params
	local selR = Config.SelectRadius
	local cancelled = function()
		return st.Phase ~= "attack"
	end
	local reserved = {}
	local plans = {}
	local inSel = Registry.inRadius(p.Center, selR, "XZ")
	for _, gun in ipairs(GUNS) do
		local prev = st.Plans[gun.Id]
		if gun.Kind == "AOE" then
			local wide = Registry.inRadius(p.Center, selR + gun.Spec.BlastRadius, "XZ")
			local aim, primary = Targeting.planAOE(wide, p.Center, selR, gun.Spec.BlastRadius, reserved, prev and prev.Aim, cancelled)
			if cancelled() then
				return nil
			end
			if aim then
				reserved[primary] = true
				plans[gun.Id] = { Aim = aim, Primary = primary }
			end
		else
			local target = Targeting.planSingle(inSel, p.Center, reserved, prev and prev.Primary)
			if target then
				reserved[target] = true
				plans[gun.Id] = { Primary = target }
			end
		end
	end
	return plans
end

local function fire(player, st, gun, gunPlan)
	local origin = Path.state(st.Params, now())
	origin -= Vector3.new(0, 2, 0)
	if gun.Kind == "AOE" then
		local impact = groundAt(gunPlan.Aim, st)
		local travel = (impact - origin).Magnitude / SHELL_SPEED
		CombatFX:FireAllClients("Shell", origin, impact, travel, gun.Style)
		task.delay(travel, function()
			Damage.radial(impact, gun.Spec.BlastRadius + 0.01, { Amount = gun.Spec.Damage, Mode = "XZ", Source = "AC130" .. gun.Id, Player = player })
			CombatFX:FireAllClients("Explosion", impact, gun.Style)
		end)
	else
		local model = gunPlan.Primary
		local root = model and Registry.rootOf(model)
		if not root then
			return
		end
		local hitPos = root.Position
		local travel = (hitPos - origin).Magnitude / SHELL_SPEED
		CombatFX:FireAllClients("Shell", origin, hitPos, travel, "MG")
		task.delay(travel, function()
			Damage.apply(model, gun.Spec.Damage, "AC130" .. gun.Id, player)
			local ground = groundAt(Vector2.new(hitPos.X, hitPos.Z), st)
			CombatFX:FireAllClients("Explosion", ground, "MG")
		end)
	end
end

local function run(player, st)
	local p = st.Params
	local readyAt = p.T0 + Path.entryDuration(p)
	while st.Phase == "entry" do
		if now() >= readyAt then
			st.Phase = "attack"
			st.AttackStart = now()
			CombatFX:FireAllClients("AC130Ready", player.UserId)
		else
			task.wait(0.1)
		end
	end
	local lastSeen = now()
	local nextPlan = 0
	local nextFire = {}
	for _, gun in ipairs(GUNS) do
		nextFire[gun.Id] = now() + math.random() * 0.2
	end
	while st.Phase == "attack" do
		local t = now()
		if t - st.AttackStart >= Config.AttackDuration then
			depart(player, st)
			break
		end
		if #Registry.inRadius(p.Center, Config.SelectRadius, "XZ") > 0 then
			lastSeen = t
		elseif t - lastSeen >= Config.EmptyTimeout then
			depart(player, st)
			break
		end
		if t >= nextPlan then
			local plans = plan(st)
			if not plans then
				break
			end
			st.Plans = plans
			nextPlan = now() + Config.ReplanInterval
			local h, s = plans.Heavy, plans.Secondary
			CombatFX:FireAllClients("AC130Plan", player.UserId, h and h.Aim, s and s.Aim)
		end
		t = now()
		for _, gun in ipairs(GUNS) do
			local gp = st.Plans[gun.Id]
			if t >= nextFire[gun.Id] then
				if gp then
					fire(player, st, gun, gp)
					nextFire[gun.Id] = t + gun.Spec.Interval
				else
					nextFire[gun.Id] = t -- idle: fire as soon as a valid target exists
				end
			end
		end
		task.wait()
	end
end

AC130Command.OnServerEvent:Connect(function(player, action, point)
	if action == "Start" then
		if states[player] or not U.isFiniteVector(point) then
			if states[player] then
				AC130Command:FireClient(player, "Busy")
			end
			return
		end
		if not Economy.trySkill(player, "AC130") then
			return
		end
		local groundY = U.groundY(point.X, point.Z, point.Y + 20)
		local params = {
			Center = Vector3.new(point.X, groundY + Config.MinAltitudeAboveGround, point.Z),
			GroundY = groundY,
			Theta0 = math.random() * math.pi * 2,
			EntryDistance = mapSpan() + Config.EntryExtra,
			T0 = now() + 0.2,
		}
		local st = { Params = params, Phase = "entry", Plans = {} }
		states[player] = st
		st.Air = Air.register({
			Skill = "AC130",
			Owner = player,
			GetCFrame = function()
				local pos, fwd = Path.state(params, now())
				return CFrame.lookAlong(pos, fwd)
			end,
			OnDown = function(pos)
				shotDown(player, st, pos)
			end,
		})
		AC130Command:FireClient(player, "Started")
		CombatFX:FireAllClients("AC130Start", player.UserId, params)
		task.spawn(run, player, st)
	elseif action == "Cancel" then
		local st = states[player]
		if st then
			depart(player, st)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local st = states[player]
	if st then
		st.Phase = "gone"
		Air.unregister(st.Air)
		states[player] = nil
		CombatFX:FireAllClients("AC130End", player.UserId)
	end
end)
