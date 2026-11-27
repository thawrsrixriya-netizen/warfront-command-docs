-- ServerScriptService.BomberCombat  (Script)
-- BomberCombat: validates a bomber pass, picks 5 stratified random impacts inside the
-- RectWidth x RectLength rectangle (30x60), broadcasts the pass to all clients (they render plane + bombs), and applies
-- server-side damage to ALL registered enemies at each impact time:
--   damage = MaxDamage * (1 - d / DamageRadius), 3D distance to the enemy root.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local C = require(ReplicatedStorage:WaitForChild("WarConfig")).Bomber
local U = require(ReplicatedStorage.WarShared.WarUtil)
local Damage = require(ServerScriptService.WarServer.Damage)
local Economy = require(ServerScriptService.WarServer.Economy)
local Air = require(ServerScriptService.WarServer.AircraftService)
local passCount = 0
local Path = require(ReplicatedStorage.WarShared.BomberPath)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BomberCommand = Remotes.BomberCommand
local CombatFX = Remotes.CombatFX

local active = {} -- [Player] = true while a pass is running
local LEAD = 0.15 -- seconds of lead so clients can start the plane in sync

BomberCommand.OnServerEvent:Connect(function(player, action, anchor, dir)
	if action ~= "Launch" or active[player] then
		return
	end
	if not U.isFiniteVector(anchor) or not U.isFiniteVector(dir) then
		return
	end
	dir = U.flat(dir)
	if not dir then
		return
	end
	if not Economy.trySkill(player, "Bomber") then
		return
	end
	Economy.skillEnded(player, "Bomber") -- cooldown starts as soon as the strike is called
	local calledAt = workspace:GetServerTimeNow()
	active[player] = true

	local params = U.groundParams()
	local anchorY = U.groundY(anchor.X, anchor.Z, anchor.Y + 20, params)
	anchor = Vector3.new(anchor.X, anchorY, anchor.Z)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local margin = 0.6
	local impacts = {}
 local releaseTimes = {}
 local fallDurations={}
 local gap=C.RectLength/C.BombCount*.65
 local freeLength=C.RectLength-2*margin-gap*(C.BombCount-1)
 local randomAlong={}
 for i=1,C.BombCount do randomAlong[i]=math.random()*freeLength end
 table.sort(randomAlong)
	for i = 0, C.BombCount - 1 do
		local along = margin+randomAlong[i+1]+i*gap
		along = math.clamp(along, margin, C.RectLength - margin)
		local lateral = (math.random() * 2 - 1) * (C.RectWidth*.5-margin)
		local p = anchor + dir * along + right * lateral
		local gy = U.groundY(p.X, p.Z, anchorY + 20, params)
		impacts[i + 1] = Vector3.new(p.X, gy, p.Z)
  releaseTimes[i+1]=Path.releaseTime({},along,i+1)
  fallDurations[i+1]=(C.StartDistance+along)/C.FlightSpeed-releaseTimes[i+1]
	end

	local t0 = workspace:GetServerTimeNow() + LEAD
	local altitude = math.max(C.DefaultAltitude, anchorY + C.MinAltitudeAboveGround)
 local pass={Anchor=anchor,Dir=dir,Altitude=altitude,T0=t0,Impacts=impacts,ReleaseTimes=releaseTimes,FallDurations=fallDurations,
 StartDistance=C.StartDistance,FlightSpeed=C.FlightSpeed,RunSpeed=C.BombRunSpeed,FallDuration=C.FallDuration}
 passCount += 1
 pass.Id = passCount
 pass.Lifetime=Path.duration(pass)
 pass.ReleaseOrigins={}
 for index,impact in impacts do
  local lateral=(impact-anchor):Dot(right)
  pass.ReleaseOrigins[index]=Path.position(pass,releaseTimes[index])+right*lateral-Vector3.new(0,C.BombReleaseDrop,0)
 end
 CombatFX:FireAllClients("Bomber",pass)

	-- can be shot down (AircraftService): bombs not yet released are cancelled, wreck falls, cooldown x1.75
	local downAt -- seconds after T0
	local air = Air.register({
		Skill = "Bomber",
		Owner = player,
		GetCFrame = function()
			return CFrame.lookAlong(Path.position(pass, workspace:GetServerTimeNow() - t0), dir)
		end,
		OnDown = function()
			downAt = workspace:GetServerTimeNow() - t0
			CombatFX:FireAllClients("BomberDown", pass.Id, downAt)
			Economy.skillShotDown(player, "Bomber", calledAt)
		end,
	})

	for i, impact in ipairs(impacts) do
		local impactTime = math.max(0,t0+releaseTimes[i]+fallDurations[i]-workspace:GetServerTimeNow())
		task.delay(impactTime, function()
			if downAt and releaseTimes[i] > downAt then
				return -- the plane was shot down before releasing this bomb
			end
			Damage.radial(impact, C.DamageRadius, {
				Mode = "3D",
				Falloff = Damage.linearFalloff(C.MaxDamage),
				Source = "Bomber",
				Player = player,
			})
		end)
	end
	task.delay(LEAD + pass.Lifetime, function()
		active[player] = nil
		Air.unregister(air)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	active[player] = nil
end)
