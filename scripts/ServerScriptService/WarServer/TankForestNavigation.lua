-- ServerScriptService.WarServer.TankForestNavigation  (ModuleScript)
-- Hybrid A*: validates the same rolling forward/reverse arcs the vehicle will execute.
local CS=game:GetService("CollectionService")
local U=require(game.ReplicatedStorage.WarShared.WarUtil)
local Planner={}
local function wrap(a) return (a+math.pi)%(2*math.pi)-math.pi end
function Planner.plan(start,goal,width,length,vehicles,startYaw)
 local obstacles={}
 for _,tree in ipairs(CS:GetTagged("TankReactiveTree")) do
  if tree:IsDescendantOf(workspace) and not tree:GetAttribute("TreeFallen") then
   local a=tree:FindFirstChild("TankTrunk1",true)
   if a then table.insert(obstacles,{P=Vector2.new(a.WorldPosition.X,a.WorldPosition.Z),R=(a:GetAttribute("TreeCollisionRadius") or 1)+0.65}) end
  end
 end
 for _,p in ipairs(vehicles or {}) do table.insert(obstacles,{P=Vector2.new(p.X,p.Z),R=math.sqrt(width^2+length^2)/2+0.5}) end
 local params=U.groundParams()
 params.RespectCanCollide=true
 local overlap=OverlapParams.new()
 overlap.FilterType=params.FilterType overlap.FilterDescendantsInstances=params.FilterDescendantsInstances
 overlap.RespectCanCollide=true
 local hw,hl=width/2+0.45,length/2+0.45
 local sx,sz,gx,gz=start.X,start.Z,goal.X,goal.Z
 local function free(x,z,yaw)
  local f=Vector2.new(-math.sin(yaw),-math.cos(yaw))
  local r=Vector2.new(math.cos(yaw),-math.sin(yaw))
  for _,o in ipairs(obstacles) do
   local d=o.P-Vector2.new(x,z)
   local dx=math.max(math.abs(d:Dot(r))-hw,0)
   local dz=math.max(math.abs(d:Dot(f))-hl,0)
   if dx*dx+dz*dz<o.R*o.R then return false end
  end
  -- A rotating hull must fit at each resulting pose, not only along the translation sweep.
  if #workspace:GetPartBoundsInBox(CFrame.new(x,start.Y+.2,z)*CFrame.Angles(0,yaw,0),
   Vector3.new(width+.2,1.3,length+.2),overlap)>0 then return false end
  return true
 end
 local function arc(node,gear,curve,travel)
  local x,z,yaw=node.X,node.Z,node.Yaw
  local n=math.ceil(travel/1)
  local step=travel/n
  for i=1,n do
   local mid=yaw+curve*step*gear/2
   local nx,nz=x-math.sin(mid)*step*gear,z-math.cos(mid)*step*gear
   local ny=wrap(yaw+curve*step*gear)
   if not free(nx,nz,ny) then return nil end
   local d=Vector3.new(nx-x,0,nz-z)
   local hit=workspace:Blockcast(CFrame.new(x,start.Y+0.2,z)*CFrame.Angles(0,yaw,0),
    Vector3.new(width+0.2,1.3,length+0.2),d,params)
   if hit then return nil end
   x,z,yaw=nx,nz,ny
  end
  return x,z,yaw
 end
 local function key(x,z,yaw,gear)
  return math.floor(x/2+0.5)..":"..math.floor(z/2+0.5)..":"..(math.floor((wrap(yaw)+math.pi)/(math.pi/12)+0.5)%24)..":"..gear
 end
 local heap={}
 local function push(n)
  table.insert(heap,n) local i=#heap
  while i>1 do local p=math.floor(i/2) if heap[p].F<=n.F then break end heap[i]=heap[p]; i=p end
  heap[i]=n
 end
 local function pop()
  local n=heap[1] local last=table.remove(heap)
  if #heap>0 then local i=1
   while i*2<=#heap do local c=i*2 if c<#heap and heap[c+1].F<heap[c].F then c+=1 end if heap[c].F>=last.F then break end heap[i]=heap[c];i=c end
   heap[i]=last
  end
  return n
 end
 local first={X=sx,Z=sz,Yaw=startYaw or 0,Gear=1,G=0,F=math.sqrt((gx-sx)^2+(gz-sz)^2)}
 push(first)
 local best={[key(sx,sz,first.Yaw,1)]=0}
 local count=0
 local margin=80
 local minX,maxX=math.min(sx,gx)-margin,math.max(sx,gx)+margin
 local minZ,maxZ=math.min(sz,gz)-margin,math.max(sz,gz)+margin
 local primitiveLength=4
 local turn=1/9
 while #heap>0 and count<10000 do
  local node=pop()
  if node.G==best[key(node.X,node.Z,node.Yaw,node.Gear)] then
   count+=1
   local remaining=math.sqrt((node.X-gx)^2+(node.Z-gz)^2)
   if remaining<2.5 then
    local result={}
    local n=node
    while n.Parent do table.insert(result,1,{Gear=n.Gear,Curve=n.Curve,Length=n.Travel}); n=n.Parent end
    return result,nil,{expanded=count,endDistance=remaining}
   end
   for _,gear in ipairs({1,-1}) do
    for _,curve in ipairs({0,-turn,turn}) do
     local x,z,yaw=arc(node,gear,curve,primitiveLength)
     if x and x>=minX and x<=maxX and z>=minZ and z<=maxZ then
      local g=node.G+primitiveLength*(gear<0 and 1.3 or 1)+(gear~=node.Gear and 3 or 0)+(curve~=0 and 0.25 or 0)
      local k=key(x,z,yaw,gear)
      if g<(best[k] or math.huge) then
       best[k]=g
       local h=math.sqrt((x-gx)^2+(z-gz)^2)
       push({X=x,Z=z,Yaw=yaw,Gear=gear,Curve=curve,Travel=primitiveLength,G=g,F=g+h*1.12,Parent=node})
      end
     end
    end
   end
   if count%80==0 then task.wait() end
  end
 end
 return nil,"No driveable arc route within the search budget",{expanded=count}
end
return Planner
