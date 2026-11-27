-- StarterPlayer.StarterPlayerScripts.AC130Input  (LocalScript)
-- AC130Input: called from the Skill Shop (aim, then click the ground); the shop's RECALL ends the attack.
-- Also renders every active AC-130 locally from the shared AC130Path, with its circles.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WarConfig")).AC130
local Shared = ReplicatedStorage:WaitForChild("WarShared")
local Client = ReplicatedStorage:WaitForChild("WarClient")
local U = require(Shared:WaitForChild("WarUtil"))
local Path = require(Shared:WaitForChild("AC130Path"))
local FX = require(Shared:WaitForChild("FX"))
local InputMode = require(Client:WaitForChild("InputMode"))
local Aim = require(Client:WaitForChild("Aim"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AC130Command = Remotes:WaitForChild("AC130Command")
local CombatFX = Remotes:WaitForChild("CombatFX")
local player = Players.LocalPlayer

---------------------------------------------------------------- input
-- Called from the Skill Shop: aim mode shows the orbit (d=400) and select (d=200) circles at
-- the mouse; a left click calls the AC-130 there. Escape or X cancels (X via MatchHUD). The shop's RECALL ends it.
local SkillActions = require(Client:WaitForChild("SkillActions"))
local MODE = "AC130Aim"
local preview -- { Model, Orbit, Select, Conn }
local state = "Ready" -- "Ready" | "Active" | "Leaving" (this player's own AC-130)

local function clearPreview()
	if preview then
		preview.Conn:Disconnect()
		preview.Model:Destroy()
		preview = nil
	end
end

local function updatePreview()
	local hit = Aim.groundHit()
	if preview and hit then
		local p = hit + Vector3.new(0, 0.15, 0)
		FX.moveRing(preview.Orbit, p)
		FX.moveRing(preview.Select, p)
	end
end

local function enterAim()
	if InputMode.get() == MODE or state ~= "Ready" then
		return
	end
	InputMode.enter(MODE, clearPreview)
	local m = Instance.new("Model")
	m.Name = "AC130AimPreview"
	m.Parent = FX.folder()
	preview = { Model = m }
	preview.Orbit = FX.ring(Vector3.zero, Config.OrbitRadius, Color3.fromRGB(255, 255, 255), 0.55, 0.5, 72, m)
	preview.Select = FX.ring(Vector3.zero, Config.SelectRadius, Color3.fromRGB(255, 80, 60), 0.4, 0.5, 56, m)
	preview.Conn = RunService.RenderStepped:Connect(updatePreview)
	updatePreview()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if InputMode.isTyping() or InputMode.get() ~= MODE then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		InputMode.exit(MODE)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		InputMode.blockClicks(0.25)
		local point = Aim.groundHit()
		if point then
			AC130Command:FireServer("Start", point)
			InputMode.exit(MODE)
		end
	end
end)

local function setState(s)
	if state ~= s then
		state = s
		SkillActions.notify("AC130")
	end
end

SkillActions.register("AC130", {
	Mode = MODE,
	Call = enterAim,
	Recall = function()
		AC130Command:FireServer("Cancel")
	end,
	State = function()
		return state
	end,
	Hint = "Click the ground to call the AC-130 there",
})

---------------------------------------------------------------- announcement
local announceGui = Instance.new("ScreenGui")
announceGui.Name = "AC130Announcement"
announceGui.ResetOnSpawn = false
announceGui.Parent = player:WaitForChild("PlayerGui")
local announce = Instance.new("TextLabel")
announce.AnchorPoint = Vector2.new(0.5, 0)
announce.Position = UDim2.new(0.5, 0, 0, 172) -- below the MatchHUD wave panel and hint bar
announce.Size = UDim2.new(0, 520, 0, 34)
announce.BackgroundTransparency = 1
announce.Font = Enum.Font.GothamBlack
announce.TextSize = Config.AnnouncementTextSize
announce.TextColor3 = Color3.fromRGB(235, 30, 30)
announce.TextStrokeTransparency = 0.5
announce.Text = Config.Announcement
announce.Visible = false
announce.Parent = announceGui
local announceToken = 0

AC130Command.OnClientEvent:Connect(function(kind)
	if kind == "Started" then
		announceToken += 1
		local token = announceToken
		announce.Visible = true
		task.delay(Config.AnnouncementDuration, function()
			if token == announceToken then
				announce.Visible = false
			end
		end)
	end
end)

---------------------------------------------------------------- rendering
local template = ReplicatedStorage:WaitForChild("AC130Template", 10)
local visuals = U.folder("AC130Visuals")
local planes = {} -- [userId] = { Params, Model, Props, Rings }
local flightSoundTemplate=Instance.new("Sound")
flightSoundTemplate.Name="AC130Flight"
flightSoundTemplate.SoundId="rbxassetid://140491345824898"
flightSoundTemplate.Volume=.18 flightSoundTemplate.Looped=true
flightSoundTemplate.RollOffMode=Enum.RollOffMode.InverseTapered
flightSoundTemplate.RollOffMinDistance=100 flightSoundTemplate.RollOffMaxDistance=2200
flightSoundTemplate.Parent=script
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({flightSoundTemplate}) end) end)
local NOSE_FIX = U.noseFix(Vector3.new(0, 0, 1)) -- AC-130 nose faces local +Z
local CRASH_G = require(ReplicatedStorage:WaitForChild("AircraftConfig")).CrashGravity or 40

