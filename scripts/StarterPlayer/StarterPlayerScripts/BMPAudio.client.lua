-- StarterPlayer.StarterPlayerScripts.BMPAudio  (LocalScript)
-- Spatial BMP audio follows the hull rendered on this client.
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local ContentProvider=game:GetService("ContentProvider")
local C=require(RS:WaitForChild("WarConfig")).Tank
local folder=workspace:WaitForChild("CommandTanks")
local tracked={}
local preload=Instance.new("Sound")
if type(C.MainGunSoundId)=="string" then preload.SoundId=C.MainGunSoundId end
task.spawn(function()
 pcall(function() ContentProvider:PreloadAsync({preload}) end)
 preload:Destroy()
end)
local function attach(model)
 if tracked[model] or not model:IsA("Model") then return end
 local hull=model:FindFirstChild("Hull")
 local part=hull and hull:FindFirstChildWhichIsA("BasePart",true)
 local deadline=os.clock()+10
 while not part and model.Parent and os.clock()<deadline do
  task.wait(0.1)
  hull=model:FindFirstChild("Hull")
  part=hull and hull:FindFirstChildWhichIsA("BasePart",true)
 end
 if not part or not model.Parent or tracked[model] then return end
 if type(C.EngineSoundId)~="string" or type(C.MovementSoundId)~="string" then warn("[BMPAudio] Missing engine/movement IDs in WarConfig.Tank"); return end
 local sound=Instance.new("Sound")
 sound.Name="BMPEngine"
 sound.SoundId=C.EngineSoundId
 sound.Looped=true
 sound.Volume=0.05
 sound.PlaybackSpeed=0.85
 sound.RollOffMinDistance=20
 sound.RollOffMaxDistance=300
 sound.Parent=part
 local movement=Instance.new("Sound")
 movement.Name="BMPMovement"
 movement.SoundId=C.MovementSoundId
 movement.Looped=true
 movement.Volume=0
 movement.RollOffMinDistance=15
 movement.RollOffMaxDistance=250
 movement.Parent=part
 tracked[model]={Sound=sound,Movement=movement,Position=model:GetAttribute("TankPos"),Speed=0}

 sound:Play()
end
for _,m in folder:GetChildren() do attach(m) end
folder.ChildAdded:Connect(function(m) task.defer(attach,m) end)
folder.DescendantAdded:Connect(function(instance)
 if not instance:IsA("BasePart") then return end
 local model=instance
 while model.Parent and model.Parent~=folder do model=model.Parent end
 if model.Parent==folder and not tracked[model] then task.defer(attach,model) end
end)
folder.ChildRemoved:Connect(function(m)
 local state=tracked[m]
 if state then state.Sound:Destroy(); state.Movement:Destroy(); tracked[m]=nil end
end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<0.1 then return end
 local interval=elapsed
 elapsed=0
 for model,state in pairs(tracked) do
  local pos=model:GetAttribute("TankPos")
  if pos and state.Position then
   local speed=(pos-state.Position).Magnitude/interval
   state.Speed+=(speed-state.Speed)*math.min(1,interval*5)
   local throttle=math.clamp(state.Speed/C.MaxSpeed,0,1)
   state.Sound.Volume=0.05+0.06*throttle
   state.Sound.PlaybackSpeed=0.85+0.3*throttle
   local movement=state.Movement
   local moving=speed>0.3
   local target=moving and (0.035+0.075*throttle) or 0
   movement.Volume+=(target-movement.Volume)*math.min(1,interval*8)
   movement.PlaybackSpeed=0.9+0.2*throttle
   if moving and not movement.IsPlaying then movement:Play() end
   if not moving and movement.Volume<0.001 then movement:Pause(); movement.Volume=0 end

  end
  state.Position=pos
 end
end)
