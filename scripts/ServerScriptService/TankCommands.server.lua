-- ServerScriptService.TankCommands  (Script)
-- TankCommands: server authority for command tanks (max 3 per player).
-- Spawn / Move / Fire with ownership checks; smooth hull motion (turn-in-place for large
-- heading changes, steering for small ones, braking redirect + 1.5 s pause), suspension pitch,
-- road following, explicit tree collision, turret yaw about the true turret centre,
-- 3x3 visual burst fire (no damage yet), random Hull/World turret hold after each sequence.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local C = require(ReplicatedStorage:WaitForChild("WarConfig")).Tank
local U = require(ReplicatedStorage.WarShared.WarUtil)
local Roads = require(ServerScriptService.WarServer.TankRoadNavigation)
local Trees = require(ServerScriptService.WarServer.TankTreeImpact)
local Damage = require(ServerScriptService.WarServer.Damage)
local BMPVision = require(ServerScriptService.WarServer.BMPVision)
local TrenchSupport = require(ServerScriptService.WarServer.TankTrenchSupport)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TankCommand = Remotes.TankCommand
local CombatFX = Remotes.CombatFX

local TEMPLATE_NAME = "CommandTankTemplate"
local tanksFolder = U.folder("CommandTanks")
local tanks = {} -- [Model] = state
local geo -- template geometry (computed once)

---------------------------------------------------------------- template
local function findPart(model, name)
	local x = model:FindFirstChild(name, true)
	return x
end

local function prepareTemplate(template)
	local hull = template:FindFirstChild("Hull")
	local turret = template:FindFirstChild("Turret")
	local muzzle = turret and findPart(turret, "CommandMuzzle")
	if not (hull and turret and muzzle) then
		warn("[TankCommands] CommandTankTemplate needs Hull, Turret and Turret.CommandMuzzle")
		return nil
	end
	local pivot = template:GetPivot()
	local bbCF, bbSize = template:GetBoundingBox()
	local bottomY = bbCF.Position.Y - bbSize.Y / 2
	-- true turret centre = the turret part with the largest footprint (the ring/body),
	-- NOT the bounding-box centre (the barrel drags that forward)
	local ring, ringArea = nil, 0
	for _, d in ipairs(turret:GetDescendants()) do
		if d:IsA("BasePart") and d.Size.X * d.Size.Z > ringArea then
			ring, ringArea = d, d.Size.X * d.Size.Z
		end
	end
	local axis = pivot:PointToObjectSpace(ring and ring.Position or (turret:GetBoundingBox()).Position)
	local muzzleCF = muzzle:IsA("Attachment") and muzzle.WorldCFrame or muzzle.CFrame
	local gun = turret:FindFirstChild("Gun")
 assert(gun and gun:IsA("Model"), "Tank turret needs a separate Gun Model")
 local barrel
 for _,p in ipairs(gun:GetDescendants()) do
  if p:IsA("BasePart") and (not barrel or p.Size.Z > barrel.Size.Z) then barrel=p end
 end
 assert(barrel, "Gun barrel missing")
 local muzzlePos = muzzleCF.Position
 local forward = (muzzlePos-barrel.Position).Unit
 local breech = muzzlePos-forward*barrel.Size.Z
 local mount = CFrame.lookAlong(breech,forward)
 local sizeLocal = template:GetExtentsSize()
	local g = {
		Template = template,
		HullRel = pivot:ToObjectSpace(hull:GetPivot()),
		TurretRel = pivot:ToObjectSpace(turret:GetPivot()),
		Axis = Vector3.new(axis.X, 0, axis.Z),
		GroundOffset = pivot.Position.Y - bottomY,
		Width = sizeLocal.X,
		Length = sizeLocal.Z,
		HullCenterRel = pivot:PointToObjectSpace((hull:GetBoundingBox()).Position),
		MuzzleRel = turret:GetPivot():ToObjectSpace(muzzleCF),
		GunMountRel = turret:GetPivot():ToObjectSpace(mount),
		GunPivotRel = mount:ToObjectSpace(gun:GetPivot()),
		GunMuzzleRel = mount:ToObjectSpace(muzzleCF),
	}
	-- client-side placement icon / footprint
	local old = ReplicatedStorage:FindFirstChild("TankPlacementVisual")
	if old then
		old:Destroy()
	end
	local vis = U.makeVisual(template:Clone())
	vis.Name = "TankPlacementVisual"
	vis:SetAttribute("Width", g.Width)
	vis:SetAttribute("Length", g.Length)
	vis.Parent = ReplicatedStorage
	return g
end

local function loadTemplate()
	local t = ServerStorage:FindFirstChild(TEMPLATE_NAME)
	if t and (not geo or geo.Template ~= t) then
		geo = prepareTemplate(t)
	end
end
loadTemplate()
ServerStorage.ChildAdded:Connect(function(c)
	if c.Name == TEMPLATE_NAME then
		task.defer(loadTemplate)
	end
end)

---------------------------------------------------------------- helpers
local function ownedTanks(player)
	local list = {}
	for model, st in pairs(tanks) do
		if st.Owner == player then
			list[st.Slot] = model
		end
	end
	return list
end

local function message(player, text)
	TankCommand:FireClient(player, "Message", text)
end

