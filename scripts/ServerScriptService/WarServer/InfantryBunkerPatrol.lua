-- ServerScriptService.WarServer.InfantryBunkerPatrol  (ModuleScript)
local B={}
local function flat(p) return Vector3.new(p.X,0,p.Z) end
function B.extend(data)
 data.Bunkers={} data.BunkerNode={} data.BunkerSlots={}
 local folder=workspace:FindFirstChild("InfantryBunkerRoutes") if not folder then return end
 local nextId=0 for id in data.Nodes do nextId=math.max(nextId,id) end
 for _,b in folder:GetChildren() do
  local ref=b:FindFirstChild("TrenchRoute") local entry=b:GetAttribute("EntryNode")
  if not ref or ref.Value~=data.Route or not data.Nodes[entry] then continue end
  local map={} local steps=b:GetAttribute("Steps")
  table.insert(data.Bunkers,b)
  for _,v in b:GetChildren() do if v:IsA("Vector3Value") then
   nextId+=1 map[tonumber(v.Name)]=nextId data.Nodes[nextId]=v.Value data.Links[nextId]={}
   data.BunkerNode[nextId]=b if v:GetAttribute("Slot") then data.BunkerSlots[nextId]=true end
  end end
  local function link(a,c) table.insert(data.Links[a],c) table.insert(data.Links[c],a) end
  link(entry,map[1])
  for i=1,steps do link(map[i],map[i+1]) end
  for i=steps+2,steps+4 do link(map[steps+1],map[i]) end
 end
end
function B.nearPassage(data,p)
 for id in data.BunkerNode or {} do
  local q=data.Nodes[id]
  if flat(p-q).Magnitude<1.6 and math.abs(p.Y-q.Y)<2 then return true end
 end
 return false
end
function B.at(data,point)
 for _,b in data.Bunkers or {} do
  local center=b:GetAttribute("Center")
  if flat(point-center).Magnitude<3.65 and math.abs(point.Y-center.Y)<2.2 then return b end
 end
end
function B.free(st,data,point,reservations)
 local bunker=B.at(data,point) if not bunker then return true end
 local others={} local center=bunker:GetAttribute("Center")
 for model,p in reservations do
  if model~=st.Model and model.Parent and B.at(data,p)==bunker then others[model]=true end
 end
 local units=workspace:FindFirstChild("CommandInfantry")
 if units then for _,model in units:GetChildren() do
  local root=model:FindFirstChild("HumanoidRootPart") local hum=model:FindFirstChildOfClass("Humanoid")
  if model~=st.Model and root and hum and hum.Health>0 and not model:GetAttribute("Embarked")
   and B.at(data,root.Position-Vector3.yAxis*(model:GetAttribute("GroundOffset") or 1))==bunker then others[model]=true end
 end end
 local n=0 for _ in others do n+=1 end
 return n<(bunker:GetAttribute("Capacity") or 3)
end
return B
