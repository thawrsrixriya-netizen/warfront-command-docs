-- ReplicatedStorage.InfantryRiflePose  (ModuleScript)
local M={}
local Overhead=require(game.ReplicatedStorage.WarShared.InfantryOverhead)
local ReloadTime=require(game.ReplicatedStorage.InfantryConfig).ReloadTime
local folder=game.ReplicatedStorage:WaitForChild("InfantryRifleAnimations")
local clips={}
for _,seq in folder:GetChildren() do
 if seq:IsA("KeyframeSequence") then
  local c={Tracks={},Duration=0}
  for _,k in seq:GetKeyframes() do
   c.Duration=math.max(c.Duration,k.Time)
   for _,p in k:GetDescendants() do if p:IsA("Pose") then
    c.Tracks[p.Name]=c.Tracks[p.Name] or {}
    table.insert(c.Tracks[p.Name],{T=k.Time,CF=p.CFrame})
   end end
  end
  for _,track in c.Tracks do table.sort(track,function(a,b)return a.T<b.T end) end
  clips[seq.Name]=c
 end
end
local function sample(clip,name,t)
 local track=clip.Tracks[name]
 if not track then return CFrame.identity end
 if t<=track[1].T then return track[1].CF end
 if t>=track[#track].T then return track[#track].CF end
 local lo,hi=1,#track
 while hi-lo>1 do local mid=math.floor((hi+lo)/2) if track[mid].T<=t then lo=mid else hi=mid end end
 local a,b=track[lo],track[hi]
 return a.CF:Lerp(b.CF,(t-a.T)/(b.T-a.T))
end
local function source(clip,t,prefix)
 local arms={}
 for _,name in {"Right Arm","Left Arm"} do
  local key=name=="Right Arm" and "RightShoulder" or "LeftShoulder"
  arms[name]=folder:GetAttribute(prefix..key.."C0")*sample(clip,name,t)*folder:GetAttribute(prefix..key.."C1"):Inverse()
 end
 local handle=arms["Right Arm"]*folder:GetAttribute(prefix.."HandleC0")*sample(clip,"RootPart",t)*folder:GetAttribute(prefix.."HandleC1"):Inverse()
 return arms,handle
end
local holdArms,holdGun=source(clips.Hold,0,"A")
local fireArms,fireGun=source(clips.FireBase,0,"B")
function M.frame(rootCF,prone,target,crouch,scale,crouchDrop)
 local offset=Vector3.new(0.36,0.14,-0.48):Lerp(Vector3.new(0.32,-0.99,-0.90),prone)
 offset+=Vector3.new(0,-(crouchDrop or .9677603245)*(scale or .4375)*(crouch or 0)*(1-prone),0)
 offset+=Vector3.new(0,.12*(crouch or 0)*(1-prone),0)
 local origin=rootCF*offset
 local direction=target and target-origin or rootCF.LookVector
 if direction.Magnitude<0.01 then direction=rootCF.LookVector end
 local horizontal=Vector3.new(direction.X,0,direction.Z)
 if horizontal.Magnitude<0.01 then horizontal=rootCF.LookVector end
 local pitch=math.clamp(math.atan2(direction.Y,horizontal.Magnitude),math.rad(-45),math.rad(60))
 return CFrame.lookAt(origin,origin+horizontal.Unit*math.cos(pitch)+Vector3.yAxis*math.sin(pitch))
end
function M.apply(model,anim,dt)
 local gun=model:FindFirstChild("Rifle") local torso=model:FindFirstChild("Torso")
 local mount=torso and torso:FindFirstChild("WeaponMount")
 if not gun or not mount then return end
 if model:GetAttribute("BoardingClimb") then
  -- Keep both hands free for the climb; the rifle is carried against the back.
  mount.C0=CFrame.new(.22,.05,.28)*CFrame.Angles(math.rad(75),0,math.rad(-20))
  anim.RifleFrame=nil anim.RifleArms=nil
  return
 end
 local root=model.HumanoidRootPart

 local now=workspace:GetServerTimeNow()
 local reloadUntil=model:GetAttribute("RifleReloadUntil") or 0
 local reloading=now<reloadUntil
 local age=now-(model:GetAttribute("LastRifleShot") or -100)
 local clip,t,prefix=clips.Hold,anim.Time%math.max(clips.Hold.Duration,.001),"A"
 local referenceArms,referenceGun=holdArms,holdGun
 if reloading then
  clip=clips.Reload t=math.clamp((now-(reloadUntil-ReloadTime))/ReloadTime,0,1)*clip.Duration
 elseif age>=0 and age<.15 then
  clip=clips.Fire t=math.clamp(age/.15,0,1)*clip.Duration prefix="B"
  referenceArms,referenceGun=fireArms,fireGun
 end
 local arms,handle=source(clip,t,prefix)
 local positionScale=anim.Scale*.85
 local baseFrame=M.frame(root.CFrame,anim.Prone,model:GetAttribute("FireTarget"),anim.Crouch,anim.Scale,.9677603245+(.72-.9677603245)*anim.RunWeight)
 local relaxed=not model:GetAttribute("FireActive") and not reloading
 local lowerTarget=relaxed and anim.RunWeight*(1-anim.Prone) or 0
 anim.RunLower=(anim.RunLower or 0)+(lowerTarget-(anim.RunLower or 0))*(1-math.exp(-10*dt))
 local idleAngle=relaxed and -12*(1-anim.Prone)*(1-anim.Crouch) or 0
 baseFrame*=CFrame.new(0,-0.12*anim.RunLower,0.06*anim.RunLower)*CFrame.Angles(math.rad(idleAngle-30*anim.RunLower),0,0)
 if Overhead.normal(model) and model:GetAttribute("FireActive") and not reloading then
  baseFrame=Overhead.normalFrame(model,root.CFrame,model:GetAttribute("FireTarget"),baseFrame)
 end
 local overhead=anim.Overhead or 0
 if overhead>.001 then baseFrame=baseFrame:Lerp(Overhead.frame(model,root.CFrame,model:GetAttribute("FireTarget")),overhead) end
 local gunDelta=CFrame.new((handle.Position-referenceGun.Position)*positionScale)*(handle.Rotation*referenceGun.Rotation:Inverse())
 local desired=baseFrame*gunDelta
 anim.RifleFrame=anim.RifleFrame and anim.RifleFrame:Lerp(desired,1-math.exp(-35*dt)) or desired
 mount.C0=torso.CFrame:ToObjectSpace(anim.RifleFrame)
 for _,name in {"Right Arm","Left Arm"} do
  local joint=anim.Joints[name] local arm=joint and joint.Part1
  if arm then
   local grip=name=="Right Arm" and Vector3.new(0,-.025,0) or Vector3.new(-.025,.025,-.44)
   local rest=holdArms[name]
   local center=grip+rest.UpVector*(arm.Size.Y*.38)
   local translation=(arms[name].Position-referenceArms[name].Position)*positionScale
   local rotation=arms[name].Rotation*referenceArms[name].Rotation:Inverse()*rest.Rotation
   local armCF=baseFrame*CFrame.new(center+translation)*rotation
   if name=="Right Arm" and anim.RunLower>.001 then
    -- Lower the soldier right shoulder (viewer left) while keeping the grip fixed.
    local up=armCF.UpVector
    local horizontal=Vector3.new(up.X,0,up.Z)
    if horizontal.Magnitude>.001 then
     local pitch=math.atan2(up.Y,horizontal.Magnitude)
     local lowered=math.min(pitch,math.max(math.rad(-15),pitch-math.rad(40)*anim.RunLower))
     local wanted=horizontal.Unit*math.cos(lowered)+Vector3.yAxis*math.sin(lowered)
     local axis=up:Cross(wanted)
     if axis.Magnitude>.001 then
      local hand=armCF.Position-up*(arm.Size.Y*.38)
      local adjustment=CFrame.fromAxisAngle(axis.Unit,math.acos(math.clamp(up:Dot(wanted),-1,1)))
      local orientation=adjustment*armCF.Rotation
      armCF=CFrame.new(hand+orientation.UpVector*(arm.Size.Y*.38))*orientation
     end
    end
   end
   if overhead>.001 then
    local hand=baseFrame:PointToWorldSpace(grip+translation)
    local side=name=="Right Arm" and 1 or -1
    local shoulder=torso.CFrame:PointToWorldSpace(Vector3.new(side*torso.Size.X*.5,torso.Size.Y*.45,0))
    local up=(shoulder-hand).Unit
    local right=baseFrame.RightVector-up*baseFrame.RightVector:Dot(up)
    if right.Magnitude>.001 then
     right=right.Unit
     local raised=CFrame.fromMatrix(hand+up*(arm.Size.Y*.38),right,up,right:Cross(up))
     armCF=armCF:Lerp(raised,overhead)
    end
   end
   local goal=torso.CFrame:ToObjectSpace(armCF)*joint.C1
   anim.RifleArms=anim.RifleArms or {}
   anim.RifleArms[name]=anim.RifleArms[name] and anim.RifleArms[name]:Lerp(goal,1-math.exp(-25*dt)) or goal
   joint.C0=anim.RifleArms[name]
  end
 end
 local mag=gun.WeaponRoot:FindFirstChild("MagazineMotor")
 if mag then
  local rest=mag:GetAttribute("RestC0")
  local change=CFrame.identity
  if reloading then
   local pose=sample(clip,"Mag",t)
   local c0=folder:GetAttribute("AMagC0") local c1=folder:GetAttribute("AMagC1")
   local sourceRest=c0*c1:Inverse()
   local sourceCurrent=c0*pose*c1:Inverse()
   local rotationBasis=holdGun.Rotation
   local p=rotationBasis*(sourceCurrent.Position-sourceRest.Position)*positionScale
   local r=rotationBasis*sourceCurrent.Rotation*sourceRest.Rotation:Inverse()*rotationBasis:Inverse()
   change=CFrame.new(p)*r
  end
  mag.C0=CFrame.new(rest.Position+change.Position)*change.Rotation*rest.Rotation
 end
end
return M