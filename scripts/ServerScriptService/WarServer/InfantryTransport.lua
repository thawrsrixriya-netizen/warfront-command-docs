-- ServerScriptService.WarServer.InfantryTransport  (ModuleScript)
local RunService=game:GetService("RunService")
local RS=game.ReplicatedStorage
local Natural=require(script.Parent.InfantryNaturalMovement)
local Rifle=require(script.Parent.InfantryRifleCombat)
local M={}
local units,moveMember
local tanks=workspace:WaitForChild("CommandTanks")
local remote=RS.Remotes:WaitForChild("InfantryTransport")
local command=RS.Remotes.InfantryCommand
local capacity=6
local nextBoardAt={}
local unloading={}
local transferInterval=.6
local boardDuration=1.35
local doorOwner={}
local parkingEvent=script.Parent:FindFirstChild("BMPParkingRequest") or Instance.new("BindableEvent")
parkingEvent.Name="BMPParkingRequest" parkingEvent.Parent=script.Parent
local Navigation=require(script.Parent.InfantryNavigation)
local function message(p,text) command:FireClient(p,"Message",text) end
local function frame(tank)
 return CFrame.new(tank:GetAttribute("TankPos") or tank:GetPivot().Position)*CFrame.Angles(0,tank:GetAttribute("TankYaw") or 0,0)
end
local function valid(p,tank)
 return typeof(tank)=="Instance" and tank:IsA("Model") and tank.Parent==tanks and tank:GetAttribute("CommandTank") and tank:GetAttribute("OwnerUserId")==p.UserId
end
local function count(tank,reserved)
 local n=0
 for m,st in units do
  if m.Parent and st.Humanoid.Health>0 and (st.Embarked==tank or (reserved and st.Boarding==tank)) then n+=1 end
 end
 return n
end
local function publish(tank)
 if tank and tank.Parent then tank:SetAttribute("PassengerCount",count(tank,false)) tank:SetAttribute("PassengerCapacity",capacity) end
end
local function hide(st,hidden)
 if hidden then
  st.TransportSaved={}
  for _,v in st.Model:GetDescendants() do
   if v:IsA("BasePart") then st.TransportSaved[v]={v.Transparency,v.CanQuery,v.CanCollide} v.Transparency=1 v.CanCollide=false v.CanQuery=false
   elseif v:IsA("Decal") or v:IsA("Texture") then st.TransportSaved[v]={v.Transparency} v.Transparency=1 end
  end
 else
  for v,values in st.TransportSaved or {} do if v.Parent then v.Transparency=values[1] if v:IsA("BasePart") then v.CanCollide=values[3] v.CanQuery=values[2] end end end
  st.TransportSaved=nil
 end
end
local function approach(st,tank)
 local index=st.Model:GetAttribute("SquadIndex") or 1
 local length=tank:GetAttribute("TreeCollisionLength") or 10
 if st.BoardDoor then return frame(tank)*Vector3.new(-.78,0,length/2+.25) end
 return frame(tank)*Vector3.new(((index-1)%3-1)*1.8,0,length/2+1.5+math.floor((index-1)/3)*1.4)
end
local function enter(st,tank)
 st.Version+=1 st.Path=nil st.Planning=false st.IdleTarget=nil Rifle.stop(st)
 st.BoardAnim=nil st.BoardDoor=nil
 if doorOwner[tank]==st.Model then doorOwner[tank]=nil end
 st.Model:SetAttribute("BoardingClimb",false)
 st.Boarding=nil st.Embarked=tank st.LastCarrierFrame=frame(tank)
 st.Model:SetAttribute("Boarding",false) st.Model:SetAttribute("Embarked",true) st.Model:SetAttribute("Moving",false)
 local ref=st.Model:FindFirstChild("Carrier") or Instance.new("ObjectValue")
 ref.Name="Carrier" ref.Value=tank ref.Parent=st.Model
 hide(st,true) nextBoardAt[tank]=os.clock()+transferInterval publish(tank)
end
function M.cancel(st)
 st.EscortTank=nil st.Model:SetAttribute("Escorting",false)
 local tank=st.Boarding st.Boarding=nil st.BoardGoal=nil st.BoardAnim=nil st.BoardDoor=nil
 if tank and doorOwner[tank]==st.Model then doorOwner[tank]=nil end
 st.Model:SetAttribute("BoardingClimb",false)
 st.Model:SetAttribute("Boarding",false) publish(tank)