local groundParamsCache, groundParamsAt = nil, 0
local function groundParams()
	if not groundParamsCache or os.clock() - groundParamsAt > 1 then
		groundParamsCache = U.groundParams()
		groundParamsAt = os.clock()
	end
	return groundParamsCache
end

local function groundAt(pos)
	return U.groundY(pos.X, pos.Z, pos.Y + 12, groundParams())
end

local function headingErr(st, target)
	local d = U.flat(target - st.Pos)
	if not d then
		return 0
	end
	return U.wrapAngle(U.yawOf(d) - st.Yaw)
end

---------------------------------------------------------------- render
-- The server only computes the pose. Every client renders the parts itself (TankRender) from
-- 4 replicated attributes, so 39+ part CFrames are not replicated every frame (that caused lag).
local PUBLISH_INTERVAL = 0.05
local function render(st, force)
	local base = CFrame.new(st.Pos) * CFrame.Angles(0, st.Yaw, 0)
	-- suspension pitch about the ground point under the hull centre
	local pc = Vector3.new(geo.HullCenterRel.X, -geo.GroundOffset, geo.HullCenterRel.Z)
	local visual = base * CFrame.new(pc) * CFrame.Angles(math.rad(st.Pitch), 0, 0) * CFrame.new(-pc)
	local turretCF = visual * CFrame.new(geo.Axis) * CFrame.Angles(0, st.TurretYaw, 0) * CFrame.new(-geo.Axis) * geo.TurretRel
	st.TurretCF = turretCF
	local gunFrame = turretCF * geo.GunMountRel * CFrame.Angles(st.GunPitch or 0, 0, 0)
	st.GunMuzzleCF = gunFrame * geo.GunMuzzleRel
	if force then
		st.Hull:PivotTo(visual * geo.HullRel)
		st.Turret:PivotTo(turretCF)
		st.Turret.Gun:PivotTo(gunFrame * geo.GunPivotRel)
	end
	local now = os.clock()
	local key = string.format("%.3f,%.3f,%.3f,%.4f,%.3f,%.4f,%.4f", st.Pos.X, st.Pos.Y, st.Pos.Z, st.Yaw, st.Pitch, st.TurretYaw, st.GunPitch or 0)
	if force or (now - (st.LastPublish or 0) >= PUBLISH_INTERVAL and key ~= st.LastKey) then
		st.LastPublish = now
		st.LastKey = key
		local m = st.Model
		m:SetAttribute("TankPos", st.Pos)
		m:SetAttribute("TankYaw", st.Yaw)
		m:SetAttribute("TankPitch", st.Pitch)
		m:SetAttribute("TurretYaw", st.TurretYaw)
		m:SetAttribute("GunPitch", st.GunPitch or 0)
		m:SetAttribute("TankT", workspace:GetServerTimeNow()) -- set last: marks a complete snapshot
		m.WorldPivot = base -- keep the tank's own pivot with the tank (GetPivot users)
	end
end

---------------------------------------------------------------- firing
local function muzzlePosition(st)
	return st.GunMuzzleCF.Position
end

local function hullCentre(st)
	return (CFrame.new(st.Pos) * CFrame.Angles(0, st.Yaw, 0)) * geo.HullCenterRel
end

-- the fixed target point may leave the allowed band while the hull moves: hold fire until it is back
local function targetInRange(st)
	local c = hullCentre(st)
	local d = Vector3.new(st.FireTarget.X - c.X, 0, st.FireTarget.Z - c.Z).Magnitude
	return d >= (st.AutoFiring and 0 or C.MinRange) and d <= C.AimRectLength
end

local function shoot(st)
	local from = muzzlePosition(st)
	local target = st.FireTarget
	if st.AutoFiring and (not BMPVision.allowed(st) or not BMPVision.clearShot(st, from, target)) then return false end
	CombatFX:FireAllClients("TankShot", from, target, st.Model)
	local travel = (target - from).Magnitude / C.ShellSpeed
	local perRound = C.ShotDamage
	task.delay(travel, function()
		Damage.radial(target, C.ShellRadius, { Amount = perRound, Mode = "XZ", Source = "Tank", Player = st.Owner })
		local ok, err = pcall(function() require(game.ServerScriptService.WarServer.BMPCraters).create(target) end)
		if not ok then warn("[BMP crater]", err) end
	end)
	return true
end

local function setHold(st)
	st.HoldMode = math.random() < 0.5 and "Hull" or "World"
	st.HoldWorldYaw = U.wrapAngle(st.Yaw + st.TurretYaw)
	st.Model:SetAttribute("TurretHoldMode", st.HoldMode)
end

-- Fire: one round, FireInterval cooldown, next round, at the SAME target until a new Fire order
-- or Stop. After OverheatShots rounds the gun must cool for OverheatTime. Heat and the cooldown
-- belong to the tank (a new Fire order cannot skip them); an idle gun cools fully after
-- OverheatTime without firing.
local function clearOverheat(st)
	st.OverheatUntil = nil
	st.Heat = 0
	st.Model:SetAttribute("Overheated", false)
	st.Model:SetAttribute("OverheatEndsAt", nil)
	st.Model:SetAttribute("Heat", 0)
end

