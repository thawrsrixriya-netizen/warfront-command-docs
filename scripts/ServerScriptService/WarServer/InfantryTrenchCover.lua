-- ServerScriptService.WarServer.InfantryTrenchCover  (ModuleScript)
local R=require(game.ReplicatedStorage.WarShared.TrenchRoutes)
local Navigation=require(script.Parent.InfantryNavigation)
local Natural=require(script.Parent.InfantryNaturalMovement)
local Rifle=require(script.Parent.InfantryRifleCombat)
local C={}
local Entry=require(script.Parent.InfantryTrenchEntry)
local Bunker=require(script.Parent.InfantryBunkerPatrol)
local Config=require(game.ReplicatedStorage.InfantryConfig)
local Posture=require(script.Parent.InfantryPosture)
local spacing=Config.TrenchSpacing
local rng=Random.new()
local occupiedCache,occupiedAt={},-math.huge
local function occupiedPositions()
 if os.clock()-occupiedAt<.2 then return occupiedCache end
 occupiedAt=os.clock() occupiedCache={}
 for _,m in workspace.CommandInfantry:GetChildren() do
  local root=m:FindFirstChild("HumanoidRootPart") local hum=m:FindFirstChildOfClass("Humanoid")
  if root and hum and hum.Health>0 and not m:GetAttribute("Embarked") and not m:GetAttribute("Moving")
   and (m:GetAttribute("InTrenchCover") or R.bodyInside(root.Position)) then
   table.insert(occupiedCache,{Model=m,Pos=root.Position})
  end
 end
 return occupiedCache
end
local reservations=setmetatable({},{__mode="k"})
local reservedSpacing=setmetatable({},{__mode="k"})
local physicalRoutes=setmetatable({},{__mode="k"})
local function physicalRoute(selected)
 local route=selected.Route
 if physicalRoutes[route] then return physicalRoutes[route] end
 local data={Route=route,Nodes={},Links={},Entries={}}
 for _,v in route:GetChildren() do if v:IsA("Vector3Value") then
  local id=tonumber(v.Name) data.Nodes[id]=v.Value data.Links[id]={}
  for n in (v:GetAttribute("Links") or ""):gmatch("%d+") do table.insert(data.Links[id],tonumber(n)) end
  if v:GetAttribute("Entry") then table.insert(data.Entries,id) end
 end end
 Bunker.extend(data)
 require(script.Parent.InfantryTrenchWalkGraph).validate(data)
 physicalRoutes[route]=data return data
end
local function flat(v) return Vector3.new(v.X,0,v.Z) end
function C.clear(st)
 st.Model:SetAttribute("TrenchRoaming",false)
 st.TrenchExit=nil st.Model:SetAttribute("TrenchExiting",nil)
 if not st.TrenchCover then return end
 st.TrenchExitUntil=os.clock()+12 st.TrenchExitOrigin=st.Pos
 reservations[st.Model]=nil reservedSpacing[st.Model]=nil st.TrenchCover=nil st.TrenchFollowing=nil
 st.Model:SetAttribute("TrenchCover",nil) st.Model:SetAttribute("InTrenchCover",nil)
 st.Model:SetAttribute("TrenchPhase",nil) st.Model:SetAttribute("TrenchTarget",nil) st.Model:SetAttribute("TrenchNext",nil)
 st.AutoPosture=true st.Model:SetAttribute("AutoPosture",true)
 Posture.set(st,"Standing")
end
function C.outsidePoint(point,used,floorAt)
 local function valid(p)
  local g=floorAt(p)
  if not g or R.groundInside(g) then return end
  for _,v in used do if flat(v-g).Magnitude<3 then return end end
  return g
 end
 local ground=valid(point) if ground then table.insert(used,ground) return ground end
 for _,radius in {3,6,9,12} do for i=0,7 do
  local a=i*math.pi/4
  ground=valid(point+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius))
  if ground then table.insert(used,ground) return ground end
 end end
