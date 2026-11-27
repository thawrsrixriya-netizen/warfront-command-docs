-- ServerScriptService.WarServer.InfantryTrenchWalkGraph  (ModuleScript)
local G={}
local Nav=require(script.Parent.InfantryNavigation)
local Routes=require(game.ReplicatedStorage.WarShared.TrenchRoutes)
local function flat(p) return Vector3.new(p.X,0,p.Z) end
function G.validate(data)
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Include rp.RespectCanCollide=true
 rp.FilterDescendantsInstances={workspace.GroundAndTrenches}
 local dummy=Instance.new("Model") local valid={} local tested,rejected=0,0
 local function walk(a,b)
  local st={Model=dummy,Pos=data.Nodes[a]+Vector3.yAxis*1.3125,Offset=1.3125,TrenchFollowing=true,TrenchCover={Data=data,Phase="Roam"},Path={data.Nodes[b]}}
  for i=1,100 do
   local d=flat(data.Nodes[b]-st.Pos) if d.Magnitude<.25 then return true end
   local nextPos=Nav.step(st,d.Unit,math.min(.15,d.Magnitude),{},function(p)
    local corridor=Routes.distanceXZ(data,p)
    if corridor>.7 and corridor>=Routes.distanceXZ(data,st.Pos)-.01 then return end
    local h=workspace:Raycast(Vector3.new(p.X,data.Nodes[b].Y+1.25,p.Z),Vector3.new(0,-3,0),rp)
    if h and h.Normal.Y>.55 then return h.Position end
   end,function()return rp end)
   if not nextPos then return false end st.Pos=nextPos
  end
  return false
 end
 for id in data.Nodes do valid[id]={} end
 for a,links in data.Links do for _,b in links do
  if a>=b or not data.Nodes[b] then continue end
  tested+=1
  if walk(a,b) and walk(b,a) then table.insert(valid[a],b) table.insert(valid[b],a)
  else rejected+=1 end
  if tested%16==0 then task.wait() end
 end end
 dummy:Destroy()
 -- Retain every walkable component; each receives soldiers through its own verified bank lane.
 local componentByNode={} local components={}
 for start in data.Nodes do if not componentByNode[start] then
  local component={start} local componentId=#components+1 componentByNode[start]=componentId
  local i=1
  while component[i] do for _,b in valid[component[i]] do if not componentByNode[b] then componentByNode[b]=componentId table.insert(component,b) end end i+=1 end
  table.insert(components,component)
 end end
 local kept=0
 for id in data.Nodes do
  if #valid[id]==0 then data.Nodes[id]=nil data.Links[id]=nil data.BunkerNode[id]=nil data.BunkerSlots[id]=nil componentByNode[id]=nil
  else data.Links[id]=valid[id] kept+=1 end
 end
 local entries={} for _,id in data.Entries do if data.Nodes[id] then table.insert(entries,id) end end data.Entries=entries
 data.ComponentByNode=componentByNode data.Components=components
 data.WalkGraphStats={Tested=tested,Rejected=rejected,Kept=kept,Components=#components}
 return data
end
return G