end
local function exitPoint(st,tank,cf,used,rearOnly)
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.RespectCanCollide=true
 local exclude={workspace.CommandInfantry} if tank then table.insert(exclude,tank) end
 rp.FilterDescendantsInstances=exclude
 local op=OverlapParams.new() op.FilterType=Enum.RaycastFilterType.Exclude op.FilterDescendantsInstances=exclude op.RespectCanCollide=true
 for n=1,60 do
  local row=math.floor((n-1)/10)
  local angle=(n-1)%10/10*math.pi*2
  local p=cf*Vector3.new(math.sin(angle)*(7+row*2),0,math.cos(angle)*(8+row*2))
  if rearOnly then
   local offsets={-.78,2,-3.5}
   p=cf*Vector3.new(offsets[(n-1)%3+1],0,(tank:GetAttribute("TreeCollisionLength") or 10)/2+3+math.floor((n-1)/3)*2.8)
  end
  local hit=workspace:Raycast(p+Vector3.new(0,10,0),Vector3.new(0,-40,0),rp)
  if hit and hit.Normal.Y>.6 then
   local g=hit.Position
   local clear=#workspace:GetPartBoundsInBox(CFrame.new(g+Vector3.new(0,1.3,0)),Vector3.new(1.7,2.2,1.1),op)==0
   for _,pos in used do if (pos-g).Magnitude<2.4 then clear=false break end end
   for m,other in units do if m~=st.Model and m.Parent and not other.Embarked and (other.Pos-(g+Vector3.new(0,st.Offset,0))).Magnitude<2 then clear=false break end end
   if clear then return g end
  end
 end
end
local function safeRear(st,tank,cf,needed)
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.RespectCanCollide=true
 rp.FilterDescendantsInstances={workspace.CommandInfantry,tank}
 local length=tank:GetAttribute("TreeCollisionLength") or 10
 local p=cf*Vector3.new(-.78,0,length/2+.8)
 local h=workspace:Raycast(p+Vector3.yAxis*6,Vector3.new(0,-15,0),rp)
 if not h or h.Normal.Y<.6 or math.abs(h.Position.Y-(cf.Position.Y-(tank:GetAttribute("GroundOffset") or st.Offset)))>st.Offset then return false end
 local used={}
 for i=1,needed do
  local ground=exitPoint(st,tank,cf,used,true)
  if not ground or math.abs(ground.Y-h.Position.Y)>st.Offset then return false end
  local origin=h.Position+Vector3.yAxis*1.3 local delta=ground-h.Position
  if delta.Magnitude>.01 and workspace:Blockcast(CFrame.lookAt(origin,origin+delta),Vector3.new(.7,2.2,.7),delta,rp) then return false end
  table.insert(used,ground)
 end
 return true
end
local function parkingPoint(st,tank,needed)
 local cf=frame(tank)
 if safeRear(st,tank,cf,needed) then return cf.Position end
 local length=tank:GetAttribute("TreeCollisionLength") or 10
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.RespectCanCollide=true
 rp.FilterDescendantsInstances={workspace.CommandInfantry,tank}
 for _,distance in {length,-length,length*2,-length*2} do
  local p=cf*Vector3.new(0,0,distance)
  local h=workspace:Raycast(p+Vector3.yAxis*10,Vector3.new(0,-40,0),rp)
  if not h or h.Normal.Y<.6 then continue end
  p=Vector3.new(p.X,h.Position.Y+(tank:GetAttribute("GroundOffset") or st.Offset),p.Z)
  local delta=p-cf.Position
  if workspace:Blockcast(cf+Vector3.yAxis*.2,Vector3.new((tank:GetAttribute("TreeCollisionWidth") or 5),1.3,length),delta,rp) then continue end
  local future=CFrame.new(p)*cf.Rotation
  if safeRear(st,tank,future,needed) then return p end
 end