end
function C.beginExit(st,goal)
 if R.groundInside(goal) then return false end
 local base=st.Pos-Vector3.new(0,st.Offset,0)
 local selected,id=R.pick(base)
 if not selected then return false end
 local data=physicalRoute(selected)
 local nearest=R.nearest(data,base)
 if math.abs(base.Y-data.Nodes[nearest].Y)>1.2 or R.distanceXZ(data,base)>1.7 then return false end
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.RespectCanCollide=true
 local skip={workspace.CommandInfantry}
 for _,player in game.Players:GetPlayers() do if player.Character then table.insert(skip,player.Character) end end
 rp.FilterDescendantsInstances=skip
 local toward=flat(goal-base) toward=toward.Magnitude>.1 and toward.Unit or Vector3.new(0,0,-1)
 local banks={}
 for _,angle in {0,45,-45,90,-90,135,-135,180} do
  local dir=CFrame.Angles(0,math.rad(angle),0):VectorToWorldSpace(toward)
  for _,distance in {2.5,4,6} do
   local p=base+dir*distance
   local h=workspace:Raycast(p+Vector3.new(0,6,0),Vector3.new(0,-10,0),rp)
   if h and h.Normal.Y>.7 and h.Position.Y>data.Nodes[nearest].Y+.9 and h.Position.Y<data.Nodes[nearest].Y+3
    and R.distanceXZ(data,h.Position)>1.4 then
    table.insert(banks,{Pos=h.Position,Score=distance+flat(h.Position-goal).Magnitude*.35})
   end
  end
 end
 if #banks==0 then return false end
 table.sort(banks,function(a,b)return a.Score<b.Score end)
 st.TrenchExit={Data=data,Goal=goal,Banks=banks,Index=1,Bank=banks[1].Pos,Best=math.huge,ProgressAt=os.clock()}
 st.TrenchFollowing=nil Posture.set(st,"Standing")
 st.Model:SetAttribute("TrenchExiting",true)
 Navigation.cancel(st) st.Version+=1 st.Planning=false st.Path={banks[1].Pos}
 return true
end
function C.updateExit(st)
 local exit=st.TrenchExit if not exit then return end
 local base=st.Pos-Vector3.new(0,st.Offset,0)
 local nearest=R.nearest(exit.Data,base)
 if base.Y-exit.Data.Nodes[nearest].Y>1.15 and R.distanceXZ(exit.Data,base)>1.4 then
  local goal=exit.Goal
  st.TrenchExit=nil st.TrenchExitUntil=nil st.TrenchExitOrigin=nil st.Model:SetAttribute("TrenchExiting",nil)
  Navigation.cancel(st) st.Version+=1 st.Path=nil st.Planning=false st.NavNextPlan=0
  Navigation.plan(st,goal)
  return
 end
 local remaining=flat(st.Pos-exit.Bank).Magnitude
 if remaining<exit.Best-.25 then exit.Best=remaining exit.ProgressAt=os.clock() end
 if os.clock()-exit.ProgressAt>2.5 then
  exit.Index=exit.Index%#exit.Banks+1 exit.Bank=exit.Banks[exit.Index].Pos exit.Best=math.huge exit.ProgressAt=os.clock()
  st.Path={exit.Bank}
 end
