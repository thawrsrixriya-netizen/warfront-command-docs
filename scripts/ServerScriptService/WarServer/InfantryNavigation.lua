-- ServerScriptService.WarServer.InfantryNavigation  (ModuleScript)
local Pathfinding=game:GetService("PathfindingService")
local C=require(game.ReplicatedStorage.InfantryConfig)
local N={}
local function flat(v) return Vector3.new(v.X,0,v.Z) end
function N.plan(st,goal)
 st.NavGoal=goal st.NavRetry=0 st.NavProgressPos=st.Pos st.NavProgressAt=os.clock()
 N.repath(st)
end
function N.repath(st)
 local now=os.clock()
 if st.Planning or not st.NavGoal or now<(st.NavNextPlan or 0) then return end
 st.NavNextPlan=now+1.2 st.Planning=true
 local version=st.Version local goal=st.NavGoal
 task.spawn(function()
  local path=Pathfinding:CreatePath({AgentRadius=math.max(.9,C.AgentRadius),AgentHeight=math.max(3,C.AgentHeight),AgentCanJump=false,WaypointSpacing=4})
  local ok=pcall(function() path:ComputeAsync(st.Pos-Vector3.new(0,st.Offset-.1,0),goal) end)
  if st.Version~=version or not st.Model.Parent or st.NavGoal~=goal then return end
  st.Planning=false
  if st.NavBlocked then st.NavBlocked:Disconnect() st.NavBlocked=nil end
  if ok and path.Status==Enum.PathStatus.Success then
   local points={} for _,wp in path:GetWaypoints() do table.insert(points,wp.Position) end
   st.Path=points st.NavRetry=0
   st.NavBlocked=path.Blocked:Connect(function() st.NavNextPlan=math.min(st.NavNextPlan,os.clock()+.2) st.NavNeedsPlan=true end)
  else
   st.NavRetry=(st.NavRetry or 0)+1 st.NavNeedsPlan=true st.NavNextPlan=os.clock()+math.min(4,1+st.NavRetry)
   -- A safe local step can still reach nearby ground missing from the navigation mesh.
   if not st.Path then st.Path={goal} end
  end
 end)
end
function N.cancel(st)
 st.NavGoal=nil st.NavNeedsPlan=nil st.NavProgressPos=nil st.NavRetry=0
 if st.NavBlocked then st.NavBlocked:Disconnect() st.NavBlocked=nil end
end
function N.update(st)
 if not st.NavGoal then return end
 local now=os.clock()
 local remaining=flat(st.NavGoal-st.Pos).Magnitude
 if remaining<.55 then N.cancel(st) return end
 if not st.Path and not st.Planning then st.NavNeedsPlan=true end
 local wp=st.Path and st.Path[1] or st.NavGoal
 local distance=flat(wp-st.Pos).Magnitude
 local changed=not st.NavTrackedWaypoint or flat(wp-st.NavTrackedWaypoint).Magnitude>.55
 if changed or distance<(st.NavBestDistance or math.huge)-.55 then
  st.NavTrackedWaypoint=wp st.NavBestDistance=distance
  st.NavProgressPos=st.Pos st.NavProgressAt=now
 elseif now-(st.NavProgressAt or now)>1.4 and now>=(st.DepartAt or 0) then
  st.NavNeedsPlan=true st.NavProgressAt=now
 end
 if st.NavNeedsPlan and now>=(st.NavNextPlan or 0) then st.NavNeedsPlan=false N.repath(st) end
