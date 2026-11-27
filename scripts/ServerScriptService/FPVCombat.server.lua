-- ServerScriptService.FPVCombat  (Script)
-- FPVCombat: server-simulated straight FPV flight, corridor detection, one detonation.
-- Flies from start along dir at Height above ground. When the first qualifying enemy
-- (|cross| <= Width/2) is within DiveDistance ahead, it makes a curved nose-dive INTO
-- THAT ENEMY (owner's change from the spec's centerline detonation; it follows the enemy
-- if it moves) or into the Length endpoint. Damage falls linearly from Damage (centre) to
-- MinDamage (edge of BlastRadius, XZ). Flies Height above the ground; anything solid taller than
-- that in its way (walls, buildings) makes it explode there. While flying, the corridor outline
-- (Width x Length) stays on the ground for everyone.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local C = require(ReplicatedStorage:WaitForChild("WarConfig")).FPV
local U = require(ReplicatedStorage.WarShared.WarUtil)
local Registry = require(ReplicatedStorage.WarShared.EnemyRegistry)
local Damage = require(ServerScriptService.WarServer.Damage)
local Economy = require(ServerScriptService.WarServer.Economy)
local Air = require(ServerScriptService.WarServer.AircraftService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FPVCommand = Remotes.FPVCommand
local CombatFX = Remotes.CombatFX

local flightsFolder = U.folder("FPVFlights")
local effectsFolder = U.folder("WarFX")
local active = {} -- [Player] = flight

local function cleanup(player, flight)
	Air.unregister(flight.Air)
	if flight.Conn then
		flight.Conn:Disconnect()
	end
	if flight.Model then
		flight.Model:Destroy()
	end
	if flight.PathPart then
		flight.PathPart:Destroy()
	end
	if active[player] == flight then
		active[player] = nil
	end
	if player.Parent then
		player:SetAttribute("FPVActive", false)
	end
end

local function launch(player, start, dir)
	local template = ServerStorage:FindFirstChild("FPVDroneTemplate")
	local params = U.groundParams()
	local startGround = U.groundY(start.X, start.Z, start.Y + 20, params)
	start = Vector3.new(start.X, startGround, start.Z)

	local flight = { CalledAt = workspace:GetServerTimeNow() }
	active[player] = flight
	player:SetAttribute("FPVActive", true)

	-- corridor outline (edges only) until the drone explodes
	do
		local outline = Instance.new("Model")
		outline.Name = "FPVPath_" .. player.UserId
		local centre = CFrame.lookAlong(start + dir * (C.Length / 2) + Vector3.new(0, 0.15, 0), dir)
		local w, l, lw = C.Width, C.Length, 0.6
		for _, e in ipairs({
			{ lw, l + lw, CFrame.new(-w / 2, 0, 0) },
			{ lw, l + lw, CFrame.new(w / 2, 0, 0) },
			{ w + lw, lw, CFrame.new(0, 0, -l / 2) },
			{ w + lw, lw, CFrame.new(0, 0, l / 2) },
		}) do
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 150, 60)
			p.Transparency = 0.1
			p.Size = Vector3.new(e[1], 0.12, e[2])
			p.CFrame = centre * e[3]
			p.Parent = outline
		end
		outline.Parent = effectsFolder
		flight.PathPart = outline
	end

	local root, rootRel
	if template then
		local m = template:Clone()
		m.Name = "FPV_" .. player.UserId
		m:ScaleTo(m:GetScale() * C.DroneScale)
		root = m.PrimaryPart
		rootRel = m:GetPivot():ToObjectSpace(root.CFrame)
		m:PivotTo(CFrame.lookAlong(start + Vector3.new(0, C.Height, 0), dir))
		m.Parent = flightsFolder
		flight.Model = m
		local sound = Instance.new("Sound")
		sound.Name = "FPVFlightSound"
		sound.SoundId = "rbxassetid://76103248450884"
		sound.Volume = 0.3
		sound.Looped = true
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 25
		sound.RollOffMaxDistance = 650
		sound.Parent = root
		sound:Play()
	end

	local travelled = 0
	local flyY = startGround + C.Height -- current flight altitude (follows the ground at ClimbRate)
	local wallParams = U.groundParams()
	wallParams.RespectCanCollide = true
	local done = false
	local diving -- { P0, P1, P2, Along, T, Dur } once the nose-dive has started

	local function groundAt(along)
		local p = start + dir * along
		return Vector3.new(p.X, U.groundY(p.X, p.Z, startGround + 40, params), p.Z)
	end

	local function detonate(point)
		if done then
			return
		end
		done = true
		Damage.radial(point, C.BlastRadius, {
			Mode = "XZ",
			Falloff = function(d, r)
				return C.Damage - (C.Damage - C.MinDamage) * math.clamp(d / r, 0, 1)
			end,
			Source = "FPV",
			Player = player,
		})
		CombatFX:FireAllClients("Explosion", point, "FPV")
		cleanup(player, flight)
	end

	local function groundUnder(pos)
		return Vector3.new(pos.X, U.groundY(pos.X, pos.Z, pos.Y + 20, params), pos.Z)
	end

	-- Where the dive ends: the enemy itself (followed while it moves), or the path end.
	local function diveTarget()
		local e = diving.Enemy
		if e and e.Root.Parent and e.Humanoid.Health > 0 then
			diving.LastTarget = groundUnder(e.Root.Position)
		end
		return diving.LastTarget
	end

	-- Curved dive: quadratic Bezier from the level flight point, through a control point
	-- ahead (toward the target) at flight height, into the target -> starts level, ends nose-down.
	local function beginDive(entry, endAlong)
		local flat = start + dir * travelled
		local here = Vector3.new(flat.X, flyY, flat.Z)
		local target = entry and groundUnder(entry.Root.Position) or groundAt(endAlong)
		local flatTo = Vector3.new(target.X - here.X, 0, target.Z - here.Z)
		local ctrl = here + flatTo * 0.55
		local len = (ctrl - here).Magnitude + (target - ctrl).Magnitude
		diving = { P0 = here, P1 = ctrl, Enemy = entry, LastTarget = target, T = 0, Dur = math.max(len / (C.Speed * C.DiveSpeedMul), 0.15) }
	end

	-- can be shot down (AircraftService): blows up in the air without hurting anyone, cooldown x1.75
	flight.Air = Air.register({
		Skill = "FPV",
		Owner = player,
		GetCFrame = function()
			return root and root.Parent and root.CFrame or nil
		end,
		OnDown = function(pos)
			if done then
				return
			end
			done = true
			CombatFX:FireAllClients("Explosion", pos, "FPV")
			cleanup(player, flight)
			Economy.skillShotDown(player, "FPV", flight.CalledAt)
		end,
	})

	flight.Conn = RunService.Heartbeat:Connect(function(dt)
		if done then
			return
		end
		if diving then
			diving.T += dt
			local u = math.min(diving.T / diving.Dur, 1)
			local a, b, c = diving.P0, diving.P1, diveTarget()
			local pos = a * (1 - u) ^ 2 + b * (2 * (1 - u) * u) + c * (u * u)
			local tangent = (b - a) * (2 * (1 - u)) + (c - b) * (2 * u)
			if root and tangent.Magnitude > 1e-3 then
				root.CFrame = CFrame.lookAlong(pos, tangent.Unit) * rootRel
			end
			if u >= 1 then
				detonate(c)
			end
			return
		end

		local s0 = travelled
		local s1 = math.min(travelled + C.Speed * dt, C.Length)
		travelled = s1
		-- look ahead DiveDistance for the first qualifying enemy in the corridor
		local best, bestAlong
		for _, e in ipairs(Registry.all(false)) do
			local rel = e.Position - start
			local along = rel.X * dir.X + rel.Z * dir.Z
			if along > s0 and along <= math.min(s1 + C.DiveDistance, C.Length) then
				local cross = math.abs(rel.X * dir.Z - rel.Z * dir.X)
				if cross <= C.Width / 2 and (not bestAlong or along < bestAlong) then
					best, bestAlong = e, along
				end
			end
		end
		if best then
			beginDive(best) -- dives into the enemy itself
			return
		end
		if s1 + C.DiveDistance >= C.Length then
			beginDive(nil, C.Length) -- no enemy: still noses into the ground at the 400-stud end
			return
		end
		-- walls: anything solid at flight height between the last and this position -> explode there
		local from = start + dir * s0
		from = Vector3.new(from.X, flyY, from.Z)
		local wall = workspace:Raycast(from, dir * (s1 - s0 + 1), wallParams)
		if wall then
			detonate(wall.Position)
			return
		end
		-- follow the ground below the drone (only things lower than the drone count as ground)
		local flat = start + dir * s1
		local gy = U.groundY(flat.X, flat.Z, flyY - 0.5, params)
		flyY += math.clamp(gy + C.Height - flyY, -C.ClimbRate * dt, C.ClimbRate * dt)
		if root then
			root.CFrame = CFrame.lookAlong(Vector3.new(flat.X, flyY, flat.Z), dir) * rootRel
		end
	end)
end

FPVCommand.OnServerEvent:Connect(function(player, action, start, dir)
	if action ~= "Launch" then
		return
	end
	if active[player] then
		return -- one active flight per player
	end
	if not U.isFiniteVector(start) or not U.isFiniteVector(dir) then
		return
	end
	local flatDir = U.flat(dir)
	if not flatDir then
		return
	end
	if not Economy.trySkill(player, "FPV") then
		return
	end
	Economy.skillEnded(player, "FPV") -- cooldown starts as soon as the drone is called
	launch(player, start, flatDir)
end)

Players.PlayerRemoving:Connect(function(player)
	local flight = active[player]
	if flight then
		cleanup(player, flight)
	end
end)
