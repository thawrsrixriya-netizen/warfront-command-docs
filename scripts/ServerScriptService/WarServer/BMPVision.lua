-- ServerScriptService.WarServer.BMPVision  (ModuleScript)
local RS=game:GetService("ReplicatedStorage")
local CS=game:GetService("CollectionService")
local Vision=require(script.Parent.VisionService)
local Config=require(RS.VisionConfig)
local U=require(RS.WarShared.WarUtil)
local Behavior=require(RS.BMPBehaviorConfig)
local Registry=require(RS.WarShared.EnemyRegistry)
local M={}
local PassengerVision=require(RS.WarShared.BMPPassengerVision)
function M.register(st,centre)
 Vision.register(st.Model,{
  Team="Player",Profile="BMP",
  GetYaw=function() return st.Yaw end,
  GetCones=function() return PassengerVision.cones(st.Model,st.Yaw) end,
  GetYaws=function() return {st.Yaw,st.Yaw+st.TurretYaw} end,
  GetEye=function() return centre(st)+Vector3.new(0,Config.Profiles.BMP.EyeHeight,0) end,
  OnAttacked=function(from)
   st.AlertPos=from; st.AlertUntil=os.clock()+Config.AlertSeconds
  end,
 })
 st.AutoEnabled=true
 st.ScanLast=os.clock()
 st.ScanPauseUntil=os.clock()+math.random()*2+2
 st.ScanVelocity=0
end
function M.allowed(st)
 local m=st.AutoTarget
 if not m or not m.Parent or not Vision.isVisible(m,"Player") then return false end
 local h=m:FindFirstChildOfClass("Humanoid")
 local r=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
 return r~=nil and (not h or h.Health>0) and (U.flat(r.Position-st.Pos)~=nil)
  and Vector3.new(r.Position.X-st.Pos.X,0,r.Position.Z-st.Pos.Z).Magnitude<=Config.Profiles.BMP.WeaponRange
end
function M.clearShot(st,from,target,targetModel)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
 local excluded={}
 for _,name in ipairs(U.EFFECT_FOLDERS) do local f=workspace:FindFirstChild(name); if f then table.insert(excluded,f) end end
 for _,p in ipairs(game.Players:GetPlayers()) do if p.Character then table.insert(excluded,p.Character) end end
 for _,tag in ipairs({"TankReactiveTree","TankPassThroughVegetation"}) do for _,v in ipairs(CS:GetTagged(tag)) do table.insert(excluded,v) end end
 for _=1,12 do
  params.FilterDescendantsInstances=excluded
  local hit=workspace:Raycast(from,target-from,params)
  if not hit or ((targetModel or st.AutoTarget) and hit.Instance:IsDescendantOf(targetModel or st.AutoTarget)) then return true end
  if hit.Instance.Transparency>=.9 then table.insert(excluded,hit.Instance) else return false end
 end
 return false
end
function M.update(st,startFire,stopFire,centre)
 if not st.AutoEnabled or (st.Firing and not st.AutoFiring) then return end
 local pos=centre(st)
 local target,bestDistance
 if st.WatchYaw and M.allowed(st) then
  local r=st.AutoTarget:FindFirstChild("HumanoidRootPart") or st.AutoTarget.PrimaryPart
  if r and M.clearShot(st,st.GunMuzzleCF.Position,r.Position,st.AutoTarget) then
   target=st.AutoTarget; bestDistance=-1
  end
 end
 for _,e in ipairs(Registry.all(false)) do
  local distance=Vector3.new(e.Position.X-pos.X,0,e.Position.Z-pos.Z).Magnitude
  if distance<=Config.Profiles.BMP.WeaponRange and Vision.isVisible(e.Model,"Player")
   and (not bestDistance or distance<bestDistance)
   and M.clearShot(st,st.GunMuzzleCF.Position,e.Position,e.Model) then
   target=e.Model; bestDistance=distance
  end
 end
 local r=target and (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart)
 if r then
  st.ScanLast=os.clock()
  st.ScanGoal=nil
  st.ScanVelocity=0
  st.ScanPauseUntil=os.clock()+Behavior.ScanPause
  st.Model:SetAttribute("AutoTarget",target.Name)
  st.AutoTarget=target
  st.FireTarget=r.Position
  if not st.AutoFiring then
   st.AutoFiring=true
   -- Start immediately so two heartbeat updates cannot spawn duplicate firing loops.
   task.spawn(startFire,st,r.Position)
  end
 elseif st.AutoFiring then
  stopFire(st); st.AutoFiring=false; st.AutoTarget=nil
  st.Model:SetAttribute("AutoTarget",nil)
 elseif st.WatchYaw then
  local now=os.clock()
  local dt=math.clamp(now-(st.ScanLast or now),0,.1)
  st.ScanLast=now
  local desired=U.wrapAngle(st.WatchYaw-st.Yaw)
  local error=U.wrapAngle(desired-st.TurretYaw)
  local speed=math.rad(require(RS.WarConfig).Tank.TurretSpeed)
  st.TurretYaw=U.wrapAngle(st.TurretYaw+math.clamp(error,-speed*dt,speed*dt))
  st.HoldMode="Hull"
 elseif st.AlertUntil and os.clock()<st.AlertUntil and st.AlertPos then
  local d=U.flat(st.AlertPos-pos)
  if d then st.HoldMode="World"; st.HoldWorldYaw=U.yawOf(d) end
 else
  local now=os.clock()
  local dt=math.clamp(now-(st.ScanLast or now),0,.1)
  st.ScanLast=now
  if now>=(st.ScanPauseUntil or 0) then
   if not st.ScanGoal then
    local limit=math.rad(Behavior.ScanHalfAngle)
    local current=math.clamp(st.TurretYaw,-limit,limit)
    -- Usually inspect the next nearby sector; bias back toward the hull's front.
    local step=math.rad(Behavior.ScanStepMin+math.random()*(Behavior.ScanStepMax-Behavior.ScanStepMin))
    local sign=math.random()<.5 and -1 or 1
    if math.abs(current)>math.rad(20) and math.random()<.8 then sign=current>0 and -1 or 1 end
    st.ScanGoal=math.clamp(current+sign*step,-limit,limit)
   end
   local error=U.wrapAngle(st.ScanGoal-st.TurretYaw)
   local speed=math.rad(Behavior.ScanSpeed)
   local desired=math.clamp(error*2,-speed,speed)
   local velocity=st.ScanVelocity or 0
   local acceleration=math.rad(Behavior.ScanAcceleration)
   velocity+=math.clamp(desired-velocity,-acceleration*dt,acceleration*dt)
   local delta=velocity*dt
   if math.abs(error)<math.rad(.25) or (delta*error>0 and math.abs(delta)>=math.abs(error)) then
    st.TurretYaw=st.ScanGoal
    st.ScanGoal=nil; st.ScanVelocity=0
    st.ScanPauseUntil=now+Behavior.ScanPause+math.random()*(Behavior.ScanPauseMax-Behavior.ScanPause)
   else
    st.ScanVelocity=velocity
    st.TurretYaw=U.wrapAngle(st.TurretYaw+delta)
   end
  else
   st.ScanVelocity=0
  end
  st.HoldMode="Hull"
 end
end
return M
