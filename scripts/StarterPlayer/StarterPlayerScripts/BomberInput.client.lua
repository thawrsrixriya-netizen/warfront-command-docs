-- StarterPlayer.StarterPlayerScripts.BomberInput  (LocalScript)
-- BomberInput: called from the Skill Shop -> aim; one left click places the anchor circle (d=RectWidth);
-- mouse rotates the RectWidth x RectLength outline around the anchor; a second click confirms. Escape cancels.
-- The strike-area outline stays on the ground for every player until the last bomb lands.
-- Also renders every bomber pass (plane + 5 bombs + explosions) from the server broadcast.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage:WaitForChild("WarConfig")).Bomber
local Shared = ReplicatedStorage:WaitForChild("WarShared")
local Client = ReplicatedStorage:WaitForChild("WarClient")
local U = require(Shared:WaitForChild("WarUtil"))
local FX = require(Shared:WaitForChild("FX"))
local BomberPath=require(Shared:WaitForChild("BomberPath"))
local InputMode = require(Client:WaitForChild("InputMode"))
local Aim = require(Client:WaitForChild("Aim"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BomberCommand = Remotes:WaitForChild("BomberCommand")
local CombatFX = Remotes:WaitForChild("CombatFX")
local player = Players.LocalPlayer

local MODE = "BomberAim"
local aim -- { Model, Circle, Rect, Anchor, Dir, Conn }

local function clearAim()
	if aim then
		if aim.Conn then
			aim.Conn:Disconnect()
		end
		aim.Model:Destroy()
		aim = nil
	end
	player:SetAttribute("BombAimMode", false)
end

-- outlines only (no filled area): flat models whose pivot is their centre
local LINE_WIDTH = 0.6
local AIM_YELLOW, STRIKE_RED = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 90, 40) -- aim circle white; strike area keeps its colour
local function outlineModel(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.PrimaryPart = FX.part({ Name = "Pivot", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = CFrame.new() }, m)
	m.Parent = parent
	return m
end
local function edge(m, color, length, cf)
	FX.part({ Size = Vector3.new(LINE_WIDTH, 0.12, length), Color = color, Material = Enum.Material.Neon, Transparency = 0.1, CFrame = cf }, m)
end
local function ringOutline(diameter, color, parent)
	local m, r, n = outlineModel("AimRing", parent), diameter / 2, 48
	for i = 1, n do
		local a = (i - 0.5) / n * 2 * math.pi
		edge(m, color, 2 * math.pi * r / n * 1.08, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(0, -a, 0))
	end
	return m
end
local function rectOutline(width, length, color, parent)
	local m = outlineModel("StrikeArea", parent)
	edge(m, color, length + LINE_WIDTH, CFrame.new(-width / 2, 0, 0))
	edge(m, color, length + LINE_WIDTH, CFrame.new(width / 2, 0, 0))
	edge(m, color, width + LINE_WIDTH, CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, math.pi / 2, 0))
	edge(m, color, width + LINE_WIDTH, CFrame.new(0, 0, length / 2) * CFrame.Angles(0, math.pi / 2, 0))
	return m
end
local function rectCFrame(anchor, dir)
	return CFrame.lookAlong(anchor + dir * (C.RectLength / 2) + Vector3.new(0, 0.12, 0), dir)
end

local function updateAim()
	local hit = Aim.groundHit()
	if not aim or not hit then
		return
	end
	if not aim.Anchor then
		aim.Circle:PivotTo(CFrame.new(hit + Vector3.new(0, 0.1, 0)))
	else
		local d = U.flat(hit - aim.Anchor)
		if d then
			aim.Dir = d
		end
		aim.Rect = aim.Rect or rectOutline(C.RectWidth, C.RectLength, STRIKE_RED, aim.Model)
		aim.Rect:PivotTo(rectCFrame(aim.Anchor, aim.Dir))
	end
end

local function enterAim()
	if InputMode.get() == MODE then
		return
	end
	InputMode.enter(MODE, clearAim) -- leaves any other mode (tank control, FPV aim...) first
	player:SetAttribute("BombAimMode", true)
	local m = Instance.new("Model")
	m.Name = "BomberAimPreview"
	m.Parent = FX.folder()
	aim = { Model = m, Dir = U.flat(workspace.CurrentCamera.CFrame.LookVector) or Vector3.new(0, 0, -1) }
	aim.Circle = ringOutline(C.AimCircleDiameter, AIM_YELLOW, m)
	aim.Conn = RunService.RenderStepped:Connect(updateAim)
	updateAim()
end

-- Called from the Skill Shop (no hotkey). 1st click = target, mouse turns the run, 2nd click = launch.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if InputMode.isTyping() or InputMode.get() ~= MODE then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		InputMode.exit(MODE)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		InputMode.blockClicks(0.25)
		if aim and not aim.Anchor then
			local hit = Aim.groundHit() -- same ground hit as the cursor circle
			if hit then
				aim.Anchor = hit
				aim.AnchorTime = os.clock()
				aim.Circle:PivotTo(CFrame.new(hit + Vector3.new(0, 0.1, 0)))
				updateAim()
			end
		elseif aim and aim.Anchor and os.clock() - aim.AnchorTime > 0.2 then
			BomberCommand:FireServer("Launch", aim.Anchor, aim.Dir)
			InputMode.exit(MODE)
		end
	end
end)

