-- ServerScriptService.WarServer.InfantryService  (ModuleScript)
-- Infantry commands are validated and executed by the server.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local PathfindingService=game:GetService("PathfindingService")
local RS=game.ReplicatedStorage
local C=require(RS.InfantryConfig)
local Rifle=require(script.Parent.InfantryRifleCombat)
local Transport=require(script.Parent.InfantryTransport)
local Natural=require(script.Parent.InfantryNaturalMovement)
local Posture=require(script.Parent.InfantryPosture)
local Navigation=require(script.Parent.InfantryNavigation)
local TrenchCover=require(script.Parent.InfantryTrenchCover)
local Overhead=require(RS.WarShared.InfantryOverhead)
-- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
local Vision=require(script.Parent.VisionService)
local AutoFire=require(script.Parent.AutoFire)
local EnemyRegistry=require(RS.WarShared.EnemyRegistry)
-- [SHARED:Vision] END

local Remote=RS.Remotes.InfantryCommand
local Folder=workspace.CommandInfantry
local Template=game.ServerStorage.CommandInfantryTemplate
local Service={}
local units={}
local lastSpawn={} local lastCommand={}
local started=false
local function finite(v)
 return typeof(v)=="Vector3" and v.X==v.X and v.Y==v.Y and v.Z==v.Z and math.abs(v.X)<100000 and math.abs(v.Y)<100000 and math.abs(v.Z)<100000
end
local function owned(player)
 local out={}
 for model,st in units do if st.Owner==player and model.Parent and st.Humanoid.Health>0 then out[st.Slot]=model end end
 return out
end
local function message(player,text) if player.Parent then Remote:FireClient(player,"Message",text) end end
local function params()
 local rp=RaycastParams.new()
 rp.FilterType=Enum.RaycastFilterType.Exclude
 local exclude={Folder}
 local fx=workspace:FindFirstChild("ClientFX") if fx then table.insert(exclude,fx) end
 for _,p in Players:GetPlayers() do if p.Character then table.insert(exclude,p.Character) end end
 rp.FilterDescendantsInstances=exclude rp.RespectCanCollide=true
 return rp
end
local function floorAt(p)
 local hit=workspace:Raycast(p+Vector3.new(0,4,0),Vector3.new(0,-20,0),params())
 if hit and hit.Normal.Y>0.55 then return hit.Position end
end
local function crowded(pos,except)
 for model,st in units do
  if model~=except and model.Parent and not st.Embarked and (Vector3.new(pos.X,0,pos.Z)-Vector3.new(st.Pos.X,0,st.Pos.Z)).Magnitude<C.SoldierMinDistance then return true end
 end
 return false
end
local function spawnMember(player,p,yaw,slot,index)
 local ground=floorAt(p) if not ground then message(player,"Choose flat ground for infantry") return end
 if crowded(ground) then message(player,"Infantry cannot spawn on another soldier") return end
 local size=Vector3.new(1.6,2.3,1.05)
 local op=OverlapParams.new() op.FilterType=Enum.RaycastFilterType.Exclude
 local skip={Folder}
 if player.Character then table.insert(skip,player.Character) end
 op.FilterDescendantsInstances=skip op.RespectCanCollide=true
 if #workspace:GetPartBoundsInBox(CFrame.new(ground+Vector3.new(0,1.3,0)),size,op)>0 then message(player,"Spawn area is blocked") return end
 local model=Template:Clone()
 local root=model.HumanoidRootPart
 local humanoid=model.Humanoid
 for _,v in model:GetDescendants() do
  if v:IsA("BasePart") then v.Anchored=v==root v.CanCollide=false v.CanTouch=false v.Massless=v~=root end
 end
 humanoid.AutoRotate=false humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 humanoid.BreakJointsOnDeath=false
 model.Name=string.format("Infantry_%d_%d_%d",player.UserId,slot,index)
 model:SetAttribute("SquadIndex",index)
 model:SetAttribute("SquadSize",C.SquadSize)
 model:SetAttribute("OwnerUserId",player.UserId) model:SetAttribute("InfantrySlot",slot)
 model:SetAttribute("CommandInfantry",true) model:SetAttribute("Prone",false)
 local offset=3*model:GetScale()
 local pos=ground+Vector3.new(0,offset,0)
 model:PivotTo(CFrame.new(pos)*CFrame.Angles(0,yaw,0))
 model.Parent=Folder
 local st={Model=model,Owner=player,Slot=slot,Root=root,Humanoid=humanoid,Pos=pos,Yaw=yaw,Offset=offset,Version=0,Prone=false}

 model:SetAttribute("RifleAmmo",C.MagazineSize)
 Natural.init(st)
 units[model]=st
 -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 Vision.register(model,{Team="Player",Profile="Infantry",Group=player.UserId..":"..slot,
  GetYaw=function() return st.Yaw end,
  GetEye=function() if st.Embarked then return nil end return st.Pos+Vector3.new(0,st.Prone and -0.6 or Vision.profile("Infantry").EyeHeight,0) end,
  OnAttacked=function(from) -- the whole squad turns toward the shooter
   for _,o in units do if o.Owner==st.Owner and o.Slot==st.Slot then AutoFire.alert(o,from) end end
  end})
 -- [SHARED:Vision] END
 humanoid.Died:Connect(function() st.Path=nil st.Version+=1 task.delay(3,function() if model.Parent then model:Destroy() end end) end)
 Remote:FireClient(player,"Spawned",model,slot)
 return model