end
function C.order(members,point)
 local data,clicked=R.pick(point) if not data then return false,"Point at a trench" end
 data=physicalRoute(data)
 local entrances={}
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude
 local skip={workspace.CommandInfantry}
 for _,p in game.Players:GetPlayers() do if p.Character then table.insert(skip,p.Character) end end
 rp.FilterDescendantsInstances=skip rp.RespectCanCollide=true
 local lanes=Entry.lanes(data,rp)
 for id in lanes do table.insert(entrances,id) end
 if #entrances==0 then return false,"Trench entrances are obstructed" end
 local accessible={}
 for id in lanes do accessible[data.ComponentByNode[id]]=true end
 local candidates={} local chosen={}
 for id,pos in data.Nodes do if not data.BunkerNode[id] and accessible[data.ComponentByNode[id]] then table.insert(candidates,{Id=id,Pos=pos,Distance=flat(pos-point).Magnitude}) end end
 table.sort(candidates,function(a,b)return a.Distance<b.Distance end)
 local memberSet={} for _,st in members do memberSet[st.Model]=true end
 local orderSpacing=spacing
 for _,gap in {spacing+.6,7.5,6.5,5.5,4.5,3.5,2.4} do
  chosen={}
  for _,candidate in candidates do
   local free=true
   for model,pos in reservations do
    if not model.Parent or not model:FindFirstChildOfClass("Humanoid") or model.Humanoid.Health<=0 then reservations[model]=nil reservedSpacing[model]=nil
    elseif not memberSet[model] and flat(pos-candidate.Pos).Magnitude<math.max(gap,reservedSpacing[model] or spacing) then free=false break end
   end
   for _,p in chosen do if flat(p.Pos-candidate.Pos).Magnitude<gap then free=false break end end
   for _,other in occupiedPositions() do if not memberSet[other.Model] and flat(other.Pos-candidate.Pos).Magnitude<math.max(gap,reservedSpacing[other.Model] or spacing) then free=false break end end
   if free then table.insert(chosen,candidate) if #chosen==#members then break end end
  end
  if #chosen==#members then orderSpacing=math.min(spacing,gap-.2) break end
 end
 if #chosen<#members then return false,"Not enough free trench space for this squad" end
 local center=Vector3.zero for _,st in members do center+=st.Pos end center/=#members
 local usedEntries={}
 table.sort(members,function(a,b)return (a.Model:GetAttribute("SquadIndex") or 1)<(b.Model:GetAttribute("SquadIndex") or 1) end)
 for i,st in members do
  C.clear(st) Navigation.cancel(st) Rifle.stop(st)
  st.Version+=1 st.Path=nil st.Planning=false
  st.ManualTargetModel=nil st.AutoFiring=false st.AutoModel=nil
  Natural.move(st)
  Posture.set(st,"Standing",false)
  local target=chosen[i]
  local lane=Entry.best(lanes,st.Pos,target.Pos,nil,data)
  local entry=lane.Node
  local path=R.path(data,entry,target.Id)
  st.TrenchCover={Data=data,Spacing=orderSpacing,Target=target.Id,Entry=entry,Path=path,Phase="Approach",
   Entrances=entrances,EntranceLanes=lanes,EntryLane=lane,TriedEntries={[entry]=true},ProgressPos=st.Pos,ProgressAt=os.clock()}
  reservations[st.Model]=target.Pos reservedSpacing[st.Model]=orderSpacing
  st.Model:SetAttribute("TrenchCover",true) st.Model:SetAttribute("InTrenchCover",false)
  Navigation.plan(st,lane.Bank)
  st.DepartAt=os.clock()+(i-1)*.12
 end
 return true
end
local function freePosition(st,point,margin)
 local data=st.TrenchCover and st.TrenchCover.Data
 local bunker=data and Bunker.at(data,point)
 if data and not Bunker.free(st,data,point,reservations) then return false end
 local function required(p,model)
  if bunker and Bunker.at(data,p)==bunker then return 2.2 end
  return math.max(st.TrenchCover and st.TrenchCover.Spacing or spacing,reservedSpacing[model] or 0)+(margin or 0)
 end
 for model,p in reservations do if model~=st.Model and model.Parent and flat(point-p).Magnitude<required(p,model) then return false end end
 for _,other in occupiedPositions() do if other.Model~=st.Model and flat(point-other.Pos).Magnitude<required(other.Pos,other.Model) then return false end end
 return true
end
local function relocate(st,cover)
 if os.clock()-(cover.LastRelocate or -math.huge)<1.5 then return end
 cover.LastRelocate=os.clock()
 local best,score=nil,math.huge
 for id,point in cover.Data.Nodes do
  if id~=cover.Target and (not cover.Data.BunkerNode[id] or cover.Data.BunkerSlots[id]) and freePosition(st,point,.6) then
   local d=flat(point-st.Pos).Magnitude
   if d<score then best=id score=d end
  end
 end
 if not best then return end
 local start=R.nearest(cover.Data,st.Pos-Vector3.new(0,st.Offset,0))
 local path=R.path(cover.Data,start,best)
 if not path then return end
 cover.Target=best cover.Phase="Inside" reservations[st.Model]=cover.Data.Nodes[best]
 Posture.set(st,"Standing") st.Model:SetAttribute("InTrenchCover",false)
 st.Path={} for _,id in path do table.insert(st.Path,cover.Data.Nodes[id]) end
 cover.ProgressPos=st.Pos cover.ProgressAt=os.clock()
