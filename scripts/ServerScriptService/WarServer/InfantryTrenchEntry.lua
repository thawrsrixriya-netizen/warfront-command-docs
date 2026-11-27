-- ServerScriptService.WarServer.InfantryTrenchEntry  (ModuleScript)
local E={}
local Nav=require(script.Parent.InfantryNavigation)
local cache=setmetatable({},{__mode="k"})
local function flat(p) return Vector3.new(p.X,0,p.Z) end
function E.floor(p,baseY,nodeY,rp)
 local h=workspace:Raycast(Vector3.new(p.X,baseY+.75,p.Z),Vector3.new(0,-7,0),rp)
 if h and h.Normal.Y>.15 and h.Position.Y<=baseY+.35 and h.Position.Y>=nodeY-.7 then return h.Position end
end
function E.lanes(data,rp)
 if cache[data.Route] then return cache[data.Route] end
 local lanes={} local dummy=Instance.new("Model")
 local checked=0
 for id,p in data.Nodes do
  if data.BunkerNode[id] or #data.Links[id]<2 then continue end
  local a=data.Nodes[data.Links[id][1]] local b=data.Nodes[data.Links[id][#data.Links[id]]]
  local tangent=flat(b-a) if tangent.Magnitude<.2 then continue end tangent=tangent.Unit
  local side=Vector3.new(-tangent.Z,0,tangent.X)
  for _,sign in {-1,1} do
   local q=p+side*(4.5*sign)
   local h=workspace:Raycast(q+Vector3.yAxis*6,Vector3.new(0,-9,0),rp)
   if not h or h.Normal.Y<.65 or h.Position.Y-p.Y<.8 or h.Position.Y-p.Y>3.5 then continue end
   local bank=h.Position local st={Model=dummy,Pos=bank+Vector3.yAxis*1.31,Offset=1.31,TrenchCover={Data=data,Phase="Approach",DirectEntry=true}}
   st.Path={p}
   local valid=true local steps=0 local points={}
   while flat(st.Pos-p).Magnitude>.24 and steps<80 do
    steps+=1 local d=flat(p-st.Pos)
    local nextPos=Nav.step(st,d.Unit,math.min(.15,d.Magnitude),{},function(v)return E.floor(v,st.Pos.Y-st.Offset,p.Y,rp)end,function()return rp end)
    if not nextPos then valid=false break end
    -- Reject a simulated detour through a neighbouring end cap.
    local segment=flat(p-bank) local t=math.clamp(flat(nextPos-bank):Dot(segment)/segment:Dot(segment),0,1)
    if (flat(nextPos-bank)-segment*t).Magnitude>.7 then valid=false break end
    st.Pos=nextPos
    if steps%5==0 then table.insert(points,nextPos-Vector3.yAxis*st.Offset) end
   end
   if valid and math.abs(st.Pos.Y-st.Offset-p.Y)<.65 and flat(st.Pos-p).Magnitude<.3 then
    table.insert(points,p) lanes[id]=lanes[id] or {} table.insert(lanes[id],{Bank=bank,Points=points,Node=id})
   end
  end
  checked+=1 if checked%12==0 then task.wait() end
 end
 dummy:Destroy() cache[data.Route]=lanes return lanes
end
function E.best(lanes,position,target,tried,data)
 local component
 if data and data.ComponentByNode then
  local nearest=require(game.ReplicatedStorage.WarShared.TrenchRoutes).nearest(data,target)
  component=data.ComponentByNode[nearest]
 end
 local lane,score=nil,math.huge
 for id,list in lanes do if (not component or data.ComponentByNode[id]==component) and (not tried or not tried[id]) then for _,v in list do
  local cost=flat(position-v.Bank).Magnitude*.55+flat(target-v.Points[#v.Points]).Magnitude
  if cost<score then lane=v score=cost end
 end end end
 return lane
end
return E