end
local function manualPosture(st,name)
 if name=="Crouch" then
  -- Kneeling is stationary: an explicit T command cancels any active movement.
  if st.TrenchCover and st.TrenchCover.Phase~="Settled" or st.TrenchExit then TrenchCover.clear(st) end
  Navigation.cancel(st) st.Version+=1 st.Path=nil st.Planning=false
  st.Model:SetAttribute("Moving",false)
  st.IdleTarget=nil
 end
 Posture.set(st,name,true)
end
local function resumeOrders(st)
 if st.CommandStopped then st.AutoPosture=true st.Model:SetAttribute("AutoPosture",true) st.NextPosture=nil end
 st.CommandStopped=false st.Model:SetAttribute("CommandStopped",false)
 if st.PausedReloadSeconds then
  st.Model:SetAttribute("RifleReloadUntil",workspace:GetServerTimeNow()+st.PausedReloadSeconds)
  st.PausedReloadSeconds=nil
 end
end
local function commandMember(player,action,p,model)
 local st=typeof(model)=="Instance" and units[model]
 if not st or st.Owner~=player or not model.Parent or st.Humanoid.Health<=0 then return end
 if action=="Move" or action=="ExitTrench" or action=="Fire" or action=="FireUnit" or action=="Watch" or action=="CancelWatch" then resumeOrders(st) end
 if action=="Move" or action=="ExitTrench" or action=="Stop" or action=="Fire" and not (st.TrenchCover and (st.TrenchCover.Phase=="Settled" or st.TrenchCover.Phase=="Roam" or st.TrenchCover.Phase=="RoamPaused" or st.Model:GetAttribute("TrenchRoaming"))) then TrenchCover.clear(st) end
 if action=="Watch" then
  if not finite(p) then return end
  local d=Vector3.new(p.X,0,p.Z)
  if d.Magnitude<.001 then return end
  st.WatchYaw=math.atan2(-d.X,-d.Z)
  model:SetAttribute("WatchYaw",st.WatchYaw)
  if st.FireTarget and not st.AutoFiring then
   local enemy=Vision.nearestVisible(st.FireTarget,10,"Player")
   Rifle.stop(st)
   if enemy then st.ManualTargetModel=enemy end
  end
 elseif action=="CancelWatch" then
  st.WatchYaw=nil
  model:SetAttribute("WatchYaw",nil)
  st.FaceTarget=nil
 elseif action=="Fire" then
  if not finite(p) then return end
  if (p-st.Pos).Magnitude>C.RifleRange then message(player,"Target out of range ("..C.RifleRange.." studs)") return end
  if (p-st.Pos).Magnitude<1 then return end
  -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
  st.AutoFiring=false st.ManualTargetModel=nil
  -- [SHARED:Vision] END
  TrenchCover.pauseForFire(st)
  Navigation.cancel(st) st.Version+=1 st.Path=nil st.Planning=false st.FireTarget=p Rifle.begin(st)
  Natural.settle(st,true)
  model:SetAttribute("FireActive",true) model:SetAttribute("FireTarget",p)
 -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 elseif action=="FireUnit" then
  if typeof(p)~="Instance" or not EnemyRegistry.isEnemyModel(p) then return end
  if st.FireTarget and not st.AutoFiring then Rifle.stop(st) end
  st.ManualTargetModel=p
  if model:GetAttribute("SquadIndex")==1 and not Vision.isVisible(p,"Player") then message(player,"Target not seen yet - get a unit close enough to see it") end
 -- [SHARED:Vision] END
 elseif action=="Prone" then
  st.AutoPosture=false model:SetAttribute("AutoPosture",false)
  manualPosture(st,Posture.next(st))
 elseif action=="Stop" then
  Rifle.stop(st)
  st.CommandStopped=true model:SetAttribute("CommandStopped",true)
  st.WatchYaw=nil st.FaceTarget=nil st.AlertPos=nil st.AlertUntil=0
  model:SetAttribute("WatchYaw",nil)
  st.IdleTarget=nil st.IdleAnchor=nil st.NextIdleAdjust=nil st.AimReadyAt=nil st.OverheadReadyAt=nil
  local reload=(model:GetAttribute("RifleReloadUntil") or 0)-workspace:GetServerTimeNow()
  if reload>0 then st.PausedReloadSeconds=reload model:SetAttribute("RifleReloadUntil",0) end
  Posture.set(st,"Standing",true)
  -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
  st.ManualTargetModel=nil st.AutoFiring=false st.AutoModel=nil
  -- [SHARED:Vision] END
  Navigation.cancel(st) st.Version+=1 st.Path=nil st.Planning=false Natural.settle(st,false) model:SetAttribute("Moving",false)
 elseif (action=="Move" or action=="ExitTrench") and finite(p) and (p-st.Pos).Magnitude<=C.MaxCommandDistance then
  local ground=floorAt(p) if not ground then message(player,"Choose reachable ground") return end
  Rifle.stop(st)
  st.Version+=1 st.Path=nil st.Planning=false Natural.move(st)
  if not TrenchCover.beginExit(st,ground) then Navigation.plan(st,ground) end
 end
