-- ReplicatedStorage.InfantryAnimation  (ModuleScript)
-- Imported R6 keyframes; evaluated locally with scaled translation.
local M={}
local Overhead=require(game.ReplicatedStorage.WarShared.InfantryOverhead)
local clips={}
local folder=game.ReplicatedStorage:WaitForChild("InfantryAnimations")
for _,seq in folder:GetChildren() do
 if seq:IsA("KeyframeSequence") then
  local tracks={} local duration=0
  for _,frame in seq:GetKeyframes() do
   duration=math.max(duration,frame.Time)
   for _,pose in frame:GetDescendants() do
    if pose:IsA("Pose") and pose.Name~="HumanoidRootPart" then
     tracks[pose.Name]=tracks[pose.Name] or {}
     table.insert(tracks[pose.Name],{Time=frame.Time,CF=pose.CFrame})
    end
   end
  end
  for _,track in tracks do table.sort(track,function(a,b)return a.Time<b.Time end) end
  clips[seq.Name]={Tracks=tracks,Duration=duration}
 end
end
local function sample(track,t,scale)
 local a,b=track[1],track[#track]
 for i=1,#track-1 do if t>=track[i].Time and t<track[i+1].Time then a,b=track[i],track[i+1] break end end
 if t<=track[1].Time then a,b=track[1],track[1] end
 local cf=a.CF:Lerp(b.CF,b.Time>a.Time and math.clamp((t-a.Time)/(b.Time-a.Time),0,1) or 0)
 return CFrame.new(cf.Position*scale)*cf.Rotation
end
function M.bind(model)
 local state={Joints={},Base={},Scale=model:GetScale(),Model=model,Time=0,Prone=0,Crouch=0,Overhead=0,RunWeight=0,RunTime=0}
 for _,v in model:GetDescendants() do
  if v:IsA("Motor6D") and v.Part1 then state.Joints[v.Part1.Name]=v state.Base[v.Part1.Name]=v.C0 end
 end
 return state
end
local function rotate(base,x,y,z)
 return CFrame.new(base.Position)*CFrame.Angles(x,y,z)*base.Rotation
end
function M.step(s,dt,moving,prone,speed,crouched)
 s.Time+=dt
 if s.Model:GetAttribute("CommandStopped") and not s.Model:GetAttribute("LowCeiling") then s.Crouch=0 s.Prone=0 s.Overhead=0 end
 s.Overhead+=((Overhead.active(s.Model) and 1 or 0)-s.Overhead)*(1-math.exp(-12*dt))
 if crouched==nil then crouched=s.Model:GetAttribute("Crouched") end
 if moving then crouched=false s.Crouch=0 end
 s.Crouch+=(((crouched and not prone) and 1 or 0)-s.Crouch)*(1-math.exp(-9*dt))
 s.Prone+=((prone and 1 or 0)-s.Prone)*(1-math.exp(-7*dt))
 s.RunWeight+=((moving and 1 or 0)-s.RunWeight)*(1-math.exp(-10*dt))
 s.RunTime+=dt*math.clamp(speed/7,0.2,1.5)
 local clip=clips[moving and "Run" or "Idle"]
 local t=clip and clip.Duration>0 and ((s.Time*(moving and math.clamp(speed/7,0.3,1.5) or 1))%clip.Duration) or 0
 local crawl=moving and math.sin(s.Time*6)*0.15 or 0
 for name,joint in s.Joints do
  local base=s.Base[name]
  local track=clip and clip.Tracks[name]
  local idle=clips.Idle
  local run=clips.Run
  local idleTrack=idle and idle.Tracks[name]
  local runTrack=run and run.Tracks[name]
  local idlePose=idleTrack and base*sample(idleTrack,s.Time%math.max(idle.Duration,0.001),s.Scale) or base
  local runPose=runTrack and base*sample(runTrack,s.RunTime%math.max(run.Duration,0.001),s.Scale) or base
  local standing=idlePose:Lerp(runPose,s.RunWeight)
  -- R6 crouch: lower the hips, bend at the hip joints, and lean slightly forward.
  local crouchPose=base
  local step=moving and math.sin(s.RunTime*7)*.22 or 0
  if name=="Torso" then
   crouchPose=CFrame.new(0,-.72*s.Scale,-.10*s.Scale)*CFrame.Angles(math.rad(-12),0,0)*base
  elseif name=="Head" then crouchPose=rotate(base,math.rad(10),0,0)
  elseif name=="Left Leg" then
   crouchPose=CFrame.new(0,.03*s.Scale,-.13*s.Scale)*rotate(base,math.rad(-49)+step,0,math.rad(-5))
  elseif name=="Right Leg" then
   crouchPose=CFrame.new(0,.03*s.Scale,-.13*s.Scale)*rotate(base,math.rad(-49)-step,0,math.rad(5))
  elseif name=="Left Arm" then crouchPose=rotate(base,math.rad(-15),0,math.rad(-7))
  elseif name=="Right Arm" then crouchPose=rotate(base,math.rad(-15),0,math.rad(7)) end
  local kneel=clips.CrouchIdle
  local kneelTrack=kneel and kneel.Tracks[name]
  if kneelTrack then
   local imported=base*sample(kneelTrack,s.Time%math.max(kneel.Duration,.001),s.Scale)
   crouchPose=imported:Lerp(crouchPose,s.RunWeight)
  end
  if name=="Head" then
   local weight=1-s.RunWeight
   crouchPose=CFrame.new(crouchPose.Position+Vector3.new(.06,-.02,-.06)*s.Scale*weight)
    *CFrame.Angles(math.rad(-6)*weight,math.rad(-5)*weight,math.rad(-12)*weight)*crouchPose.Rotation
  end
  standing=standing:Lerp(crouchPose,s.Crouch)
  local low=base
  if name=="Torso" then
   low=CFrame.new(0,-2.05*s.Scale,0)*CFrame.Angles(-math.pi/2,0,0)*base
  elseif name=="Head" then low=rotate(base,math.rad(65),0,0)
  elseif name=="Left Arm" then low=rotate(base,math.rad(190)+crawl,0,-0.16)
  elseif name=="Right Arm" then low=rotate(base,math.rad(190)-crawl,0,0.16)
  elseif name=="Left Leg" then low=rotate(base,crawl*0.4,0,-0.09)
  elseif name=="Right Leg" then low=rotate(base,-crawl*0.4,0,0.09) end
  local proneClip=clips[moving and "Crawl" or "ProneIdle"]
  local proneTrack=proneClip and proneClip.Tracks[name]
  if proneTrack then
   local proneTime=moving and (s.Time*0.85)%math.max(proneClip.Duration,0.001) or 0
   low=base*sample(proneTrack,proneTime,s.Scale)
  end
  local result=standing:Lerp(low,s.Prone)
  if s.Overhead>.001 then
   local concealed=idlePose
   if name=="Head" then
    concealed=CFrame.new(concealed.Position)*CFrame.Angles(math.rad(-5),0,0)*concealed.Rotation
   end
   result=result:Lerp(concealed,s.Overhead)
  end
  local board=clips.BoardClimb
  if s.Model:GetAttribute("BoardingClimb") and board then
   local age=workspace:GetServerTimeNow()-(s.Model:GetAttribute("BoardClimbStart") or workspace:GetServerTimeNow())
   local duration=s.Model:GetAttribute("BoardClimbDuration") or 1.35
   local progress=math.clamp(age/duration,0,1)
   local weight=math.clamp(age/.12,0,1)
   if s.Model:GetAttribute("DisembarkingClimb") then progress=1-progress end
   local boardingTrack=board.Tracks[name]
   local pose=boardingTrack and base*sample(boardingTrack,progress*board.Duration,s.Scale) or base
   result=result:Lerp(pose,weight)
  end
  joint.C0=joint.C0:Lerp(result,1-math.exp(-25*dt))

 end
end
return M