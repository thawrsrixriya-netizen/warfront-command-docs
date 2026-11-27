-- StarterPlayer.StarterPlayerScripts.InfantryRender  (LocalScript)
-- Smooth authoritative snapshots independently of network update rate.
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Folder=workspace:WaitForChild("CommandInfantry")
local Remote=RS:WaitForChild("Remotes"):WaitForChild("InfantryCommand")
local Animation=require(RS:WaitForChild("InfantryAnimation"))
local RiflePose=require(RS:WaitForChild("InfantryRiflePose"))
local states={}
local function bind(model)
 if states[model] then return states[model] end
 local root=model:FindFirstChild("HumanoidRootPart")
 if not root then return end
 local torso=model:FindFirstChild("Torso")
 if not torso then return end
 for _,name in {"Neck","Right Shoulder","Left Shoulder","Right Hip","Left Hip"} do
  local joint=torso:FindFirstChild(name)
  if not joint or not joint.Part0 or not joint.Part1 then return end
 end
 local rootJoint=root:FindFirstChild("RootJoint")
 if not rootJoint or not rootJoint.Part1 then return end
 local st={Root=root,Animation=Animation.bind(model),Frames={},LastCF=root.CFrame}
 states[model]=st return st
end
Remote.OnClientEvent:Connect(function(kind,model,cf,time,moving,prone,speed,crouched)
 if kind~="State" or typeof(model)~="Instance" or not model.Parent then return end
 local st=bind(model) if not st then return end
 table.insert(st.Frames,{CF=cf,Time=time,Moving=moving,Prone=prone,Speed=speed,Crouched=crouched==true})
 while #st.Frames>12 do table.remove(st.Frames,1) end
end)
Folder.ChildAdded:Connect(bind)
for _,model in Folder:GetChildren() do bind(model) end
RunService:BindToRenderStep("InfantrySmoothRender",Enum.RenderPriority.Character.Value+1,function(dt)
 local time=workspace:GetServerTimeNow()-0.1
 for model,st in states do
  if not model.Parent or not st.Root.Parent then states[model]=nil continue end
  if model:GetAttribute("Embarked") then st.Frames={} st.LastCF=st.Root.CFrame continue end
  local frames=st.Frames
  while #frames>2 and frames[2].Time<=time do table.remove(frames,1) end
  local a,b=frames[1],frames[2]
  if a then
   b=b or a
   local alpha=b.Time>a.Time and math.clamp((time-a.Time)/(b.Time-a.Time),0,1) or 0
   local target=a.CF:Lerp(b.CF,alpha)
   if (target.Position-st.LastCF.Position).Magnitude>12 then st.LastCF=target
   else st.LastCF=st.LastCF:Lerp(target,1-math.exp(-35*dt)) end
   st.Root.CFrame=st.LastCF
   local pose=alpha>=0.5 and b or a
   Animation.step(st.Animation,dt,pose.Moving,pose.Prone,pose.Speed,pose.Crouched)
   RiflePose.apply(model,st.Animation,dt)
  end
 end
end)
