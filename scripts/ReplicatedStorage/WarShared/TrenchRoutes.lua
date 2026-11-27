-- ReplicatedStorage.WarShared.TrenchRoutes  (ModuleScript)
local R={}
local cache=setmetatable({},{__mode="k"})
local function flat(v) return Vector3.new(v.X,0,v.Z) end
function R.load(route)
 if cache[route] then return cache[route] end
 if not route or route.Parent~=workspace:FindFirstChild("InfantryTrenchRoutes") then return end
 local data={Route=route,Nodes={},Links={},Entries={}}
 for _,v in route:GetChildren() do if v:IsA("Vector3Value") then local id=tonumber(v.Name) if id then
  data.Nodes[id]=v.Value data.Links[id]={}
  local blocked={}
  for n in (v:GetAttribute("BlockedLinks") or ""):gmatch("%d+") do blocked[tonumber(n)]=true end
  for n in (v:GetAttribute("Links") or ""):gmatch("%d+") do if not blocked[tonumber(n)] then table.insert(data.Links[id],tonumber(n)) end end
  if v:GetAttribute("Entry") then table.insert(data.Entries,id) end
 end end end
 data.ComponentByNode={}
 local seen={}
 for start in data.Nodes do if not seen[start] then
  local sub={Route=route,Nodes={},Links={},Entries={}}
  local queue={start} seen[start]=true local qi=1
  while queue[qi] do
   local id=queue[qi] qi+=1 sub.Nodes[id]=data.Nodes[id] sub.Links[id]=data.Links[id]
   data.ComponentByNode[id]=sub
   if #data.Links[id]==1 then table.insert(sub.Entries,id) end
   for _,v in data.Links[id] do if not seen[v] then seen[v]=true table.insert(queue,v) end end
  end
 end end
 cache[route]=data return data
end
function R.nearest(data,p,entries)
 local best,dist=nil,math.huge
 for _,id in entries or {} do local d=(data.Nodes[id]-p).Magnitude if d<dist then best=id dist=d end end
 if best then return best,dist end
 for id,v in data.Nodes do local d=(v-p).Magnitude if d<dist then best=id dist=d end end
 return best,dist
end
function R.pick(p)
 if typeof(p)~="Vector3" then return end
 local root=workspace:FindFirstChild("InfantryTrenchRoutes") if not root then return end
 local best,node,distance=nil,nil,6
 for _,route in root:GetChildren() do
  local data=R.load(route) local id,d=R.nearest(data,p)
  if d<distance then best=data.ComponentByNode[id] node=id distance=d end
 end
 return best,node
end
function R.path(data,start,finish)
 local dist={[start]=0} local previous={} local open={[start]=true}
 while next(open) do
  local best,score=nil,math.huge
  for id in open do if dist[id]<score then best=id score=dist[id] end end
  open[best]=nil if best==finish then break end
  for _,id in data.Links[best] do
   local n=score+(data.Nodes[id]-data.Nodes[best]).Magnitude
   if n<(dist[id] or math.huge) then dist[id]=n previous[id]=best open[id]=true end
  end
 end
 if not dist[finish] then return end
 local ids={finish} local at=finish
 while at~=start do at=previous[at] if not at then return end table.insert(ids,1,at) end
 return ids,dist[finish]
end
function R.distanceXZ(data,p)
 local nearest,distance=nil,math.huge
 local q=Vector3.new(p.X,0,p.Z)
 for a,edges in data.Links do for _,b in edges do if a<b then
  local x,y=flat(data.Nodes[a]),flat(data.Nodes[b])
  local delta=y-x
  local t=delta:Dot(delta)>.0001 and math.clamp((q-x):Dot(delta)/delta:Dot(delta),0,1) or 0
  local d=(q-(x+delta*t)).Magnitude
  if d<distance then distance=d nearest=a end
 end end end
 return distance,nearest
end
function R.groundInside(p)
 local data,id=R.pick(p)
 return data~=nil and math.abs(p.Y-data.Nodes[id].Y)<1 and R.distanceXZ(data,p)<1.6
end
function R.bodyInside(p)
 local data,id=R.pick(p)
 return data~=nil and p.Y-data.Nodes[id].Y>.2 and p.Y-data.Nodes[id].Y<2.6 and R.distanceXZ(data,p)<1.6
end
return R

