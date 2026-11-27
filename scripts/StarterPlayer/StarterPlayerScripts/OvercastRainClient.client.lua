-- StarterPlayer.StarterPlayerScripts.OvercastRainClient  (LocalScript)
-- Lightweight local rain; recycled streaks stop at roofs and ground.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local rng=Random.new()
local folder=Instance.new("Folder")
folder.Name="LocalOvercastRain"
folder.Parent=workspace
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.IgnoreWater=false
local drops={}
local weather=game:GetService("ReplicatedStorage"):WaitForChild("MapWeather")
local intensity=0
local velocity=Vector3.new(-5,-60,2)
local function reset(drop,randomAge)
 local camera=workspace.CurrentCamera
 if not camera then drop.Part.Transparency=1 return end
 local centre=camera.CFrame.Position+camera.CFrame.LookVector*16
 local origin=centre+Vector3.new(rng:NextNumber(-30,30),rng:NextNumber(20,32),rng:NextNumber(-30,30))
 local hit=workspace:Raycast(origin,velocity.Unit*130,params)
 local life=hit and math.min((hit.Position-origin).Magnitude/velocity.Magnitude,1.5) or 1.2
 drop.Origin=origin
 drop.Life=math.max(0.02,life)
 drop.Age=randomAge and rng:NextNumber(0,drop.Life) or 0
 drop.BaseTransparency=rng:NextNumber(0.48,0.7)
 drop.Part.Transparency=1-(1-drop.BaseTransparency)*intensity
end
local function filters()
 local list={folder}
 for _,p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list,p.Character) end end
 params.FilterDescendantsInstances=list
end
filters()
for i=1,100 do
 local p=Instance.new("Part")
 p.Name="Rain"
 p.Size=Vector3.new(0.025,0.025,rng:NextNumber(1.2,2.5))
 p.Color=Color3.fromRGB(177,190,202)
 p.Material=Enum.Material.SmoothPlastic
 p.Anchored=true
 p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false
 p.Transparency=1
 p.Parent=folder
 local drop={Part=p}
 drops[i]=drop
 reset(drop,true)
end
local filterTimer=0
RunService.RenderStepped:Connect(function(dt)
 local target=weather:GetAttribute("Raining") and 1 or 0
 intensity+=math.clamp(target-intensity,-dt/5,dt/5)
 if intensity<0.001 and target==0 then
  for _,drop in ipairs(drops) do drop.Part.Transparency=1;drop.Origin=nil end
  return
 end
 filterTimer+=dt
 if filterTimer>1 then filterTimer=0;filters() end
 for _,drop in ipairs(drops) do
  if drop.Origin then
   drop.Age+=math.min(dt,0.1)
   if drop.Age>=drop.Life then reset(drop,false) end
   local pos=drop.Origin+velocity*drop.Age
   drop.Part.CFrame=CFrame.lookAlong(pos,velocity)
   drop.Part.Transparency=1-(1-(drop.BaseTransparency or 0.6))*intensity
  else reset(drop,true) end
 end
end)
script.Destroying:Connect(function() folder:Destroy() end)