end
local function settle(st,cover)
 if not freePosition(st,st.Pos,0) then return false end
 Navigation.cancel(st) st.Path=nil st.Planning=false
 cover.Phase="Settled" Posture.set(st,"Standing",false)
 cover.PausedPath=nil cover.ResumeAt=nil
 cover.NextRoam=os.clock()+rng:NextNumber(Config.TrenchRoamPauseMin,Config.TrenchRoamPauseMax)
 st.Model:SetAttribute("TrenchPhase","Settled")
 st.Model:SetAttribute("TrenchRoaming",false)
 st.NextPosture=nil st.IdleSince=os.clock()
 st.Model:SetAttribute("InTrenchCover",true)
 reservations[st.Model]=st.Pos-Vector3.new(0,st.Offset,0)
 return true
end
local function startRoam(st,cover)
 cover.NextRoam=os.clock()+rng:NextNumber(Config.TrenchRoamPauseMin,Config.TrenchRoamPauseMax)
 if st.CommandStopped or st.AutoPosture==false or st.FireTarget or st.Planning or st.Path then return end
 local data=cover.Data local start=R.nearest(data,st.Pos-Vector3.new(0,st.Offset,0))
 -- Traverse the entire connected passage; reserve spacing at destinations only.
 local previous={[start]=false} local queue={start} local qi=1 local candidates={}
 while queue[qi] do
  local a=queue[qi] qi+=1
  for _,b in data.Links[a] do if data.Nodes[b] and previous[b]==nil then
   previous[b]=a table.insert(queue,b)
   if (not data.BunkerNode[b] or data.BunkerSlots[b]) and flat(data.Nodes[b]-st.Pos).Magnitude>=4 and freePosition(st,data.Nodes[b],.6) then table.insert(candidates,b) end
  end end
 end
 if #candidates==0 then return end
 local roomTargets,outsideTargets={},{}
 for _,id in candidates do
  table.insert(data.BunkerSlots[id] and roomTargets or outsideTargets,id)
 end
 -- Visit a room occasionally, then return to the open trench.
 local insideRoom=Bunker.at(data,st.Pos-Vector3.yAxis*st.Offset)
 local pool=candidates
 if insideRoom and #outsideTargets>0 then pool=outsideTargets
 elseif not insideRoom and #roomTargets>0 and rng:NextNumber()<.35 then pool=roomTargets
 elseif #outsideTargets>0 then pool=outsideTargets end
 local target=pool[rng:NextInteger(1,#pool)]

 local ids={target} local at=target
 while at~=start do at=previous[at] table.insert(ids,1,at) end
 Natural.move(st) Posture.set(st,"Standing",false)
 Navigation.cancel(st) st.Version+=1 st.Planning=false
 cover.Target=target cover.Phase="Roam" cover.ProgressAt=os.clock() cover.ProgressPos=st.Pos
 reservations[st.Model]=data.Nodes[target]
 st.Path={} for _,id in ids do table.insert(st.Path,data.Nodes[id]) end
 st.TrenchFollowing=true
 st.Model:SetAttribute("TrenchPhase","Roam") st.Model:SetAttribute("TrenchRoaming",true)
 st.Model:SetAttribute("InTrenchCover",false)
 st.Model:SetAttribute("TrenchRoamCount",(st.Model:GetAttribute("TrenchRoamCount") or 0)+1)
end
function C.pauseForFire(st)
 local cover=st.TrenchCover
 if not cover or (cover.Phase~="Roam" and not (cover.Phase=="Inside" and st.Model:GetAttribute("TrenchRoaming"))) then return end
 cover.PausedPath=st.Path st.Path=nil st.Planning=false
 cover.Phase="RoamPaused" cover.ResumeAt=nil
 st.Model:SetAttribute("TrenchPhase","RoamPaused")
 st.Model:SetAttribute("InTrenchCover",true) st.Model:SetAttribute("Moving",false)
 Posture.set(st,"Standing")
end
local function firingPosition(st,cover)
 if not st.FireTarget or st.CommandStopped or st.CeilingProne or os.clock()<(cover.NextFirePosition or 0) then return end
 cover.NextFirePosition=os.clock()+3
 local O=require(game.ReplicatedStorage.WarShared.InfantryOverhead)
 local Pose=require(game.ReplicatedStorage.InfantryRiflePose)
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude
 local skip={workspace.CommandInfantry}
 for _,p in game.Players:GetPlayers() do if p.Character then table.insert(skip,p.Character) end end
 for _,name in {"CommandTanks","ClientFX","WarFX"} do local f=workspace:FindFirstChild(name) if f then table.insert(skip,f) end end
 rp.FilterDescendantsInstances=skip
 local function clear(point)
  local cf=CFrame.new(point+Vector3.yAxis*st.Offset)*CFrame.Angles(0,st.Yaw,0)
  local gun=st.Model:GetAttribute("TrenchFireStyle")=="Normal"
   and O.normalFrame(st.Model,cf,st.FireTarget,Pose.frame(cf,0,st.FireTarget,0,st.Model:GetScale()))
   or O.frame(st.Model,cf,st.FireTarget)
  local delta=st.FireTarget-gun.Position
  if workspace:Raycast(cf.Position,gun.Position-cf.Position,rp) then return false end
  local hit=workspace:Raycast(gun.Position,delta,rp)
  if not hit then return true end
  local target=st.AutoModel or st.ManualTargetModel
  return target and hit.Instance:IsDescendantOf(target) or (hit.Position-st.FireTarget).Magnitude<1
 end
 local base=st.Pos-Vector3.yAxis*st.Offset
 if clear(base) then return end
 local start=R.nearest(cover.Data,base)
 local best,path,score=nil,nil,math.huge
 for id,p in cover.Data.Nodes do
  if not cover.Data.BunkerNode[id] and (p-base).Magnitude<Config.SquadSpreadRadius
   and freePosition(st,p,.6) and clear(p) then
   local ids=R.path(cover.Data,start,id)
   local cost=(p-base).Magnitude
   if ids and cost<score then best=id path=ids score=cost end
  end
 end
 if not best then return end
 Navigation.cancel(st) Natural.move(st) st.Version+=1 st.Planning=false st.TrenchFollowing=true
 cover.Target=best cover.Phase="Inside" reservations[st.Model]=cover.Data.Nodes[best]
 cover.ProgressAt=os.clock() cover.ProgressPos=st.Pos
 st.Path={} for _,id in path do table.insert(st.Path,cover.Data.Nodes[id]) end
 st.Model:SetAttribute("InTrenchCover",false)
end
function C.update(st)

 C.updateExit(st)
 local cover=st.TrenchCover if not cover then return end
 if not cover.Data.Route.Parent then C.clear(st) Navigation.cancel(st) st.Path=nil return end
 st.Model:SetAttribute("TrenchPhase",cover.Phase)
 st.Model:SetAttribute("TrenchTarget",cover.Data.Nodes[cover.Target])
 st.Model:SetAttribute("TrenchNext",st.Path and st.Path[1] or nil)
 local now=os.clock()
 if cover.Phase=="Settled" and now>=(cover.NextSpacingCheck or 0) then
  cover.NextSpacingCheck=now+.4
  if not freePosition(st,st.Pos,0) then relocate(st,cover) end
 end
 if cover.Phase=="Settled" then
  firingPosition(st,cover)
  cover.NextRoam=cover.NextRoam or now+rng:NextNumber(Config.TrenchRoamPauseMin,Config.TrenchRoamPauseMax)
  if now>=cover.NextRoam then startRoam(st,cover) end
 end
 if (cover.Phase=="Roam" or cover.Phase=="Inside" and st.Model:GetAttribute("TrenchRoaming")) and st.FireTarget then C.pauseForFire(st) end
 if cover.Phase=="RoamPaused" then
  if st.FireTarget then cover.ResumeAt=nil
  else
   cover.ResumeAt=cover.ResumeAt or now+rng:NextNumber(1,2)
   if now>=cover.ResumeAt then
    Natural.move(st) Posture.set(st,"Standing",false)
    st.Path=cover.PausedPath cover.PausedPath=nil cover.Phase="Roam"
    cover.ProgressAt=now cover.ProgressPos=st.Pos
    st.Model:SetAttribute("TrenchPhase","Roam") st.Model:SetAttribute("InTrenchCover",false)
   end
  end
  return
 end
 if cover.Phase=="Approach" then
  local remaining=flat(st.Pos-(cover.DirectEntry and cover.Data.Nodes[cover.Entry] or cover.EntryLane.Bank)).Magnitude
  cover.BestEntryDistance=cover.BestEntryDistance or remaining
  if remaining<cover.BestEntryDistance-.35 then cover.BestEntryDistance=remaining cover.ProgressAt=now end
 elseif st.Path and st.Path[1] then
  local waypoint=st.Path[1]
  local distance=flat(st.Pos-waypoint).Magnitude
  if not cover.ProgressWaypoint or (cover.ProgressWaypoint-waypoint).Magnitude>.1 then
   cover.ProgressWaypoint=waypoint cover.BestWaypointDistance=distance cover.ProgressAt=now
  elseif distance<(cover.BestWaypointDistance or math.huge)-.2 then
   cover.BestWaypointDistance=distance cover.ProgressAt=now
  end
 end
 if cover.Phase=="Approach" then
  local base=st.Pos-Vector3.new(0,st.Offset,0)
  local nearest=R.nearest(cover.Data,base)
  local node=cover.Data.Nodes[nearest]
  -- Recognize entering anywhere along the passage, including before the original entry waypoint.
  if flat(base-node).Magnitude<1.65 and math.abs(base.Y-node.Y)<1.25 then
   Navigation.cancel(st) st.Version+=1 st.Planning=false st.TrenchFollowing=true
   local ids=R.path(cover.Data,nearest,cover.Target)
   st.Path={} for _,id in ids or {} do table.insert(st.Path,cover.Data.Nodes[id]) end
   cover.Phase="Inside" cover.ProgressAt=now cover.ProgressPos=st.Pos
  elseif not cover.DirectEntry and flat(st.Pos-cover.EntryLane.Bank).Magnitude<1 then
   Navigation.cancel(st) st.Version+=1 st.Planning=false
   st.Path=table.clone(cover.EntryLane.Points) cover.DirectEntry=true
   cover.ProgressAt=now cover.BestEntryDistance=nil
  elseif now-cover.ProgressAt>3 then
   local lane=Entry.best(cover.EntranceLanes,st.Pos,cover.Data.Nodes[cover.Target],cover.TriedEntries,cover.Data)
   if lane then
    cover.Entry=lane.Node cover.EntryLane=lane cover.TriedEntries[lane.Node]=true
    cover.DirectEntry=false cover.BestEntryDistance=nil
    Navigation.cancel(st) st.Version+=1 st.Path=nil st.Planning=false st.NavNextPlan=0
    Navigation.plan(st,lane.Bank)
   end
   cover.ProgressAt=now
  end

 elseif cover.Phase=="Roam" then
  if not st.Path or now-cover.ProgressAt>3 then
   if not settle(st,cover) then relocate(st,cover) end
  end
 elseif cover.Phase=="Inside" then
  if not st.Path and flat(st.Pos-cover.Data.Nodes[cover.Target]).Magnitude<.65 then
   if not settle(st,cover) then relocate(st,cover) end
  elseif now-cover.ProgressAt>3 then
   -- Keep a valid position in the trench if decorative debris blocks the last few metres.
   if not settle(st,cover) then relocate(st,cover) end
  end
 end
end
function C.floor(st,p,fallback,params)
 local cover=st.TrenchCover
 if cover and (cover.Phase=="Roam" or st.Model:GetAttribute("TrenchRoaming")) then
  local corridor=R.distanceXZ(cover.Data,p)
  if corridor>.7 and corridor>=R.distanceXZ(cover.Data,st.Pos)-.01 then return nil end
  -- Infantry may pass each other while travelling; settle() keeps resting positions apart.
 end
 if st.TrenchExit then
  local data=st.TrenchExit.Data
  local nearest=R.nearest(data,p)
  local h=workspace:Raycast(p+Vector3.new(0,5,0),Vector3.new(0,-14,0),params())
  if h and h.Normal.Y>.15 and h.Position.Y<data.Nodes[nearest].Y+3 and h.Position.Y>data.Nodes[nearest].Y-.8 then return h.Position end
  return nil
 end
 if not st.TrenchFollowing then
  local cover=st.TrenchCover
  if cover and cover.Phase=="Approach" and cover.DirectEntry then
   return Entry.floor(p,st.Pos.Y-st.Offset,cover.Data.Nodes[cover.Entry].Y,params())
  end
  return fallback(p)
 end
 local wp=st.Path and st.Path[1]
 if not wp then return fallback(p) end
 -- Low bridges are ceilings, not the bottom of the trench.
 local hit=workspace:Raycast(Vector3.new(p.X,wp.Y+1.25,p.Z),Vector3.new(0,-3,0),params())
 if hit and hit.Normal.Y>.55 then return hit.Position end
end
return C