end
local function discharge(st,tank,used,forced)

 local m=st.Model
 if not m.Parent or st.Embarked~=tank then return false end
 local cf=tank and tank.Parent and frame(tank) or st.LastCarrierFrame
 local ground=cf and exitPoint(st,tank,cf,used,not forced)
 if not ground then return false end
 table.insert(used,ground)
 st.Embarked=nil st.Version+=1 st.Path=nil st.Planning=false st.Prone=false
 m:SetAttribute("Embarked",false) m:SetAttribute("Prone",false) m:SetAttribute("Moving",false)
 local ref=m:FindFirstChild("Carrier") if ref then ref.Value=nil end
 if not forced and tank and tank.Parent then
  local length=tank:GetAttribute("TreeCollisionLength") or 10
  local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.RespectCanCollide=true
  rp.FilterDescendantsInstances={workspace.CommandInfantry,tank}
  local landingXZ=cf*Vector3.new(-.78,0,length/2+.8)
  local h=workspace:Raycast(landingXZ+Vector3.yAxis*6,Vector3.new(0,-15,0),rp)
  local landing=(h and h.Position or ground)+Vector3.yAxis*st.Offset
  local start=cf*Vector3.new(-.78,.2,length/2-.8)
  st.Disembarking=true st.Crouched=false st.CommandStopped=false
  m:SetAttribute("CommandStopped",false) m:SetAttribute("Crouched",false)
  m:SetAttribute("Disembarking",true) m:SetAttribute("DisembarkingClimb",true)
  m:SetAttribute("BoardingClimb",true)
  m:SetAttribute("BoardClimbStart",workspace:GetServerTimeNow()) m:SetAttribute("BoardClimbDuration",boardDuration)
  st.Pos=start st.Yaw=tank:GetAttribute("TankYaw") or 0
  st.Root.CFrame=CFrame.new(start)*CFrame.Angles(0,st.Yaw,0)
  hide(st,false) publish(tank)
  local begun=workspace:GetServerTimeNow()
  while m.Parent and st.Humanoid.Health>0 do
   local p=math.clamp((workspace:GetServerTimeNow()-begun)/boardDuration,0,1)
   local alpha=p*p*(3-2*p)
   local live=tank.Parent and frame(tank) or cf
   start=live*Vector3.new(-.78,.2,length/2-.8)
   st.Pos=start:Lerp(landing,alpha)+Vector3.yAxis*(math.sin(p*math.pi)*.12)
   st.Root.CFrame=CFrame.new(st.Pos)*CFrame.Angles(0,st.Yaw,0)
   command:FireAllClients("State",m,st.Root.CFrame,workspace:GetServerTimeNow(),false,false,0,false)
   if p>=1 then break end task.wait(.03)
  end
  m:SetAttribute("BoardingClimb",false) m:SetAttribute("DisembarkingClimb",false)
  -- Walk clear of the doorway before the next passenger is released.
  local from=st.Pos local goal=ground+Vector3.yAxis*st.Offset local walkStart=os.clock()
  local duration=math.max(.25,(goal-from).Magnitude/5)
  local delta=goal-from
  if Vector3.new(delta.X,0,delta.Z).Magnitude>.01 then st.Yaw=math.atan2(-delta.X,-delta.Z) end
  while m.Parent and st.Humanoid.Health>0 do
   local p=math.clamp((os.clock()-walkStart)/duration,0,1)
   st.Pos=from:Lerp(goal,p) st.Root.CFrame=CFrame.new(st.Pos)*CFrame.Angles(0,st.Yaw,0)
   m:SetAttribute("Moving",true)
   command:FireAllClients("State",m,st.Root.CFrame,workspace:GetServerTimeNow(),true,false,5,false)
   if p>=1 then break end task.wait(.03)
  end
  st.Disembarking=nil m:SetAttribute("Disembarking",false) m:SetAttribute("Moving",false)
 else hide(st,false) end
 st.Pos=ground+Vector3.new(0,st.Offset,0)
 st.Yaw=select(2,cf:ToOrientation())
 st.Root.CFrame=CFrame.new(st.Pos)*CFrame.Angles(0,st.Yaw,0)
 Natural.settle(st,false)
 command:FireAllClients("State",m,st.Root.CFrame,workspace:GetServerTimeNow(),false,false,0)
 publish(tank)
 return true