local function fireSequence(st, target)
	st.FireSeq += 1
	local seq = st.FireSeq
	st.Firing = true
	st.FireTarget = target
	st.Model:SetAttribute("FireActive", true)
	local function alive()
		return st.Model.Parent ~= nil and seq == st.FireSeq
	end
	while alive() do
		if st.OverheatUntil then
			if os.clock() < st.OverheatUntil then
				task.wait()
				continue
			end
			clearOverheat(st)
		end
		local ready = (st.LastShot or -math.huge) + C.FireInterval
		if os.clock() < ready or not (st.Aligned and targetInRange(st)) then
			task.wait()
			continue
		end
		if os.clock() - (st.LastShot or -math.huge) >= C.OverheatTime then
			st.Heat = 0 -- the gun cooled down while idle
		end
		if shoot(st) == false then task.wait(0.1); continue end
		st.LastShot = os.clock()
		st.Model:SetAttribute("LastShotAt", workspace:GetServerTimeNow())
		st.Heat = (st.Heat or 0) + 1
		st.Model:SetAttribute("Heat", st.Heat)
		if st.Heat >= C.OverheatShots then
			st.OverheatUntil = os.clock() + C.OverheatTime
			st.Model:SetAttribute("OverheatEndsAt", workspace:GetServerTimeNow() + C.OverheatTime)
			st.Model:SetAttribute("Overheated", true)
		end
	end
end

local function stopFire(st)
	st.FireSeq += 1 -- ends any running sequence
	if st.Firing then
		st.Firing = false
		st.FireTarget = nil
		setHold(st)
	end
	st.Model:SetAttribute("FireActive", false)
end

---------------------------------------------------------------- per-frame motion
-- Recovery preserves the route: reverse clear of contact, retry, then drive around.
local CollectionService=game:GetService("CollectionService")
local VEGETATION_TAG="TankPassThroughVegetation"
local function markVegetation(v)
 if not (v:IsA("Model") or v:IsA("BasePart")) then return end
 local n=v.Name:lower()
 if n:find("crate",1,true) then return end
 if n:find("grass",1,true) or n:find("bush",1,true) or n:find("shrub",1,true) or n:find("หญ้า",1,true) then
  CollectionService:AddTag(v,VEGETATION_TAG)
 end
end
for _,v in ipairs(workspace:GetDescendants()) do markVegetation(v) end
workspace.DescendantAdded:Connect(markVegetation)

-- OBB/SAT collision uses authoritative vehicle poses, not client-rendered mesh locations.
local function penetration(pos,yaw,otherPos,otherYaw)
 local f,r=U.dirOf(yaw),Vector3.new(math.cos(yaw),0,-math.sin(yaw))
 local of,orr=U.dirOf(otherYaw),Vector3.new(math.cos(otherYaw),0,-math.sin(otherYaw))
 local delta=otherPos-pos
 local depth=math.huge
 for _,axis in ipairs({f,r,of,orr}) do
  local radius=math.abs(axis:Dot(f))*geo.Length/2+math.abs(axis:Dot(r))*geo.Width/2
  radius+=math.abs(axis:Dot(of))*geo.Length/2+math.abs(axis:Dot(orr))*geo.Width/2+0.2
  local overlap=radius-math.abs(delta:Dot(axis))
  if overlap<=0 then return 0 end
  depth=math.min(depth,overlap)
 end
 return depth
end
local function vehicleAt(st,nextPos)
 for model,other in pairs(tanks) do
  if model~=st.Model and model.Parent and math.abs(nextPos.Y-other.Pos.Y)<3 then
   local newDepth=penetration(nextPos,st.Yaw,other.Pos,other.Yaw)
   if newDepth>0 then
    local oldDepth=penetration(st.Pos,st.CollisionStartYaw or st.Yaw,other.Pos,other.Yaw)
    -- Allow vehicles spawned overlapping to drive apart, but never drive deeper inside.
    if oldDepth<=0 or newDepth>=oldDepth-1e-5 then return model end
   end
  end
 end
end

local obstacleParams, obstacleParamsAt
local function obstacleAt(st, nextPos, heading)
 if not obstacleParams or os.clock()-(obstacleParamsAt or 0)>0.5 then
  obstacleParams=U.groundParams()
  obstacleParams.RespectCanCollide=true
  obstacleParamsAt=os.clock()
 end
 local centre=st.Pos+Vector3.new(0,0.2,0)
 local hit=workspace:Blockcast(CFrame.lookAlong(centre,heading),
  Vector3.new(geo.Width*0.85,1.3,geo.Length*0.85),nextPos-st.Pos,obstacleParams)
 return hit and hit.Instance
end
local ForestNavigation=require(ServerScriptService.WarServer.TankForestNavigation)
local function sidesBlocked(st)
 local heading=U.dirOf(st.Yaw)
 local right=Vector3.new(math.cos(st.Yaw),0,-math.sin(st.Yaw))
 local function blocked(sign)
  local p=st.Pos+right*(geo.Width*.5*sign)
  if vehicleAt(st,p) or obstacleAt(st,p,heading) then return true end
  for _,tree in ipairs(game:GetService("CollectionService"):GetTagged("TankReactiveTree")) do
   if tree:IsDescendantOf(workspace) and not tree:GetAttribute("TreeFallen") then
    local trunk=tree:FindFirstChild("TankTrunk1",true)
    if trunk then
     local d=trunk.WorldPosition-p
     local radius=trunk:GetAttribute("TreeCollisionRadius") or 1
     local x=math.max(math.abs(d:Dot(right))-geo.Width*.5,0)
     local z=math.max(math.abs(d:Dot(heading))-geo.Length*.5,0)
     if x*x+z*z<radius*radius then return true end
    end
   end
  end
  return false
 end
 return blocked(-1) and blocked(1)