end
function N.step(st,desired,distance,units,floorAt,params)
 local rp=params()
 local exiting=st.TrenchExit~=nil or (st.TrenchExitUntil and os.clock()<st.TrenchExitUntil and (st.Pos-st.TrenchExitOrigin).Magnitude<6)
 local entering=st.TrenchCover and st.TrenchCover.Phase=="Approach" and st.TrenchCover.DirectEntry
 local following=st.TrenchFollowing or entering
 local base=st.Pos-Vector3.new(0,st.Offset,0)
 local height=(following or exiting) and 2.3 or (st.Prone and .65 or st.Crouched and 1.5 or 2.3)
 local box=Vector3.new(1.05,height,.35)
 local function safe(dir,look)
  local ground=floorAt(base+dir*distance)
  if not ground or math.abs(ground.Y-base.Y)>(exiting and 3 or (st.TrenchCover and ground.Y<base.Y and 2.4 or 1.2)) then return end
  -- Follow the walkable floor ahead instead of sweeping horizontally into the hill.
  local ahead=floorAt(base+dir*look)
  if not ahead then return end
  local rise=ahead.Y-base.Y
  if math.abs(rise)>(exiting and 3 or (st.TrenchCover and rise<0 and 3 or look*1.45+.65)) then return end
  local slope=math.abs(rise)/math.max(look,.1)
  local clearance=following and (.12+.25*slope) or (.4+.35*slope)
  local lift=math.max(0,ground.Y-base.Y)
  local origin=base+Vector3.new(0,height/2+clearance+lift,0)
  local sweep=dir*look+Vector3.new(0,math.max(0,rise),0)
  local function clearBody(h)
   local o=base+Vector3.new(0,h/2+clearance+lift,0)
   local size=Vector3.new(1.05,h,.35)
   local hit=workspace:Blockcast(CFrame.lookAt(o,o+dir),size,sweep,rp)
   if not hit then return true end
   -- A walkable pallet/ramp lip may be stepped onto; vertical walls stay solid.
   local step=hit.Position.Y-base.Y+.12
   local walkable=hit.Normal.Y>.55
   local part=hit.Instance
   if (following or exiting) and part:IsA("BasePart") then
    local cf,size=part.CFrame,part.Size
    local top=part.Position.Y+(math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)/2
    if top-base.Y>0 and top-base.Y<=(exiting and 3 or 1.1) then step=math.max(step,top-base.Y+.12) walkable=true end
   end
   if (following or exiting) and walkable and step>0 and step<=(exiting and 3.15 or 1.25) then
    o+=Vector3.new(0,step,0)
    return workspace:Blockcast(CFrame.lookAt(o,o+dir),size,sweep,rp)==nil
   end
   return false
  end
  if not clearBody(height) then
   if not (following or exiting) or not clearBody(.65) then return end
   if not st.Prone then st.Prone=true st.Model:SetAttribute("Prone",true) end
  elseif (following or exiting) and st.Prone then
   st.Prone=false st.Model:SetAttribute("Prone",false)
  end
  local nextPos=ground+Vector3.new(0,st.Offset,0)
  -- Infantry can pass through one another; cover slots prevent stationary overlap.

  return nextPos
 end
 local bunkerPassage=st.TrenchCover and require(script.Parent.InfantryBunkerPatrol).nearPassage(st.TrenchCover.Data,base)
 local look=math.max(distance+.12,st.BoardDoor and .12 or (entering or bunkerPassage) and .25 or .9)
 if st.TrenchFollowing then look=math.min(look,math.max(.05,(flat(st.Path[1]-st.Pos)).Magnitude-.18)) end
 local nextPos=safe(desired,look)
 if nextPos then st.NavAvoidUntil=nil return nextPos,desired end

 local side=st.NavAvoidSide or 1
 -- Hold the chosen side briefly so adjacent frames do not alternate left/right.
 for _,angle in {30,55,80,105} do
  for _,sign in {side,-side} do
   if sign~=side and os.clock()<(st.NavAvoidUntil or 0) then continue end
   local dir=CFrame.Angles(0,math.rad(angle*sign),0):VectorToWorldSpace(desired)
   local pos=safe(dir,look)
   if pos then st.NavAvoidSide=sign st.NavAvoidUntil=os.clock()+.8 return pos,dir end
  end
 end
 st.NavNeedsPlan=true
 return nil,desired
end
return N
