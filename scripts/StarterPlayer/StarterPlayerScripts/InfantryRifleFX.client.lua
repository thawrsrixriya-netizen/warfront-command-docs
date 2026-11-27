-- StarterPlayer.StarterPlayerScripts.InfantryRifleFX  (LocalScript)
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local remote=RS.Remotes:WaitForChild("InfantryCommand")
local folder=Instance.new("Folder") folder.Name="InfantryLocalFX" folder.Parent=workspace.CurrentCamera
local tracers={}
local C=require(RS.InfantryConfig)
local reloads={}
local function sound(parent,id,volume)
 local a=Instance.new("Sound") a.SoundId="rbxassetid://"..id a.Volume=volume
 a.RollOffMode=Enum.RollOffMode.InverseTapered a.RollOffMinDistance=8 a.RollOffMaxDistance=180
 a.Parent=parent return a
end
local function shotAudio(origin)
 local emitter=Instance.new("Part") emitter.Name="InfantryShotAudio"
 emitter.Anchored=true emitter.CanCollide=false emitter.CanTouch=false emitter.CanQuery=false
 emitter.Transparency=1 emitter.Size=Vector3.one*.1 emitter.Position=origin emitter.Parent=folder
 local a=sound(emitter,C.RifleShotSound,C.RifleShotVolume)
 a.Ended:Once(function() emitter:Destroy() end)
 Debris:AddItem(emitter,8) a:Play()
end
local function updateReloads()
 local units=workspace:FindFirstChild("CommandInfantry")
 local now=workspace:GetServerTimeNow()
 if units then for _,model in units:GetChildren() do
  if not model:IsA("Model") then continue end
  local finish=model:GetAttribute("RifleReloadUntil") or 0
  local root=model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
  if finish>now and root then
   if not reloads[model] then
    local a=sound(root,C.RifleReloadSound,C.RifleReloadVolume)
    a.Name="InfantryReloadAudio" a:Play() reloads[model]=a
   end
  end
 end end
 for model,a in reloads do
  if not model:IsDescendantOf(workspace) or (model:GetAttribute("RifleReloadUntil") or 0)<=now or model:GetAttribute("CommandStopped") then
   a:Destroy() reloads[model]=nil
  end
 end
end
RunService.Heartbeat:Connect(updateReloads)

local function part(size,color)
 local p=Instance.new("Part") p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
 p.Material=Enum.Material.Neon p.Size=size p.Color=color p.CastShadow=false p.Parent=folder return p
end
remote.OnClientEvent:Connect(function(kind,model,origin,impact)
 if kind~="Shot" then return end
 local muzzle=model and model:FindFirstChild("Muzzle",true)
 if muzzle and muzzle:IsA("Attachment") then origin=muzzle.WorldPosition end
 if typeof(origin)~="Vector3" or typeof(impact)~="Vector3" then return end
 shotAudio(origin)
 local direction=impact-origin if direction.Magnitude<0.01 then return end
 local flash=part(Vector3.new(.11,.11,.22),Color3.fromRGB(255,206,90))
 flash.CFrame=CFrame.lookAt(origin,origin+direction)
 local light=Instance.new("PointLight") light.Brightness=1.2 light.Range=3 light.Color=flash.Color light.Parent=flash Debris:AddItem(flash,.045)
 local tracer=part(Vector3.new(.018,.018,.65),Color3.fromRGB(255,225,150))
 table.insert(tracers,{Part=tracer,Origin=origin,Target=impact,Time=0,Duration=math.clamp(direction.Magnitude/1200,.025,.22)})
end)
RunService.RenderStepped:Connect(function(dt)
 for i=#tracers,1,-1 do
  local t=tracers[i] t.Time+=dt
  if t.Time>=t.Duration then t.Part:Destroy() table.remove(tracers,i)
  else
   local p=t.Origin:Lerp(t.Target,t.Time/t.Duration)
   t.Part.CFrame=CFrame.lookAt(p,t.Target)
  end
 end
end)
