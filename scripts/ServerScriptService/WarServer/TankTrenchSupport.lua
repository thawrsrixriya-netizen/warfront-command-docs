-- ServerScriptService.WarServer.TankTrenchSupport  (ModuleScript)
local S={}
local routes={} local root,lastRefresh=nil,-math.huge
local function refresh()
 local folder=workspace:FindFirstChild("InfantryTrenchRoutes")
 if folder==root and os.clock()-lastRefresh<5 then return end
 root=folder lastRefresh=os.clock() routes={}
 if not folder then return end
 for _,route in folder:GetChildren() do
  local d={Nodes={},Edges={},MinX=math.huge,MaxX=-math.huge,MinZ=math.huge,MaxZ=-math.huge}
  for _,v in route:GetChildren() do if v:IsA("Vector3Value") then
   local id=tonumber(v.Name) d.Nodes[id]=v.Value
   d.MinX=math.min(d.MinX,v.Value.X) d.MaxX=math.max(d.MaxX,v.Value.X)
   d.MinZ=math.min(d.MinZ,v.Value.Z) d.MaxZ=math.max(d.MaxZ,v.Value.Z)
  end end
  for _,v in route:GetChildren() do if v:IsA("Vector3Value") then
   local a=tonumber(v.Name) for text in (v:GetAttribute("Links") or ""):gmatch("%d+") do
    local b=tonumber(text) if a<b and d.Nodes[b] then table.insert(d.Edges,{d.Nodes[a],d.Nodes[b]}) end
   end
  end end
  table.insert(routes,d)
 end
end
local function nearTrench(p,radius)
 refresh()
 for _,route in routes do
  if p.X<route.MinX-radius or p.X>route.MaxX+radius or p.Z<route.MinZ-radius or p.Z>route.MaxZ+radius then continue end
  for _,edge in route.Edges do
   local a,b=edge[1],edge[2]
   local dx,dz=b.X-a.X,b.Z-a.Z
   local len=dx*dx+dz*dz
   local t=len>.0001 and math.clamp(((p.X-a.X)*dx+(p.Z-a.Z)*dz)/len,0,1) or 0
   local x,z=a.X+dx*t,a.Z+dz*t
   if (p.X-x)^2+(p.Z-z)^2<=radius*radius and math.abs(p.Y-(a.Y+(b.Y-a.Y)*t))<15 then return true end
  end
 end
 return false
end
function S.height(pos,yaw,geo,params,centreHeight)
 local radius=math.sqrt(geo.Width^2+geo.Length^2)*.5+1
 if not nearTrench(pos,radius) then return centreHeight,false end
 local pivot=CFrame.new(pos)*CFrame.Angles(0,yaw,0)
 local rel=geo.HullCenterRel or Vector3.zero
 local support=centreHeight
 -- Four contact corners span the narrow trench while the centre ray sees its bottom.
 for _,x in {-geo.Width*.43,geo.Width*.43} do
  for _,z in {-geo.Length*.43,geo.Length*.43} do
   local p=pivot:PointToWorldSpace(Vector3.new(rel.X+x,0,rel.Z+z))
   local hit=workspace:Raycast(Vector3.new(p.X,pos.Y+12,p.Z),Vector3.new(0,-50,0),params)
   if hit and hit.Normal.Y>.55 and hit.Position.Y-centreHeight<=4 then support=math.max(support,hit.Position.Y) end
  end
 end
 return support,support>centreHeight+.15
end
return S
