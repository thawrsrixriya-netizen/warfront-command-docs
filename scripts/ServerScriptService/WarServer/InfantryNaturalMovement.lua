-- ServerScriptService.WarServer.InfantryNaturalMovement  (ModuleScript)
local C=require(game.ReplicatedStorage.InfantryConfig)
local M={}
local Posture=require(script.Parent.InfantryPosture)
local rng=Random.new()
function M.scatter(count)
 local positions={}
 for i=1,count do
  local accepted
  for attempt=1,180 do
   local angle=rng:NextNumber(0,math.pi*2)
   local radius=math.sqrt(rng:NextNumber(.08,1))*C.SquadSpreadRadius
   local p=Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
   local clear=true
   for _,v in positions do if (p-v).Magnitude<C.SquadMinSpacing then clear=false break end end
   if clear then accepted=p break end
  end
  if not accepted then
   local a=(i-1)*math.pi*2/count
   accepted=Vector3.new(math.cos(a),0,math.sin(a))*C.SquadSpreadRadius
   for _,v in positions do if (accepted-v).Magnitude<C.SquadMinSpacing then return nil end end
  end
  table.insert(positions,accepted)
 end
 return positions
end
function M.layout(count,kind,yaw)
 local offsets
 if kind=="Line" then
  offsets={}
  for i=1,count do
   local x=(i-(count+1)/2)*C.LineSpacing+rng:NextNumber(-.3,.3)
   local z=rng:NextNumber(-1.2,1.2)
   table.insert(offsets,Vector3.new(x,0,z))
  end
 else offsets=M.scatter(count) end
 if not offsets then return nil end
 local rotation=CFrame.Angles(0,yaw or 0,0)
 for i,p in offsets do offsets[i]=rotation:VectorToWorldSpace(p) end
 return offsets
end
function M.init(st)
 st.SpeedMultiplier=rng:NextNumber(.9,1.08)
 st.AutoPosture=true
 st.IdleDelay=rng:NextNumber(1.5,3)
 st.Model:SetAttribute("AutoPosture",true)
 st.Model:SetAttribute("SpeedMultiplier",st.SpeedMultiplier)
end
function M.move(st)
 local standFirst=st.Crouched
 st.DepartAt=os.clock()+(standFirst and .4 or rng:NextNumber(0,.45))
 st.IdleSince=nil st.WaitSince=nil st.NextIdleAdjust=nil st.IdleAnchor=nil st.IdleTarget=nil
 if st.Crouched or st.AutoPosture~=false then Posture.set(st,"Standing") end
end
function M.settle(st,firing)
 st.Planning=false st.NextPosture=nil
 if st.AutoPosture~=false then st.AutoPosture=true st.Model:SetAttribute("AutoPosture",true) end
 st.IdleSince=os.clock()
 st.IdleDelay=firing and rng:NextNumber(.35,1.1) or rng:NextNumber(1.5,3)
end
function M.posture(st)
 if st.CommandStopped or st.AutoPosture==false then return end
 if st.Path or st.Planning then
  st.IdleSince=nil st.NextPosture=nil st.IdleTarget=nil st.IdleAnchor=nil
  Posture.set(st,"Standing")
  return
 end
 local now=os.clock()
 st.IdleSince=st.IdleSince or now
 if now-st.IdleSince<st.IdleDelay then return end
 local inside=Posture.inTrench(st)
 if inside and st.FireTarget then
  Posture.set(st,"Standing")
  return
 end
 if not st.NextPosture or now>=st.NextPosture then
  local roll=rng:NextNumber()
  if inside then
   st.IdleWanted=roll<.5 and "Crouch" or "Standing"
  elseif st.FireTarget then
   st.IdleWanted=roll<.5 and "Prone" or roll<.8 and "Crouch" or "Standing"
  else
   st.IdleWanted=roll<.35 and "Standing" or roll<.7 and "Crouch" or "Prone"
  end
  st.NextPosture=now+rng:NextNumber(C.AutoPostureMin,C.AutoPostureMax)
 end
 if inside and st.IdleWanted=="Prone" then st.IdleWanted="Standing" end
 if not st.CeilingProne and Posture.name(st)~=st.IdleWanted then Posture.set(st,st.IdleWanted) end
end
function M.idle(st,dt,units,floorAt,params)
 if st.Crouched or st.CommandStopped then st.IdleTarget=nil return false end
 if st.Model:GetAttribute("SquadFormation")=="Line" then st.IdleTarget=nil return false end
 if st.Path or st.Planning or st.FireTarget then st.IdleTarget=nil return false end
 local now=os.clock()
 st.IdleAnchor=st.IdleAnchor or st.Pos
 st.NextIdleAdjust=st.NextIdleAdjust or (now+rng:NextNumber(4,9))
 if not st.IdleTarget and now>=st.NextIdleAdjust then
  st.NextIdleAdjust=now+rng:NextNumber(5,11)
  local angle=rng:NextNumber(0,math.pi*2)
  local radius=rng:NextNumber(.45,1.15)
  st.IdleTarget=st.IdleAnchor+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
 end
 if not st.IdleTarget then return false end
 local delta=Vector3.new(st.IdleTarget.X-st.Pos.X,0,st.IdleTarget.Z-st.Pos.Z)
 if delta.Magnitude<.06 then st.IdleTarget=nil return false end
 local distance=math.min(delta.Magnitude,(st.Prone and .45 or .85)*dt)
 local nextPos=st.Pos+delta.Unit*distance
 for model,other in units do
  if model~=st.Model and model.Parent and not other.Embarked and other.Humanoid.Health>0 then
   if (Vector3.new(nextPos.X,0,nextPos.Z)-Vector3.new(other.Pos.X,0,other.Pos.Z)).Magnitude<C.SquadMinSpacing*.85 then
    st.IdleTarget=nil return false
   end
  end
 end
 local ground=floorAt(nextPos-Vector3.new(0,st.Offset,0))
 local origin=st.Pos+Vector3.new(0,st.Prone and -.85 or -.15,0)
 local box=st.Prone and Vector3.new(.8,.4,1.5) or Vector3.new(.7,1.5,.65)
 if not ground or workspace:Blockcast(CFrame.new(origin),box,delta.Unit*distance,params()) then st.IdleTarget=nil return false end
 st.Pos=ground+Vector3.new(0,st.Offset,0)
 st.Model:SetAttribute("IdleAdjustments",(st.Model:GetAttribute("IdleAdjustments") or 0)+1)
 return true
end
function M.steer(st,direction,units)
 return direction,1
end
return M