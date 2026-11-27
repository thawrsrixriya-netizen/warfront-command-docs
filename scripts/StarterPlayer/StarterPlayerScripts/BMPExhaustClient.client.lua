-- StarterPlayer.StarterPlayerScripts.BMPExhaustClient  (LocalScript)
-- Dynamic diesel exhaust: light idle, dark under load, brief occasional soot on acceleration.
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local C=require(RS:WaitForChild("WarConfig")).Tank
local folder=workspace:WaitForChild("CommandTanks")
local states={}
folder.ChildRemoved:Connect(function(model) states[model]=nil end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<0.2 then return end
 local interval=elapsed
 elapsed=0
 local now=os.clock()
 for _,model in ipairs(folder:GetChildren()) do
  local emitter=model:FindFirstChild("BMPExhaustSmoke",true)
  local pos=model:GetAttribute("TankPos")
  if emitter and pos then
   local st=states[model]
   if not st then
    st={Position=pos,Throttle=0,Speed=0,Soot=0,PuffUntil=0,NextPuff=0,Rng=Random.new()}
    states[model]=st
   end
   local distance=(pos-st.Position).Magnitude
   local speed=distance<20 and distance/interval or st.Speed
   local acceleration=(speed-st.Speed)/interval
   local accelerating=acceleration>2 and speed>0.8
   if accelerating and not st.Accelerating and now>=st.NextPuff then
    st.NextPuff=now+st.Rng:NextNumber(4,7)
    if st.Rng:NextNumber()<0.55 then st.PuffUntil=now+st.Rng:NextNumber(0.55,1.05) end
   end
   if speed<0.3 then st.PuffUntil=0 end
   local throttle=math.clamp(speed/(C.MaxSpeed or 16),0,1)
   st.Throttle+=(throttle-st.Throttle)*math.min(1,interval*4)
   local sootTarget=(now<st.PuffUntil and speed>0.3) and 1 or 0
   st.Soot+=(sootTarget-st.Soot)*math.min(1,interval*5)
   local load=st.Throttle
   local grey=205-45*load
   grey=grey+(115-grey)*st.Soot
   local opacity=math.clamp(0.73-0.25*load-0.10*st.Soot,0.25,0.85)
   emitter.Enabled=true
   emitter.Color=ColorSequence.new(Color3.fromRGB(grey,grey,grey),Color3.fromRGB(grey+22,grey+22,grey+22))
   emitter.Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,opacity),
    NumberSequenceKeypoint.new(0.55,math.min(0.9,opacity+0.12)),
    NumberSequenceKeypoint.new(1,1)})
   emitter.Rate=8+18*load+10*st.Soot
   emitter.Speed=NumberRange.new(0.7+load,1.5+2*load)
   emitter:SetAttribute("ExhaustMode",st.Soot>0.4 and "SootPuff" or (load>0.12 and "Driving" or "Idle"))
   st.Position=pos
   st.Speed=speed
   st.Accelerating=accelerating
  end
 end
end)