require(Client:WaitForChild("SkillActions")).register("Bomber", {
	Mode = MODE,
	Call = enterAim,
	Hint = "Click to set the target, move the mouse to turn the run, click again to launch",
})

---------------------------------------------------------------- rendering a pass
local visualTemplate = ReplicatedStorage:WaitForChild("MapFlyoverVisual", 10)
local bombTemplate = ReplicatedStorage:FindFirstChild("MapFlyoverBomb")
local visuals = U.folder("BomberVisuals")
local flyTemplate=Instance.new("Sound")
flyTemplate.Name="SU34Flyby" flyTemplate.SoundId="rbxassetid://1452058524"
flyTemplate.Volume=.4 flyTemplate.RollOffMode=Enum.RollOffMode.Linear
flyTemplate.RollOffMinDistance=180 flyTemplate.RollOffMaxDistance=4500 flyTemplate.Looped=false flyTemplate.Parent=script
local blastTemplate=Instance.new("Sound")
blastTemplate.Name="SU34BombExplosion" blastTemplate.SoundId="rbxassetid://76578158277677"
blastTemplate.Volume=.6 blastTemplate.RollOffMode=Enum.RollOffMode.Linear
blastTemplate.RollOffMinDistance=200 blastTemplate.RollOffMaxDistance=3000 blastTemplate.Looped=false blastTemplate.Parent=script
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({flyTemplate,blastTemplate}) end) end)
local function bombAudio(position)
 local emitter=FX.part({Name="SU34BombAudio",Size=Vector3.new(.1,.1,.1),Transparency=1,CFrame=CFrame.new(position)})
 local sound=blastTemplate:Clone() sound.Parent=emitter sound:Play()
 sound.Ended:Once(function() if emitter.Parent then emitter:Destroy() end end)
 game:GetService("Debris"):AddItem(emitter,25)
end


local planeCenterOffset=Vector3.zero
if visualTemplate then local cf=visualTemplate:GetBoundingBox() planeCenterOffset=visualTemplate:GetPivot():PointToObjectSpace(cf.Position) end
local planeNoseFix = CFrame.new()
if visualTemplate then
	local pivot = visualTemplate:GetPivot()
	local canopy = visualTemplate:FindFirstChild("Canopy", true)
	local burner = visualTemplate:FindFirstChild("Burner", true)
	local function centreOf(inst)
		if inst:IsA("BasePart") then
			return inst.Position
		end
		local sum, n = Vector3.zero, 0
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				sum += d.Position
				n += 1
			end
		end
		return n > 0 and sum / n or nil
	end
	local a, b = canopy and centreOf(canopy), burner and centreOf(burner)
	if a and b then
		planeNoseFix = U.noseFix(pivot:PointToObjectSpace(a) - pivot:PointToObjectSpace(b))
	end
end

local function makeBomb()
	if bombTemplate then
		local b = bombTemplate:Clone()
		if b:IsA("BasePart") then
			b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery = true, false, false, false
		else
			U.makeVisual(b)
		end
		b.Parent = visuals
		return b
	end
	-- fallback until the real MapFlyoverBomb asset is added
	return FX.part({ Size = Vector3.new(0.986, 5.121, 1.095), Color = Color3.fromRGB(60, 66, 58), Material = Enum.Material.Metal }, visuals)
end

local function setCF(inst, cf)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	else
		inst:PivotTo(cf)
	end
end

-- bomb local Y is its length axis; the MapFlyoverBomb mesh has its nose (fuse) at +Y and fins at -Y,
-- so Angles(-90deg) maps +Y onto the direction of travel (nose leads, nose-down while falling)
local BOMB_NOSE = CFrame.Angles(-math.pi / 2, 0, 0)
local CRASH_G = require(ReplicatedStorage:WaitForChild("AircraftConfig")).CrashGravity or 40
local running = {} -- [pass.Id] = runtime state (DownT set when the plane is shot down)

