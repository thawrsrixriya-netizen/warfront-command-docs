-- ReplicatedStorage.WarShared.InfantryOverhead  (ModuleScript)
local O={}
local cache=setmetatable({},{__mode="k"})
local physicalCache=setmetatable({},{__mode="k"})
local Routes=require(game.ReplicatedStorage.WarShared.TrenchRoutes)
function O.eligible(model)
 if model:GetAttribute("Moving") or model:GetAttribute("Embarked") or model:GetAttribute("TrenchExiting") or model:GetAttribute("LowCeiling") then return false end
 if model:GetAttribute("InTrenchCover")==true then return true end
 local root=model:FindFirstChild("HumanoidRootPart") if not root then return false end
 local old=physicalCache[model]
 if old and os.clock()<old.Until and (root.Position-old.Pos).Magnitude<.5 then return old.Inside end
 local inside=Routes.bodyInside(root.Position)
 physicalCache[model]={Pos=root.Position,Until=os.clock()+.3,Inside=inside}
 return inside
end
function O.normal(model)
 return model:GetAttribute("TrenchFireStyle")=="Normal" and O.eligible(model)
end
function O.active(model)
 return model:GetAttribute("TrenchFireStyle")~="Normal" and O.eligible(model) and model:GetAttribute("FireActive")==true
  and workspace:GetServerTimeNow()>=(model:GetAttribute("RifleReloadUntil") or 0)
end
function O.bankHeight(model,rootCF)
 local old=cache[model]
 if old and os.clock()<old.Until and (rootCF.Position-old.Pos).Magnitude<1 then return old.Height end
 local root=rootCF.Position
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.RespectCanCollide=true
 local skip={model}
 for _,name in {"CommandInfantry","CommandTanks","ClientFX","WarFX"} do local f=workspace:FindFirstChild(name) if f then table.insert(skip,f) end end
 for _,p in game.Players:GetPlayers() do if p.Character then table.insert(skip,p.Character) end end
 rp.FilterDescendantsInstances=skip
 local baseY=root.Y-3*model:GetScale()
 local bins={}
 for _,radius in {3,5,7} do for i=0,3 do
  local a=i*math.pi/2 local p=root+Vector3.new(math.cos(a)*radius,5,math.sin(a)*radius)
  local h=workspace:Raycast(p,Vector3.new(0,-10,0),rp)
  if h and h.Normal.Y>.7 and h.Position.Y>baseY+1 and h.Position.Y<baseY+3.2 then
   local key=math.floor(h.Position.Y*10+.5) local bin=bins[key] or {Count=0,Sum=0}
   bin.Count+=1 bin.Sum+=h.Position.Y bins[key]=bin
  end
 end end
 local count,height=0,baseY+1.7
 for _,bin in bins do if bin.Count>count then count=bin.Count height=bin.Sum/bin.Count end end
 cache[model]={Pos=root,Until=os.clock()+1,Height=height}
 return height
end
function O.origin(model,rootCF)
 local bank=O.bankHeight(model,rootCF)
 local p=rootCF:PointToWorldSpace(Vector3.new(.12,0,-.12))
 return Vector3.new(p.X,math.max(bank+.18,rootCF.Position.Y+2.25*model:GetScale()+.25),p.Z)
end
function O.frame(model,rootCF,target)
 local p=O.origin(model,rootCF)
 local d=target and target-p or rootCF.LookVector
 if d.Magnitude<.01 then d=rootCF.LookVector end
 return CFrame.lookAt(p,p+d.Unit)
end
function O.normalFrame(model,rootCF,target,baseFrame)
 local lift=require(game.ReplicatedStorage.InfantryConfig).TrenchNormalGunLift
 local p=baseFrame.Position
 p=Vector3.new(p.X,math.max(p.Y+lift,O.bankHeight(model,rootCF)+.08),p.Z)
 local d=target and target-p or baseFrame.LookVector
 if d.Magnitude<.01 then d=baseFrame.LookVector end
 return CFrame.lookAt(p,p+d.Unit)
end
return O