local function collectProps(model)
	local pivot = model:GetPivot()
	local props = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:match("^Propeller%d+") then
			local s = d.Size
			local axis
			if s.X <= s.Y and s.X <= s.Z then
				axis = Vector3.xAxis
			elseif s.Y <= s.Z then
				axis = Vector3.yAxis
			else
				axis = Vector3.zAxis
			end
			table.insert(props, { Part = d, Rel = pivot:ToObjectSpace(d.CFrame), Axis = axis })
		end
	end
	return props
end

local function clearRings(st)
	for _, r in pairs(st.Rings) do
		r:Destroy()
	end
	st.Rings = {}
end

local function removePlane(userId)
	local st = planes[userId]
	if st then
		clearRings(st)
		if st.Model then
			st.Model:Destroy()
		end
		planes[userId] = nil
	end
end

CombatFX.OnClientEvent:Connect(function(kind, userId, a, b)
	if userId == player.UserId then
		if kind == "AC130Start" then
			setState("Active")
		elseif kind == "AC130Depart" then
			setState("Leaving")
		elseif kind == "AC130End" or kind == "AC130Down" then
			setState("Ready")
		end
	end
	if kind == "AC130Start" then
		removePlane(userId)
		local p = a
		local st = { Params = p, Rings = {}, Props = {} }
		if template then
			local m = U.makeVisual(template:Clone())
			m.Name = "AC130_" .. userId
			m.Parent = visuals
			st.Model = m
			st.Props = collectProps(m)
   local host,volume
   for _,part in m:GetDescendants() do if part:IsA("BasePart") then
    local size=part.Size local v=size.X*size.Y*size.Z
    if not volume or v>volume then host=part volume=v end
   end end
   if host then
    local pos,fwd,bank=Path.state(p,workspace:GetServerTimeNow())
    m:PivotTo(Path.cframe(pos,fwd,bank,NOSE_FIX))
    local sound=flightSoundTemplate:Clone() sound.Parent=host sound:Play()
   end
		end
		local ground = Vector3.new(p.Center.X, p.GroundY, p.Center.Z)
		-- while the AC-130 is out only the attack circle is shown (no orbit circle)
		st.Rings.Select = FX.ring(ground, Config.SelectRadius, Color3.fromRGB(255, 80, 60), 0.45, 0.5, 56)
		planes[userId] = st
	elseif kind == "AC130Ready" then
		local st = planes[userId]
		if st and st.Params.TDepart == nil and not st.Rings.Select then
			local p = st.Params
			local ground = Vector3.new(p.Center.X, p.GroundY, p.Center.Z)
			st.Rings.Select = FX.ring(ground, Config.SelectRadius, Color3.fromRGB(255, 80, 60), 0.45, 0.5, 56)
		end
	elseif kind == "AC130Plan" then
		local st = planes[userId]
		if not st or st.Params.TDepart then
			return
		end
		local y = st.Params.GroundY
		local function upd(name, aim, radius, color)
			if aim then
				local pos = Vector3.new(aim.X, y, aim.Y)
				if not st.Rings[name] then
					st.Rings[name] = FX.ring(pos, radius, color, 0.35, 0.35, 36)
				else
					FX.moveRing(st.Rings[name], pos)
				end
			elseif st.Rings[name] then
				st.Rings[name]:Destroy()
				st.Rings[name] = nil
			end
		end
		upd("Heavy", a, Config.Guns.Heavy.BlastRadius, Color3.fromRGB(255, 120, 30))
		upd("Secondary", b, Config.Guns.Secondary.BlastRadius, Color3.fromRGB(255, 220, 60))
	elseif kind == "AC130Depart" then
		local st = planes[userId]
		if st then
			st.Params.TDepart = a
			clearRings(st) -- all circles disappear immediately
		end
	elseif kind == "AC130End" then
		removePlane(userId)
	elseif kind == "AC130Down" then
		-- shot down: circles go, the wreck falls from where it was hit and explodes on the ground
		local st = planes[userId]
		if st then
			clearRings(st)
			st.Crash = { T = workspace:GetServerTimeNow(), From = a, Vel = b }
			FX.explosion(a, "Secondary")
		end
	end
end)

local function crashStep(userId, st, t)
	local c = st.Crash
	local e = t - c.T
	local pos = c.From + c.Vel * e + Vector3.new(0, -0.5 * CRASH_G * e * e, 0)
	local vel = c.Vel + Vector3.new(0, -CRASH_G * e, 0)
	local gy = U.groundY(pos.X, pos.Z, pos.Y + 5)
	if pos.Y <= gy + 2 or e > 15 then
		FX.explosion(Vector3.new(pos.X, gy, pos.Z), "Bomb")
		removePlane(userId)
		return nil
	end
	local fwd = vel.Magnitude > 1e-3 and vel.Unit or Vector3.new(0, -1, 0)
	return CFrame.lookAlong(pos, fwd) * CFrame.Angles(0, 0, math.rad(40) + e * 1.2) * NOSE_FIX
end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for userId, st in pairs(planes) do
		if st.Crash then
			local cf = crashStep(userId, st, t)
			if cf and st.Model then
				st.Model:PivotTo(cf)
			end
		elseif st.Model then
			local pos, fwd, bank = Path.state(st.Params, t)
			local cf = Path.cframe(pos, fwd, bank, NOSE_FIX)
			st.Model:PivotTo(cf)
			local angle = (t - st.Params.T0) * Config.PropellerSpeedRad
			for _, pr in ipairs(st.Props) do
				pr.Part.CFrame = cf * pr.Rel * CFrame.fromAxisAngle(pr.Axis, angle)
			end
		end
		if not st.Crash and Path.departDone(st.Params, t) then
			removePlane(userId)
		end
	end
end)
