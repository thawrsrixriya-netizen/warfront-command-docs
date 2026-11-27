-- ServerScriptService.WarServer.InfantryAnimation  (ModuleScript)
-- Imported R6 keyframes; evaluated locally with scaled translation.
local M={}
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
 local state={Joints={},Base={},Scale=model:GetScale(),Time=0,Prone=0}
 for _,v in model:GetDescendants() do
  if v:IsA("Motor6D") and v.Part1 then state.Joints[v.Part1.Name]=v state.Base[v.Part1.Name]=v.C0 end
 end
 return state
end
local function rotate(base,x,y,z)
 return CFrame.new(base.Position)*CFrame.Angles(x,y,z)*base.Rotation
end
function M.step(s,dt,moving,prone,speed)
 s.Time+=dt
 s.Prone+=((prone and 1 or 0)-s.Prone)*math.min(1,dt*7)
 local clip=clips[moving and "Run" or "Idle"]
 local t=clip and clip.Duration>0 and ((s.Time*(moving and math.clamp(speed/7,0.3,1.5) or 1))%clip.Duration) or 0
 local crawl=moving and math.sin(s.Time*6)*0.15 or 0
 for name,joint in s.Joints do
  local base=s.Base[name]
  local track=clip and clip.Tracks[name]
  local standing=track and base*sample(track,t,s.Scale) or base
  local low=base
  if name=="Torso" then
   low=CFrame.new(0,-2.05*s.Scale,0)*CFrame.Angles(-math.pi/2,0,0)*base
  elseif name=="Head" then low=rotate(base,math.rad(65),0,0)
  elseif name=="Left Arm" then low=rotate(base,math.rad(190)+crawl,0,-0.16)
  elseif name=="Right Arm" then low=rotate(base,math.rad(190)-crawl,0,0.16)
  elseif name=="Left Leg" then low=rotate(base,crawl*0.4,0,-0.09)
  elseif name=="Right Leg" then low=rotate(base,-crawl*0.4,0,0.09) end
  joint.C0=standing:Lerp(low,s.Prone)
 end
end
return M