end

local function detour(st,recovery)
 if not st.Path or st.PlanningRoute then return end
 local resume=table.clone(st.DetourResumePath or st.Path)
 while #resume>1 and (Vector3.new(resume[1].X,0,resume[1].Z)-Vector3.new(st.Pos.X,0,st.Pos.Z)).Magnitude<1 do table.remove(resume,1) end
 local goal=resume[1]
 if not goal then return end
 st.DetourResumePath=table.clone(resume)
 st.PlanVersion=(st.PlanVersion or 0)+1
 local version=st.PlanVersion
 st.PlanningRoute=true
 st.V=0
 st.Model:SetAttribute("RecoveryState","Planning")
 local start=st.Pos
 local startYaw=st.Yaw
 local vehicles={}
 for model,other in pairs(tanks) do if model~=st.Model and model.Parent then table.insert(vehicles,other.Pos) end end
 task.spawn(function()
  local ok,path,reason=pcall(ForestNavigation.plan,start,goal,geo.Width,geo.Length,vehicles,startYaw)
  if st.PlanVersion~=version or not st.Model.Parent then return end
  st.PlanningRoute=false
  if not ok or not path then
   -- Keep the original destination and back out farther if no rolling turn fits.
   st.ReverseEscapeAttempts=(st.ReverseEscapeAttempts or 0)+1
   if not recovery.RearBlocked and st.ReverseEscapeAttempts<=6 then
    st.Path=table.clone(resume) st.ForestArcs=nil st.ForestAvoidMode=true
    st.Recovery={Start=st.Pos,Started=os.clock(),Heading=U.dirOf(st.Yaw),Obstacle=recovery.Obstacle,
     Avoid=true,EscapeSign=-1,InitialYaw=st.Yaw,EscapeYaw=recovery.EscapeYaw or st.CommandStartYaw or st.Yaw}
    st.Model:SetAttribute("RecoveryState","Reversing")
    return
   end
   st.Path=nil
   st.V=0
   st.Model:SetAttribute("RecoveryState","Blocked")
   message(st.Owner,"No clear route through these trees. Choose a wider opening.")
   if not ok then warn("[TankForestNavigation]",path) end
   return
  end
  st.ReverseEscapeAttempts=0
  st.ForestArcs=path
  st.ForestAvoidMode=true
  st.Path=table.clone(resume)
  st.DetourWaypointCount=1
  st.RouteReverse=nil
  st.Model:SetAttribute("RecoveryState","ForestDetour")
 end)
end
local function recover(st, obstacle, isTree, travelSign)
 if st.LastObstacle==obstacle then st.RecoveryAttempts=(st.RecoveryAttempts or 0)+1
 else
  st.LastObstacle=obstacle
  st.RecoveryAttempts=1
  -- Roll once per encountered obstacle, not again on every contact/frame.
  st.TreeRetryMode=isTree and math.random(1,3) or nil
  -- 1: one impact then detour; 2: two impacts then detour; 3: keep retrying until fallen.
  st.TreeRetryLimit=st.TreeRetryMode and (st.TreeRetryMode==3 and math.huge or st.TreeRetryMode) or nil
  st.Model:SetAttribute("TreeRetryMode",st.TreeRetryMode)
  st.Model:SetAttribute("TreeRetryLimit",st.TreeRetryMode and (st.TreeRetryMode==3 and -1 or st.TreeRetryMode) or nil)
 end
 if isTree then
  st.TreeChoices=st.TreeChoices or {}
  local choice=st.TreeChoices[obstacle]
  if not choice then
   choice={Mode=st.TreeRetryMode,Attempts=0}
   st.TreeChoices[obstacle]=choice
  end
  choice.Attempts+=1
  st.TreeRetryMode=choice.Mode
  st.TreeRetryLimit=choice.Mode==3 and math.huge or choice.Mode
  st.RecoveryAttempts=choice.Attempts
  st.Model:SetAttribute("TreeRetryMode",choice.Mode)
 end
 st.RecoveryTotal=(st.RecoveryTotal or 0)+1
 if st.RecoveryAttempts>6 or st.RecoveryTotal>12 then
  st.V=0; st.Path=nil; st.Recovery=nil
  st.Model:SetAttribute("RecoveryState","Blocked")
  message(st.Owner,"Tank cannot find a clear route; choose a new destination")
  return
 end
 st.Recovery={Start=st.Pos,Started=os.clock(),Heading=U.dirOf(st.Yaw),Obstacle=obstacle,
  Avoid=st.RecoveryAttempts >= (isTree and (st.TreeRetryLimit or 1) or 2),
  EscapeSign=-(travelSign or 1), InitialYaw=st.Yaw,
  EscapeYaw=sidesBlocked(st) and (st.CommandStartYaw or st.Yaw) or st.Yaw}
 st.V=0
 if st.ForestAvoidMode then st.Recovery.Avoid=true end
 st.Model:SetAttribute("RecoveryState","Reversing")
end