end
function M.unload(player,tank,forced)
 if not forced and not valid(player,tank) then return end
 if not forced and unloading[tank] then return end
 local list={}
 for m,st in units do
  if m.Parent and st.Embarked==tank then table.insert(list,st) end
  if st.Boarding==tank then M.cancel(st) st.Version+=1 st.Path=nil st.Planning=false end
 end
 if #list==0 then return end
 local parking
 if not forced then
  parking=parkingPoint(list[1],tank,#list)
  if not parking then message(player,"No safe rear exit nearby; move BMP to open ground") return end
 end
 table.sort(list,function(a,b)return (a.Model:GetAttribute("SquadIndex") or 1)<(b.Model:GetAttribute("SquadIndex") or 1) end)
 local function release()
  if not forced then
   local drive=require(RS.WarConfig).Tank
   local deadline=os.clock()+math.max(3,drive.MaxSpeed/math.max(drive.BrakeDecel,.1)+2)+(parking-frame(tank).Position).Magnitude/math.max(drive.MaxSpeed,1)
   while tank.Parent and not tank:GetAttribute("DisembarkStopped") and os.clock()<deadline do task.wait(.03) end
   if not tank.Parent or not tank:GetAttribute("DisembarkStopped") then
    unloading[tank]=nil
    if tank.Parent then tank:SetAttribute("ParkingForUnload",false) tank:SetAttribute("Unloading",false) end
    message(player,"BMP must stop before disembarking")
    return
   end
   -- Braking can change the exit position; validate the final stopped pose as well.
   if not safeRear(list[1],tank,frame(tank),#list) then
    local adjusted=parkingPoint(list[1],tank,#list)
    if adjusted and (adjusted-frame(tank).Position).Magnitude>.5 then
     tank:SetAttribute("DisembarkStopped",false) tank:SetAttribute("ParkingForUnload",true)
     parkingEvent:Fire(player,tank,adjusted)
     deadline=os.clock()+math.max(3,drive.MaxSpeed/math.max(drive.BrakeDecel,.1)+2)+(adjusted-frame(tank).Position).Magnitude/math.max(drive.MaxSpeed,1)
     while tank.Parent and not tank:GetAttribute("DisembarkStopped") and os.clock()<deadline do task.wait(.03) end
    end
    if not tank.Parent or not tank:GetAttribute("DisembarkStopped") or not safeRear(list[1],tank,frame(tank),#list) then
     unloading[tank]=nil
     if tank.Parent then tank:SetAttribute("ParkingForUnload",false) tank:SetAttribute("Unloading",false) end
     message(player,"No safe rear exit at the stopping position") return
    end
   end

  end
  local used={} local released=0
  for _,st in list do
   if discharge(st,tank,used,forced) then
    released+=1
    if not forced then task.wait(transferInterval) end
   end
  end
  publish(tank)
  if not forced then
   unloading[tank]=nil
   if tank.Parent then tank:SetAttribute("Unloading",false) end
   if released==0 and count(tank,false)>0 then message(player,"No clear space to disembark around BMP") end
  end
 end
 if forced then release()
 else
  unloading[tank]=true tank:SetAttribute("DisembarkStopped",false) tank:SetAttribute("Unloading",true)
  if (parking-frame(tank).Position).Magnitude>.5 then
   tank:SetAttribute("ParkingForUnload",true)
   parkingEvent:Fire(player,tank,parking)
  end
  task.spawn(release)
 end
end
function M.board(player,model,tank)
 if not valid(player,tank) then message(player,"Choose your own BMP") return end
 if unloading[tank] then message(player,"Wait for disembarking to finish") return end
 local leader=typeof(model)=="Instance" and units[model]
 if not leader or leader.Owner~=player or leader.Embarked then return end
 local list={}
 for m,st in units do if m.Parent and st.Owner==player and st.Slot==leader.Slot and st.Humanoid.Health>0 and not st.Embarked then table.insert(list,st) end end
 local already=0 for _,st in list do if st.Boarding==tank then already+=1 end end
 if #list==0 or count(tank,true)-already+#list>capacity then message(player,"BMP can carry only 6 soldiers") return end
 for _,st in list do
  M.cancel(st) Rifle.stop(st)
  st.AutoPosture=true st.Prone=false st.Model:SetAttribute("Prone",false)
  st.Boarding=tank st.BoardGoal=approach(st,tank)
  st.Model:SetAttribute("Boarding",true)
  moveMember(player,"Move",st.BoardGoal,st.Model)
 end
 publish(tank)
end
local escortRandom=Random.new()
function M.escort(player,model,tank)
 if not valid(player,tank) or unloading[tank] then return end
 local leader=typeof(model)=="Instance" and units[model]
 if not leader or leader.Owner~=player or leader.Embarked or leader.Disembarking then return end
 local config=require(RS.InfantryConfig) local chosen={} local offsets={}
 local width=tank:GetAttribute("TreeCollisionWidth") or 5
 local length=tank:GetAttribute("TreeCollisionLength") or 10
 for m,st in units do if m.Parent and st.Owner==player and st.Slot==leader.Slot and st.Humanoid.Health>0 and not st.Embarked then table.insert(chosen,st) end end
 for _,st in chosen do
  local offset
  for attempt=1,180 do
   local p=Vector3.new(escortRandom:NextNumber(-config.SquadSpreadRadius,config.SquadSpreadRadius),0,escortRandom:NextNumber(0,config.SquadSpreadRadius*1.5))
   if math.abs(p.X)<width*.5+config.SquadMinSpacing*.5 and p.Z<length*.5+config.SquadMinSpacing*.5 then continue end
   local free=true for _,v in offsets do if (v-p).Magnitude<config.SquadMinSpacing then free=false break end end
   if free then offset=p break end
  end
  if not offset then message(player,"Choose more open ground around BMP") return end
  table.insert(offsets,offset)
 end
 for i,st in chosen do
  M.cancel(st) Rifle.stop(st)
  st.EscortTank=tank st.EscortNext=0 st.EscortGoal=nil st.EscortOffset=offsets[i]
  st.EscortPauseUntil=nil st.EscortNextPause=os.clock()+config.ReloadTime st.CommandStopped=false
  st.Model:SetAttribute("CommandStopped",false) st.Model:SetAttribute("Escorting",true)
 end
end
local function escortStep(st)
 local tank=st.EscortTank if not tank then return end
 if not valid(st.Owner,tank) or st.CommandStopped then M.cancel(st) return end
 local config=require(RS.InfantryConfig)
 local goal=frame(tank)*(st.EscortOffset or Vector3.new(0,0,config.SquadSpreadRadius))
 local d=Vector3.new(goal.X-st.Pos.X,0,goal.Z-st.Pos.Z).Magnitude
 local now=os.clock()
 if st.EscortPauseUntil and now<st.EscortPauseUntil then return end
 if st.EscortPauseUntil then st.EscortPauseUntil=nil st.EscortGoal=nil end
 -- Most soldiers fire on the move; an occasional short pause never diverts them into a trench.
 if st.FireTarget and now>=(st.EscortNextPause or 0) then
  st.EscortNextPause=now+config.ReloadTime+config.SemiPauseMax
  if d<config.SquadMinSpacing*2 and escortRandom:NextNumber()<.1 then
   st.EscortPauseUntil=now+escortRandom:NextNumber(config.SemiShotMin,config.SemiShotMax)
   Navigation.cancel(st) st.Path=nil st.Planning=false st.Model:SetAttribute("Moving",false)
   return
  end
 end
 if now<(st.EscortNext or 0) then return end st.EscortNext=now+.5
 local movedGoal=not st.EscortGoal or (goal-st.EscortGoal).Magnitude>config.SoldierMinDistance
 if d>config.SoldierMinDistance and (movedGoal or not st.Path and not st.Planning) then
  require(script.Parent.InfantryTrenchCover).clear(st)
  moveMember(st.Owner,"Move",goal,st.Model) st.EscortGoal=goal
 end
end
function M.step(st)
 escortStep(st)

 if st.Disembarking then return true end
 if st.Embarked then
  local tank=st.Embarked
  if not tank.Parent then M.unload(st.Owner,tank,true) return st.Embarked~=nil end
  st.LastCarrierFrame=frame(tank) st.Pos=st.LastCarrierFrame.Position st.Root.CFrame=st.LastCarrierFrame
  return true
 end
 if st.Boarding then
  local tank=st.Boarding
  if not valid(st.Owner,tank) then M.cancel(st) return false end
  if st.BoardAnim then
   local progress=math.clamp((workspace:GetServerTimeNow()-st.BoardAnim.Start)/boardDuration,0,1)
   local alpha=progress*progress*(3-2*progress)
   local cf=frame(tank)
   local length=tank:GetAttribute("TreeCollisionLength") or 10
   local destination=Vector3.new(0,st.BoardAnim.From.Y+.18,length/2-1)
   local relative=st.BoardAnim.From:Lerp(destination,alpha)+Vector3.yAxis*(math.sin(progress*math.pi)*.32)
   st.Pos=cf*relative st.Yaw=tank:GetAttribute("TankYaw") or 0
   st.Root.CFrame=CFrame.new(st.Pos)*CFrame.Angles(0,st.Yaw,0)
   command:FireAllClients("State",st.Model,st.Root.CFrame,workspace:GetServerTimeNow(),false,false,0,false)
   if progress>=1 then enter(st,tank) end
   return true
  end
  local goal=approach(st,tank)
  local now=os.clock() local dt=math.clamp(now-(st.LastTransportStep or now-.05),0,.15) st.LastTransportStep=now
  local owner=doorOwner[tank]
  if owner and (not owner.Parent or not owner:GetAttribute("Boarding") or owner:FindFirstChildOfClass("Humanoid").Health<=0) then doorOwner[tank]=nil end
  if st.BoardDoor then
   local d=Vector3.new(st.Pos.X-goal.X,0,st.Pos.Z-goal.Z).Magnitude
   if d>=.4 then
    Navigation.cancel(st) st.Version+=1 st.Planning=false st.Path={goal} st.BoardGoal=goal
    return false
   end
  end
  local d=Vector3.new(st.Pos.X-goal.X,0,st.Pos.Z-goal.Z).Magnitude
  if d<(st.BoardDoor and .4 or .75) then
   if not st.BoardDoor then
    if not doorOwner[tank] and os.clock()>=(nextBoardAt[tank] or 0) then
     doorOwner[tank]=st.Model st.BoardDoor=true
     Navigation.cancel(st) st.Version+=1 st.Planning=false st.Path={approach(st,tank)}
    else st.Path=nil st.Planning=false end
    return false
   end
   local yaw=tank:GetAttribute("TankYaw") or 0
   local err=(yaw-st.Yaw+math.pi)%(2*math.pi)-math.pi
   st.Yaw+=math.clamp(err,-math.rad(240)*dt,math.rad(240)*dt)
   st.Root.CFrame=CFrame.new(st.Pos)*CFrame.Angles(0,st.Yaw,0)
   if math.abs(err)>math.rad(8) then
    st.Path=nil st.Planning=false st.Model:SetAttribute("Moving",false)
    command:FireAllClients("State",st.Model,st.Root.CFrame,workspace:GetServerTimeNow(),false,false,0,false)
    return true
   end
   st.Path=nil st.Planning=false st.Model:SetAttribute("Moving",false)
   command:FireAllClients("State",st.Model,st.Root.CFrame,workspace:GetServerTimeNow(),false,st.Prone,0)
   if os.clock()>=(nextBoardAt[tank] or 0) then
    local start=workspace:GetServerTimeNow()
    st.Version+=1 st.Path=nil st.Planning=false st.IdleTarget=nil Rifle.stop(st)
    st.Prone=false st.Crouched=false st.Model:SetAttribute("Prone",false) st.Model:SetAttribute("Crouched",false)
    st.BoardAnim={Start=start,From=frame(tank):PointToObjectSpace(st.Pos)}
    st.Model:SetAttribute("BoardClimbStart",start) st.Model:SetAttribute("BoardClimbDuration",boardDuration)
    st.Model:SetAttribute("BoardingClimb",true)
    nextBoardAt[tank]=os.clock()+boardDuration+.15
    return true
   end

   return true
  end
  if os.clock()-(st.LastBoardPlan or 0)>1 and (not st.Path and not st.Planning or (goal-st.BoardGoal).Magnitude>2) then
   st.LastBoardPlan=os.clock() st.BoardGoal=goal moveMember(st.Owner,"Move",goal,st.Model)
  end
 end
 return false
end
function M.init(all,callback)
 units=all moveMember=callback
 remote.OnServerEvent:Connect(function(player,action,model,tank)
  if action=="Escort" then M.escort(player,model,tank)
  elseif action=="Board" then M.board(player,model,tank)
  elseif action=="Unload" then M.unload(player,model,false) end
 end)
 local timer=0
 RunService.Heartbeat:Connect(function(dt)
  timer+=dt if timer<.3 then return end timer=0
  for _,tank in tanks:GetChildren() do if tank:GetAttribute("CommandTank") then publish(tank) end end
 end)
end
return M