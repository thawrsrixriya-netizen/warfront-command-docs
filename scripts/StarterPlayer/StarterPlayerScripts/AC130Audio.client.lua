-- StarterPlayer.StarterPlayerScripts.AC130Audio  (LocalScript)
-- AC-130 audio starts on the same event as each projectile.
local RS=game:GetService("ReplicatedStorage")
local Debris=game:GetService("Debris")
local FX=require(RS:WaitForChild("WarShared"):WaitForChild("FX"))
local remote=RS:WaitForChild("Remotes"):WaitForChild("CombatFX")
local definitions={
 Heavy={Name="AC130_105mm",Id="107308922606630",Volume=.65,Voices=4},
 Secondary={Name="AC130_40mm",Id="18754665604",Volume=.60,Voices=4},
 MG={Name="AC130_MG",Id="138382899505069",Volume=.07,Voices=6,Clip=.18},
}
local templates,active={},{}
for style,def in definitions do
 local sound=Instance.new("Sound")
 sound.Name=def.Name sound.SoundId="rbxassetid://"..def.Id sound.Volume=def.Volume
 sound.RollOffMode=Enum.RollOffMode.Linear
 sound.RollOffMinDistance=600 sound.RollOffMaxDistance=6000 sound.Looped=false
 if def.Clip then sound.PlaybackRegion=NumberRange.new(0,def.Clip) sound.PlaybackRegionsEnabled=true end
 sound.Parent=script templates[style]=sound active[style]={}
end
task.spawn(function()
 local preload={}
 for _,s in templates do table.insert(preload,s) end
 pcall(function()game:GetService("ContentProvider"):PreloadAsync(preload)end)
end)
remote.OnClientEvent:Connect(function(kind,origin,impact,travel,style)
 if kind~="Shell" or not definitions[style] or typeof(origin)~="Vector3" then return end
 local def=definitions[style] local playing=active[style]
 for i=#playing,1,-1 do if not playing[i].Parent then table.remove(playing,i) end end
 -- Keep both machine guns from piling up long audio tails.
 while #playing>=def.Voices do table.remove(playing,1):Destroy() end
 local emitter=FX.part({Name=def.Name.."_Audio",Size=Vector3.new(.1,.1,.1),Transparency=1,CFrame=CFrame.new(origin)})
 local sound=templates[style]:Clone() sound.Parent=emitter
 table.insert(playing,emitter)
 sound.Ended:Once(function()if emitter.Parent then emitter:Destroy()end end)
 sound.TimePosition=0
 sound:Play()
 if def.Clip then
  task.delay(def.Clip-.035,function()
   if sound.Parent then game:GetService("TweenService"):Create(sound,TweenInfo.new(.035),{Volume=0}):Play() end
  end)
  Debris:AddItem(emitter,def.Clip+.06)
 else Debris:AddItem(emitter,20) end
end)