CombatFX.OnClientEvent:Connect(function(kind, pass, extra)
	if kind == "BomberDown" then
		local r = running[pass]
		if r then
			r.DownT = extra
		end
		return
	end
	if kind ~= "Bomber" then
		return
	end
	local r = {}
	if pass.Id then
		running[pass.Id] = r
	end
	local dir, anchor = pass.Dir, pass.Anchor
 local flightSpeed=pass.FlightSpeed or C.FlightSpeed
 local startDistance=pass.StartDistance or C.StartDistance
 local fallDuration=pass.FallDuration or C.FallDuration
 local lifetime=pass.Lifetime or C.PlaneLifetime
	local startPos = Vector3.new(anchor.X, pass.Altitude, anchor.Z) - dir * startDistance
	local function planePos(t)
		return BomberPath.position(pass,t)
	end
	local plane
	if visualTemplate then
		plane = U.makeVisual(visualTemplate:Clone())
		plane.Name = "BomberPass"
		plane.Parent = visuals
	end
	local flySound,flyStarted
 if plane then
  local host,largest
  for _,part in plane:GetDescendants() do if part:IsA("BasePart") then
   local size=part.Size local volume=size.X*size.Y*size.Z
   if not largest or volume>largest then host=part largest=volume end
  end end
  if host then flySound=flyTemplate:Clone() flySound.Parent=host end
  plane:PivotTo(CFrame.lookAlong(planePos(0),dir)*planeNoseFix*CFrame.new(-planeCenterOffset))
 end
 local bombs = {}
	for i, impact in ipairs(pass.Impacts) do
		local release = pass.ReleaseTimes and pass.ReleaseTimes[i] or (C.FirstRelease + C.ReleaseInterval * (i - 1))
		bombs[i] = { Release = release, Fall = pass.FallDurations and pass.FallDurations[i] or fallDuration, Impact = impact, From = pass.ReleaseOrigins and pass.ReleaseOrigins[i] or nil, Part = nil, Done = false }
	end
	-- strike-area outline stays until the last bomb has landed
	local zone = rectOutline(C.RectWidth, C.RectLength, STRIKE_RED, visuals)
	zone:PivotTo(rectCFrame(anchor, dir))
	local landed = 0
	-- shot down: the wreck keeps its speed, falls and explodes where it hits the ground
	local function crashStep(t)
		if r.Crashed or not plane or not plane.Parent then
			return
		end
		if not r.CrashFrom then
			local p0, p1 = planePos(r.DownT), planePos(r.DownT + 0.05)
			r.CrashFrom, r.CrashVel = p0, (p1 - p0) / 0.05
			FX.explosion(p0, "Secondary")
		end
		local e = t - r.DownT
		local pos = r.CrashFrom + r.CrashVel * e + Vector3.new(0, -0.5 * CRASH_G * e * e, 0)
		local vel = r.CrashVel + Vector3.new(0, -CRASH_G * e, 0)
		local gy = U.groundY(pos.X, pos.Z, pos.Y + 5)
		if pos.Y <= gy + 1 or e > 10 then
			r.Crashed = true
			local ground = Vector3.new(pos.X, gy, pos.Z)
			FX.explosion(ground, "Bomb")
			bombAudio(ground)
			plane:Destroy()
			return
		end
		plane:PivotTo(CFrame.lookAlong(pos, vel.Unit) * CFrame.Angles(0, 0, e * 1.5) * planeNoseFix * CFrame.new(-planeCenterOffset))
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - pass.T0
  if flySound and not flyStarted then
   local duration=flySound.TimeLength>0 and flySound.TimeLength or 8
   local closest=BomberPath.releaseTime(pass,C.RectLength*.5)+fallDuration
   if t>=math.max(0,closest-duration*.5) then flyStarted=true flySound:Play() end
  end
		if plane then
			if r.DownT and t >= r.DownT then
				crashStep(t)
			elseif t <= lifetime then
				plane:PivotTo(CFrame.lookAlong(planePos(math.max(t, 0)), dir) * planeNoseFix*CFrame.new(-planeCenterOffset))
			elseif plane.Parent then
				plane:Destroy()
			end
		end
		local allDone = t > lifetime
		for _, b in ipairs(bombs) do
			if not b.Done then
				allDone = false
				if r.DownT and b.Release > r.DownT and not b.Part then
					b.Done = true -- never released: the plane was shot down first
					landed += 1
					if landed >= #bombs and zone.Parent then
						zone:Destroy()
					end
				elseif t >= b.Release then
					if not b.Part then
						b.From = b.From or (planePos(b.Release) - Vector3.new(0, C.BombReleaseDrop, 0))
						b.Part = makeBomb()
					end
					local u = math.clamp((t - b.Release) / b.Fall, 0, 1)
					local from, to = b.From, b.Impact
					local horiz = Vector3.new(from.X + (to.X - from.X) * u, 0, from.Z + (to.Z - from.Z) * u)
					local y = from.Y + (to.Y - from.Y) * u * u
					local vel = Vector3.new(to.X - from.X, 2 * u * (to.Y - from.Y), to.Z - from.Z)
					local pos = Vector3.new(horiz.X, y, horiz.Z)
					if vel.Magnitude > 1e-3 then
						setCF(b.Part, CFrame.lookAlong(pos, vel.Unit) * BOMB_NOSE)
					end
					if u >= 1 then
						b.Done = true
						b.Part:Destroy()
						FX.explosion(to, "Bomb")
						landed += 1
						if landed >= #bombs and zone.Parent then
							zone:Destroy()
						end
      bombAudio(to)
					end
				end
			end
		end
		if allDone then
			conn:Disconnect()
			if pass.Id then
				running[pass.Id] = nil
			end
			if zone.Parent then
				zone:Destroy()
			end
			if plane and plane.Parent then
				plane:Destroy()
			end
		end
	end)
end)