local function stepTank(st, dt)
	local turnRate = math.rad(C.MaxTurnSpeed)
	local vBefore = st.V
	if st.OverheatUntil and os.clock() >= st.OverheatUntil then
		clearOverheat(st) -- cooled down even if not firing
	end
	local braking = false

 local initialYaw = st.Yaw
 st.CollisionStartYaw=initialYaw
 local initialPos = st.Pos
 if st.Path and st.Path[1] and not st.Recovery and not st.PlanningRoute and not st.ForestArcs and not st.Model:GetAttribute("Unloading") then
  local wp=st.Path[1] local d=Vector3.new(wp.X-st.Pos.X,0,wp.Z-st.Pos.Z).Magnitude
  if not st.ProgressWaypoint or (st.ProgressWaypoint-wp).Magnitude>.45 then
   st.ProgressWaypoint=wp st.ProgressBest=d st.ProgressAt=os.clock()
  elseif d<(st.ProgressBest or math.huge)-.45 then
   st.ProgressBest=d st.ProgressAt=os.clock()
  elseif os.clock()-(st.ProgressAt or os.clock())>3.5 then
   st.ProgressAt=os.clock() st.NavStallAttempts=(st.NavStallAttempts or 0)+1
   if st.NavStallAttempts<=6 then detour(st,{Obstacle=st.LastObstacle,Avoid=true,EscapeYaw=st.CommandStartYaw or st.Yaw})
   else st.Path=nil st.V=0 st.Model:SetAttribute("RecoveryState","Blocked") end
  end
 end

 -- Every heading change is a rolling arc; there is no stationary pivot or redirect pause.
 st.Phase = "drive"
 st.TurningInPlace = false
 if st.PendingPath then
  st.Path, st.OnRoad = st.PendingPath, st.PendingOnRoad
  st.PendingPath = nil
 end
 if not st.Model:GetAttribute("Unloading") then
  st.Model:SetAttribute("DisembarkStopped",false)
  if st.UnloadResumePath then st.Path=st.UnloadResumePath st.OnRoad=st.UnloadResumeOnRoad st.UnloadResumePath=nil end
 end
 local motionSign=1
 local activeArc
 if st.Model:GetAttribute("Unloading") and not st.Model:GetAttribute("ParkingForUnload") then
  -- Brake with the existing deceleration and suspension, preserving the current gear.
  motionSign=st.Recovery and (st.Recovery.EscapeSign or -1) or st.DriveSign or 1
  st.V=math.max(0,st.V-C.BrakeDecel*dt)
  braking=vBefore>.01
  if st.V<.01 then st.V=0 end
  st.Model:SetAttribute("DisembarkStopped",st.V==0)
 elseif st.PlanningRoute then
  st.Model:SetAttribute("DisembarkStopped",false)
  st.V=0
 elseif st.Recovery then
  local recovery=st.Recovery
  local backed=(st.Pos-recovery.Start).Magnitude
  if backed>=8 or os.clock()-recovery.Started>3.5 then
   st.Recovery=nil
   st.V=0
   if recovery.Avoid then detour(st,recovery)
   else st.Model:SetAttribute("RecoveryState","Retry") end
  else
   motionSign=recovery.EscapeSign or -1
   st.V=math.min(4,st.V+C.Accel*dt)
   -- Recover the corridor heading while rolling backwards rather than backing diagonally into its walls.
   local desiredYaw=backed<C.CollisionStep and st.Yaw or recovery.EscapeYaw or st.Yaw
   local error=U.wrapAngle(desiredYaw-st.Yaw)
   local rate=math.rad(C.RollingTurnSpeed)*math.clamp(st.V/.5,0,1)
   st.Yaw=U.wrapAngle(st.Yaw+math.clamp(error,-rate*dt,rate*dt))

  end
 elseif st.ForestArcs and #st.ForestArcs>0 then
  activeArc=st.ForestArcs[1]
  activeArc.Remaining=activeArc.Remaining or activeArc.Length
  motionSign=activeArc.Gear
  st.DriveSign=motionSign
  local stopDistance=activeArc.Remaining
  for n=2,#st.ForestArcs do
   if st.ForestArcs[n].Gear~=motionSign then break end
   stopDistance+=st.ForestArcs[n].Length
  end
  local targetSpeed=math.min(motionSign<0 and 3.5 or 7, math.sqrt(2*C.BrakeDecel*math.max(stopDistance,0.02)))
  if st.V<targetSpeed then st.V=math.min(targetSpeed,st.V+C.Accel*dt)
  else st.V=math.max(targetSpeed,st.V-C.BrakeDecel*dt) end
  st.Model:SetAttribute("ForestGear",motionSign)
 elseif st.Path and #st.Path > 0 then
  local wp = st.Path[1]
  local delta = Vector3.new(wp.X-st.Pos.X,0,wp.Z-st.Pos.Z)
  local dist = delta.Magnitude
  local arrivalRadius=(st.DetourWaypointCount and #st.Path>1) and 1.4 or 0.45
  if dist <= arrivalRadius then
   table.remove(st.Path,1)
   st.RouteReverse=nil
   if st.DetourWaypointCount then
    st.DetourWaypointCount-=1
    if st.DetourWaypointCount<=0 then
     st.DetourWaypointCount=nil
     st.DetourResumePath=nil
     st.Model:SetAttribute("RecoveryState",nil)
    end
   end
   if #st.Path == 0 then
    st.Path=nil; st.V=0
    if st.Model:GetAttribute("ParkingForUnload") then st.Model:SetAttribute("ParkingForUnload",false) end
    st.RecoveryAttempts=0; st.LastObstacle=nil
    st.Model:SetAttribute("RecoveryState",nil)
   end
  else
   local err = headingErr(st,wp)
   -- A nearby waypoint behind the hull is a reversing correction, not a full driving circle.
   if st.RouteReverse==nil or (not st.RouteReverse and dist<14 and math.abs(err)>math.rad(105)) then
    st.RouteReverse=dist<=18 and math.abs(err)>math.rad(105)
   end
   local desiredSign=st.RouteReverse and -1 or 1
   st.DriveSign=st.DriveSign or 1
   local changingDirection=desiredSign~=st.DriveSign and st.V>0.1
   if not changingDirection then st.DriveSign=desiredSign end
   motionSign=st.DriveSign
   if motionSign<0 then err=U.wrapAngle(err+math.pi) end
   local angle = math.abs(err)
   local boxed=motionSign>0 and angle>math.rad(8) and sidesBlocked(st)
   local rate = math.rad(C.RollingTurnSpeed)
   local remaining = dist
   for n=1,#st.Path-1 do
    remaining += (Vector3.new(st.Path[n+1].X,0,st.Path[n+1].Z)-Vector3.new(st.Path[n].X,0,st.Path[n].Z)).Magnitude
   end
   local desired = math.min(C.MaxSpeed,math.sqrt(2*C.Accel*math.max(remaining-0.15,0)))
   desired *= math.clamp(1-angle/math.pi,0.25,1)
   if motionSign<0 then desired=math.min(desired,5.5) end
   if changingDirection or boxed then desired=0 end
   if angle > math.rad(8) then
    local fitRadius=dist/(2*math.max(math.sin(math.min(angle,math.pi/2)),0.1))
    desired=math.min(desired,math.max(0.12,fitRadius*rate*0.9))
   end
   if st.V < desired then st.V=math.min(desired,st.V+C.Accel*dt)
   else st.V=math.max(desired,st.V-C.BrakeDecel*dt) end
   -- Steering is tied to forward speed, including a U-turn toward a rear destination.
   local steerRate=rate*math.clamp(angle/math.rad(15),0.2,1)*math.clamp(st.V/0.5,0,1)
   if not changingDirection and not boxed then st.Yaw=U.wrapAngle(st.Yaw+math.clamp(err,-steerRate*dt,steerRate*dt)) end
   if boxed and st.V<=.1 then
    recover(st,nil,false,1)
    if st.Recovery then st.Recovery.Avoid=true st.Recovery.EscapeYaw=st.Yaw end
   end
  end
 else
  st.V=math.max(0,st.V-C.Accel*dt)
 end

	-- translate with swept tree collision (sub-steps <= CollisionStep)
	local heading = U.dirOf(st.Yaw)
	local distance = st.V * dt
 if activeArc then distance=math.min(distance,activeArc.Remaining) end
	if distance > 0 then
		local steps = math.max(1, math.ceil(distance / C.CollisionStep))
		local stepLen = distance / steps
		for _ = 1, steps do
			local previousYaw=st.Yaw
   local arcDelta=activeArc and activeArc.Curve*stepLen*motionSign or 0
   local stepHeading=U.dirOf(st.Yaw+arcDelta/2)
   local nextYaw=U.wrapAngle(st.Yaw+arcDelta)
   local nextPos = st.Pos + stepHeading * (stepLen * motionSign)
   heading=U.dirOf(nextYaw)
   st.Yaw=nextYaw
			local treeBlocked,treeObstacle=Trees.check(st.Model,nextPos,heading,geo.Width,geo.Length,motionSign>0)
   local vehicleObstacle=vehicleAt(st,nextPos)
   local solidObstacle=vehicleObstacle or obstacleAt(st,nextPos,heading)
   if treeBlocked or solidObstacle then
    st.Yaw=previousYaw
    st.ForestArcs=nil
    st.V=0
    if st.Recovery then
     local recovery=st.Recovery
     st.Recovery=nil
     recovery.Avoid=true
     recovery.RearBlocked=motionSign<0
     detour(st,recovery)
    else
     recover(st,treeObstacle or solidObstacle,treeBlocked,motionSign)
    end
    break
   end
			st.Pos = nextPos
   if activeArc then activeArc.Remaining=math.max(0,activeArc.Remaining-stepLen) end
		end
		local gy = groundAt(st.Pos)
		gy = TrenchSupport.height(st.Pos,st.Yaw,geo,groundParams(),gy)
		st.Pos = Vector3.new(st.Pos.X, gy + geo.GroundOffset, st.Pos.Z)
	end

	if activeArc and st.ForestArcs and activeArc.Remaining<0.001 then
  table.remove(st.ForestArcs,1)
  local nextArc=st.ForestArcs[1]
  if not nextArc or nextArc.Gear~=activeArc.Gear then st.V=0 end
  if not nextArc then st.ForestArcs=nil; st.Model:SetAttribute("ForestGear",nil) end
 end
 if (st.Pos-initialPos).Magnitude < 1e-6 then st.Yaw=initialYaw end

	-- suspension pitch (visual only): nose up when accelerating, down when braking
	local accel = (st.V - vBefore) / math.max(dt, 1e-3)
	local target = 0
	if braking then
		target = -C.PitchBrake
	elseif accel > 0.5 then
		target = C.PitchNormal
	elseif accel < -0.5 then
		target = -C.PitchNormal
	end
	local k, c = 45, 7
	st.PitchVel += ((target - st.Pitch) * k - st.PitchVel * c) * dt
	st.Pitch += st.PitchVel * dt

	-- turret
	if st.Firing and st.FireTarget then
		local axisWorld = (CFrame.new(st.Pos) * CFrame.Angles(0, st.Yaw, 0)) * geo.Axis
		local d = U.flat(st.FireTarget - axisWorld)
		if d then
			local desiredRel = U.wrapAngle(U.yawOf(d) - st.Yaw)
			local e = U.wrapAngle(desiredRel - st.TurretYaw)
			local rate = math.rad(C.TurretSpeed) * math.clamp(math.abs(e) / math.rad(10), 0.2, 1)
			st.TurretYaw = U.wrapAngle(st.TurretYaw + math.clamp(e, -rate * dt, rate * dt))
			st.Aligned = math.abs(U.wrapAngle(desiredRel - st.TurretYaw)) <= math.rad(C.TurretTolerance)
		end
	elseif st.HoldMode == "World" then
		st.TurretYaw = U.wrapAngle(st.HoldWorldYaw - st.Yaw)
	end
 -- Aim elevation in the turret's local mounting frame, compensating hull pitch.
 if st.Firing and st.FireTarget and st.TurretCF then
  local mount = st.TurretCF * geo.GunMountRel
  local target = mount:PointToObjectSpace(st.FireTarget)
  local elevation = math.atan2(target.Y, math.sqrt(target.X*target.X+target.Z*target.Z))
  local desired = math.clamp(elevation, math.rad(C.GunMinElevation), math.rad(C.GunMaxElevation))
  local pitch = st.GunPitch or 0
  local step = math.rad(C.GunElevationSpeed)*dt
  st.GunPitch = pitch + math.clamp(desired-pitch,-step,step)
  st.Aligned = st.Aligned and math.abs(elevation-st.GunPitch)<=math.rad(C.GunElevationTolerance)
 end
 render(st)
end

RunService.Heartbeat:Connect(function(dt)
	for model, st in pairs(tanks) do
		if model.Parent then
			BMPVision.update(st, fireSequence, stopFire, hullCentre)
			stepTank(st, math.min(dt, 0.1))
		else
			tanks[model] = nil
			Trees.forget(model)
		end
	end
end)

---------------------------------------------------------------- commands
-- [SHARED:Economy] BEGIN  (owner's money system, see doc "To ChatGPT" rule 2.4; do not change or remove)
local Economy = require(game:GetService("ServerScriptService").WarServer.Economy)
-- [SHARED:Economy] END
local function spawnTank(player, point, yaw)
	if not geo then
		message(player, "Tank model is missing (ServerStorage.CommandTankTemplate)")
		return
	end
	-- [SHARED:Economy] BEGIN  (owner's money system, see doc "To ChatGPT" rule 2.4; do not change or remove)
	if not Economy.canSummon(player, "BMP") then
		return
	end
	-- [SHARED:Economy] END
	local owned = ownedTanks(player)
	local slot
	for i = 1, C.MaxPerPlayer do
		if not owned[i] then
			slot = i
			break
		end
	end
	if not slot then
		message(player, string.format("Tank limit reached (%d/%d)", C.MaxPerPlayer, C.MaxPerPlayer))
		return
	end
	local model = geo.Template:Clone()
	model.Name = string.format("CommandTank_%d_%d", player.UserId, slot)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("CommandTank", true)
	model:SetAttribute("TankSlot", slot)
	model:SetAttribute("GroundOffset", geo.GroundOffset)
	model:SetAttribute("TreeCollisionWidth", geo.Width)
	model:SetAttribute("TreeCollisionLength", geo.Length)
	model:SetAttribute("TurretHoldMode", "Hull")
	model:SetAttribute("AutoMove", false)
	-- geometry the clients need to render the tank locally
	model:SetAttribute("HullRel", geo.HullRel)
	model:SetAttribute("TurretRel", geo.TurretRel)
	model:SetAttribute("TurretAxis", geo.Axis)
	model:SetAttribute("HullCenterRel", geo.HullCenterRel)
	model:SetAttribute("GunMountRel", geo.GunMountRel)
	model:SetAttribute("GunPivotRel", geo.GunPivotRel)
	local gy = groundAt(Vector3.new(point.X, point.Y + 5, point.Z))
 gy = TrenchSupport.height(Vector3.new(point.X,gy+geo.GroundOffset,point.Z),yaw,geo,groundParams(),gy)
	local st = {
		Model = model,
		Owner = player,
		Slot = slot,
		Hull = model.Hull,
		Turret = model.Turret,
		Muzzle = findPart(model.Turret, "CommandMuzzle"),
		Pos = Vector3.new(point.X, gy + geo.GroundOffset, point.Z),
		Yaw = U.wrapAngle(yaw),
		V = 0,
		Phase = "drive",
		Pitch = 0,
		PitchVel = 0,
		TurretYaw = 0,
		GunPitch = 0,
		HoldMode = "Hull",
		HoldWorldYaw = 0,
		FireSeq = 0,
		Firing = false,
		Aligned = false,
	}
	-- Reject overlapping placement on the server before reserving a slot or exposing the model.
	if vehicleAt(st, st.Pos) then
		model:Destroy()
		message(player, "Cannot place BMP on another tank. Choose a clear position.")
		return
	end
	tanks[model] = st
	render(st, true)
	model.Parent = tanksFolder
	BMPVision.register(st, hullCentre)
	TankCommand:FireClient(player, "Spawned", model, slot)
	-- [SHARED:Economy] BEGIN  (owner's money system, see doc "To ChatGPT" rule 2.4; do not change or remove)
	Economy.chargeSummon(player, "BMP")
	-- [SHARED:Economy] END
end

local function moveTank(player, st, point)
 st.CommandStartYaw=st.Yaw
 st.NavStallAttempts=0 st.ProgressWaypoint=nil
	local route, why = Roads.route(st.Pos, point)
	local path, onRoad
	if route == false then
		message(player, "Road is not connected to that point")
		return
	elseif route then
		path, onRoad = route, true
	else
		path, onRoad = { point }, false
	end
	st.Path, st.OnRoad = path, onRoad
	st.Recovery=nil
	st.PlanVersion=(st.PlanVersion or 0)+1
	st.PlanningRoute=false
	st.ForestArcs=nil
	st.ForestAvoidMode=false
	st.TreeChoices={}
	st.RecoveryTotal=0
 st.ReverseEscapeAttempts=0
	st.RouteReverse=nil
	st.DriveSign=1
	st.DetourResumePath=nil
	st.DetourWaypointCount=nil
	st.DetourObstacle=nil
	st.DetourSide=nil
	st.RecoveryAttempts=0
	st.LastObstacle=nil
	st.Model:SetAttribute("RecoveryState", nil)
	st.Phase = "drive"
	st.PendingPath = nil
	st.TurningInPlace = false
 local backwards=U.flat(point-st.Pos)
 if backwards and math.abs(U.wrapAngle(U.yawOf(backwards)-st.Yaw))>math.rad(105) and sidesBlocked(st) then
  st.RouteReverse=true
 end

end

local parkingEvent=ServerScriptService.WarServer:FindFirstChild("BMPParkingRequest") or Instance.new("BindableEvent")
parkingEvent.Name="BMPParkingRequest" parkingEvent.Parent=ServerScriptService.WarServer
parkingEvent.Event:Connect(function(player,model,point)
 local st=tanks[model]
 if not st or st.Owner~=player or not U.isFiniteVector(point) or (point-st.Pos).Magnitude>C.MaxSpeed*3 then
  if model and model.Parent then model:SetAttribute("ParkingForUnload",false) end return
 end
 local resume=st.Path and table.clone(st.Path) local road=st.OnRoad
 moveTank(player,st,point) st.UnloadResumePath=resume st.UnloadResumeOnRoad=road
end)
local function fireTank(st, point)

	-- same clamp as the client preview: white circle centre stays in [MinRange+r, Length-r]
	local r = C.TargetCircleDiameter / 2
	local centre = (CFrame.new(st.Pos) * CFrame.Angles(0, st.Yaw, 0)) * geo.HullCenterRel
	local d = Vector3.new(point.X - centre.X, 0, point.Z - centre.Z)
	local dist = d.Magnitude
	if dist < 1e-3 then
		return
	end
	local clamped = math.clamp(dist, C.MinRange + r, C.AimRectLength - r)
	local p = centre + d / dist * clamped
	local gy = groundAt(Vector3.new(p.X, point.Y + 5, p.Z))
	task.spawn(fireSequence, st, Vector3.new(p.X, gy, p.Z))
end

TankCommand.OnServerEvent:Connect(function(player, action, point, yaw, tank)
	if not U.isFiniteVector(point) then
		return
	end
	if action == "Spawn" then
		if U.isFiniteNumber(yaw) then
			spawnTank(player, point, yaw)
		end
		return
	end
	local st = typeof(tank) == "Instance" and tanks[tank]
	if not st or st.Owner ~= player then
		return -- ownership enforced on the server
	end
	if action == "Watch" then
		local d=U.flat(point)
		if not d then return end
		st.WatchYaw=U.yawOf(d)
		st.Model:SetAttribute("WatchYaw",st.WatchYaw)
		st.AutoEnabled=true
		if st.Firing and not st.AutoFiring then
			local Vision=require(ServerScriptService.WarServer.VisionService)
			local enemy=Vision.nearestVisible(st.FireTarget,10,"Player")
			stopFire(st)
			if enemy then st.AutoTarget=enemy end
		end
	elseif action=="CancelWatch" then
		st.WatchYaw=nil
		st.Model:SetAttribute("WatchYaw",nil)
		st.ScanLast=os.clock()
	elseif action == "Move" then
  st.UnloadResumePath=nil
		st.AutoEnabled = true
		moveTank(player, st, point)
	elseif action == "Fire" then
		if st.AutoFiring then stopFire(st) end
		st.AutoFiring = false
		st.AutoTarget = nil
		st.AutoEnabled = true
		fireTank(st, point)
	elseif action == "Stop" then
		st.AutoEnabled = true
		st.AutoFiring = false
		st.AutoTarget = nil
		stopFire(st)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for model, st in pairs(tanks) do
		if st.Owner == player then
			tanks[model] = nil
			Trees.forget(model)
			model:Destroy()
		end
	end
end)