end
-- [SHARED:Economy] BEGIN  (owner's money system, see doc "To ChatGPT" rule 2.4; do not change or remove)
local Economy=require(script.Parent.Economy)
-- [SHARED:Economy] END
function Service.Spawn(player,p,yaw,formation)
 formation=formation=="Line" and "Line" or "Dispersed"
 if not finite(p) or type(yaw)~="number" or yaw~=yaw or math.abs(yaw)>1e6 then return end
 -- [SHARED:Economy] BEGIN  (owner's money system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 if not Economy.canSummon(player,"Infantry") then return end
 -- [SHARED:Economy] END
 if os.clock()-(lastSpawn[player] or -math.huge)<C.SpawnCooldown then return end
 lastSpawn[player]=os.clock()
 local own=owned(player) local slot
 for n=1,C.MaxPerPlayer do if not own[n] then slot=n break end end
 if not slot then message(player,"Squad limit reached (3/3)") return end
 local created={}
 local spread=Natural.layout(C.SquadSize,formation,0)
 if not spread then message(player,"Cannot find enough squad spacing") return end
 local rotation=CFrame.Angles(0,yaw,0)
 for n=1,C.SquadSize do
  local x=spread[n].X
  local z=spread[n].Z
  local member=spawnMember(player,p+rotation:VectorToWorldSpace(Vector3.new(x,0,z)),yaw,slot,n)
  if not member then
   for _,unit in created do units[unit]=nil unit:Destroy() end
   message(player,"The whole 6-soldier squad needs more clear space")
   return
  end
  member:SetAttribute("SquadFormation",formation)
  table.insert(created,member)
 end
 -- [SHARED:Economy] BEGIN  (owner's money system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 Economy.chargeSummon(player,"Infantry")
 -- [SHARED:Economy] END
 return created[1]
end
function Service.Command(player,action,p,model,formationYawOverride)
 local leader=typeof(model)=="Instance" and units[model]
 if not leader or leader.Owner~=player or not model.Parent then return end
 if leader.Embarked then message(player,"Disembark from the BMP first") return end
 local members={} local center=Vector3.zero
 for unit,st in units do
  if st.Owner==player and st.Slot==leader.Slot and unit.Parent and st.Humanoid.Health>0 then
   if not st.Embarked then Transport.cancel(st) table.insert(members,st) center+=st.Pos end
  end
 end
 if #members==0 then return end center/=#members
 if action=="Trench" then
  if not finite(p) or (p-center).Magnitude>C.MaxCommandDistance then return end
  local ok,reason=TrenchCover.order(members,p) if ok then for _,st in members do resumeOrders(st) end else message(player,reason) end
  return
 end
 local exitingTrench=action=="ExitTrench"
 local exitDestinations={}
 if exitingTrench then action="Move" end
 local formation=leader.Model:GetAttribute("SquadFormation") or "Dispersed"
 if action=="FormationLine" or action=="FormationDispersed" then
  formation=action=="FormationLine" and "Line" or "Dispersed"
  for _,st in members do st.Model:SetAttribute("SquadFormation",formation) end
  action="Move"
  if not finite(p) then p=center end
 end
 local desiredPosture=Posture.next(leader)
 if desiredPosture=="Prone" then for _,st in members do if Posture.inTrench(st) then desiredPosture="Standing" break end end end
 local destinations
 if action=="Move" and finite(p) then
  local delta=p-center
  local formationYaw=Vector3.new(delta.X,0,delta.Z).Magnitude>.1 and math.atan2(-delta.X,-delta.Z) or leader.Yaw
  if type(formationYawOverride)=="number" and formationYawOverride==formationYawOverride and math.abs(formationYawOverride)<1e6 then formationYaw=formationYawOverride end
  destinations=Natural.layout(#members,formation,formationYaw)
  if not destinations then message(player,"Choose a wider destination") return end
 end
 table.sort(members,function(a,b)return (a.Model:GetAttribute("SquadIndex") or 1)<(b.Model:GetAttribute("SquadIndex") or 1) end)
 for _,st in members do
  if action=="Prone" then
   st.AutoPosture=false st.Model:SetAttribute("AutoPosture",false)
   manualPosture(st,desiredPosture)
  elseif action=="Move" and finite(p) then
   local best,bestDistance=1,math.huge
   local relative=Vector3.new(st.Pos.X-center.X,0,st.Pos.Z-center.Z)
   for n,offset in destinations do local d=(offset-relative).Magnitude if d<bestDistance then best=n bestDistance=d end end
   local offset=table.remove(destinations,best)
   local destination=p+offset
   if exitingTrench then destination=TrenchCover.outsidePoint(destination,exitDestinations,floorAt) end
   if destination then commandMember(player,exitingTrench and "ExitTrench" or action,destination,st.Model) end
  else commandMember(player,action,p,st.Model) end
 end
end
function Service.Init()
 if started then return end started=true
 Transport.init(units,commandMember)
 Remote.OnServerEvent:Connect(function(player,action,p,yaw,model)
  if type(action)~="string" then return end
  if action=="Spawn" then Service.Spawn(player,p,yaw,model) return end
  local now=os.clock()
  local key=lastCommand[player] or {Time=now,Count=0}
  if now-key.Time>1 then key.Time=now key.Count=0 end
  key.Count+=1 lastCommand[player]=key if key.Count>30 then return end
  Service.Command(player,action,p,model,yaw)
 end)
 local accumulator=0
 RunService.Heartbeat:Connect(function(dt)
  accumulator+=dt if accumulator<0.05 then return end
  dt=math.min(accumulator,0.15) accumulator=0
  for model,st in units do
   if not model.Parent then units[model]=nil continue end
   if st.Humanoid.Health<=0 then continue end
   if (st.Boarding or st.Embarked) and st.TrenchCover then TrenchCover.clear(st) Navigation.cancel(st) end
   if st.Embarked then Navigation.cancel(st) end

   if Transport.step(st) then continue end
   TrenchCover.update(st)
   Navigation.update(st)
   Natural.posture(st)
   if st.Crouched and (st.Path or st.Planning) then
    Posture.set(st,"Standing")
    st.DepartAt=math.max(st.DepartAt or 0,os.clock()+.4)
   end
   Posture.clearance(st)
   if not model:GetAttribute("LowCeiling") and Overhead.active(model) then Posture.set(st,"Standing") end
   Posture.sync(st)
   local speed=(st.Prone and C.CrawlSpeed or st.Crouched and C.CrouchSpeed or st.TrenchCover and st.TrenchCover.Phase=="Roam" and C.TrenchRoamSpeed or C.RunSpeed)*(st.SpeedMultiplier or 1)
   local moving=false
   while st.Path and st.Path[1] and (Vector3.new(st.Path[1].X,st.Pos.Y,st.Path[1].Z)-st.Pos).Magnitude<0.25 do
    table.remove(st.Path,1) if #st.Path==0 then st.Path=nil end
   end
   local wp=st.Path and st.Path[1]
   if wp and os.clock()>=(st.DepartAt or 0) then
    local delta=Vector3.new(wp.X-st.Pos.X,0,wp.Z-st.Pos.Z)
    if delta.Magnitude<0.25 then table.remove(st.Path,1) if #st.Path==0 then st.Path=nil end
    else
     local dir,spacingSpeed=delta.Unit,1
     if not st.TrenchFollowing and not (st.TrenchCover and st.TrenchCover.DirectEntry and st.TrenchCover.Phase=="Approach") then dir,spacingSpeed=Natural.steer(st,delta.Unit,units) end
     local targetYaw=math.atan2(-dir.X,-dir.Z)
     local err=(targetYaw-st.Yaw+math.pi)%(2*math.pi)-math.pi
     -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
     -- move and shoot: while aiming/alerted the soldier keeps facing the target and walks sideways
     if not (st.FireTarget or st.FaceTarget) then
     -- [SHARED:Vision] END
     st.Yaw+=math.clamp(err,-math.rad(C.TurnSpeed)*dt,math.rad(C.TurnSpeed)*dt)
     -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
     end
     -- [SHARED:Vision] END
     local distance=math.min(speed*spacingSpeed*dt,delta.Magnitude)
     local nextPos=Navigation.step(st,dir,distance,units,function(p) return TrenchCover.floor(st,p,floorAt,params) end,params)
     if nextPos then
      st.Pos=nextPos moving=true st.WaitSince=nil
     else
      st.WaitSince=st.WaitSince or os.clock()
     end
    end
   end
   if not wp and not st.NavGoal and not st.TrenchCover then
    local idleMoving=Natural.idle(st,dt,units,floorAt,params)
    if idleMoving then moving=true speed=st.Prone and .45 or .85 end
   end
   -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
   AutoFire.update(st,Rifle,"Infantry")
   local face=st.FireTarget or st.FaceTarget
   if face then
    local d=face-st.Pos
   -- [SHARED:Vision] END
    local desired=math.atan2(-d.X,-d.Z)
    local err=(desired-st.Yaw+math.pi)%(2*math.pi)-math.pi
    st.Yaw+=math.clamp(err,-math.rad(C.TurnSpeed)*dt,math.rad(C.TurnSpeed)*dt)
   end
   model:SetAttribute("Moving",moving)
   st.Root.CFrame=CFrame.new(st.Pos)*CFrame.Angles(0,st.Yaw,0)
   Rifle.step(st)
   Remote:FireAllClients("State",model,st.Root.CFrame,workspace:GetServerTimeNow(),moving,st.Prone,speed,st.Crouched==true)
  end
 end)
 Players.PlayerRemoving:Connect(function(player)
  lastSpawn[player]=nil lastCommand[player]=nil
  for model,st in units do if st.Owner==player then units[model]=nil model:Destroy() end end
 end)
end
return Service