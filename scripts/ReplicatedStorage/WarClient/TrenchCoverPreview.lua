-- ReplicatedStorage.WarClient.TrenchCoverPreview  (ModuleScript)
local R=require(game.ReplicatedStorage.WarShared.TrenchRoutes)
local P={} P.__index=P
local levels=setmetatable({},{__mode="k"})
local function surfaceLevel(data)
 if levels[data.Route] then return levels[data.Route] end
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude
 local skip={}
 for _,n in {"CommandInfantry","CommandTanks","ClientFX"} do local f=workspace:FindFirstChild(n) if f then table.insert(skip,f) end end
 for _,player in game.Players:GetPlayers() do if player.Character then table.insert(skip,player.Character) end end
 rp.FilterDescendantsInstances=skip rp.RespectCanCollide=true
 local bins={} local count=0 local minimum=math.huge
 for _,p in data.Nodes do
  minimum=math.min(minimum,p.Y)
  if count>=20 then continue end count+=1
  for _,offset in {Vector3.new(4,0,0),Vector3.new(-4,0,0),Vector3.new(0,0,4),Vector3.new(0,0,-4)} do
   local h=workspace:Raycast(p+offset+Vector3.new(0,5,0),Vector3.new(0,-10,0),rp)
   if h and h.Normal.Y>.8 and h.Position.Y>p.Y+1 and h.Position.Y<p.Y+3.2 then
    local key=math.floor(h.Position.Y*10+.5)
    local b=bins[key] or {Count=0,Sum=0} b.Count+=1 b.Sum+=h.Position.Y bins[key]=b
   end
  end
 end
 local best,level=0,minimum+1.7
 for _,b in bins do if b.Count>best then best=b.Count level=b.Sum/b.Count end end
 levels[data.Route]=level+.06
 return levels[data.Route]
end
function P.new()
 local m=Instance.new("Model") m.Name="TrenchCoverPreview" m.Parent=workspace.CurrentCamera
 return setmetatable({Model=m},P)
end
function P:Update(hit)
 local data,id=R.pick(hit)
 self.Point=data and data.Nodes[id] or nil
 if self.Data==data then return end
 self.Data=data self.Model:ClearAllChildren()
 if not data then return end
 local level=surfaceLevel(data)
 self.Model:SetAttribute("SurfaceLevel",level)
 for a,edges in data.Links do for _,b in edges do if a<b then
  local pa,pb=data.Nodes[a],data.Nodes[b]
  local x,y=Vector3.new(pa.X,level,pa.Z),Vector3.new(pb.X,level,pb.Z)
  local p=Instance.new("Part") p.Name="WhiteRoute" p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
  p.CastShadow=false p.Material=Enum.Material.Neon p.Color=Color3.new(1,1,1)
  p.Size=Vector3.new(.14,.025,(y-x).Magnitude) p.CFrame=CFrame.lookAt((x+y)/2,y) p.Parent=self.Model
 end end end
end
return P
