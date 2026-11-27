-- ReplicatedStorage.WarClient.UnitWatchPreview  (ModuleScript)
local RS=game.ReplicatedStorage
local U=require(RS.WarShared.WarUtil)
local Aim=require(RS.WarClient.Aim)
local Profiles=require(RS.VisionConfig).Profiles
local W={}; W.__index=W
local function centre(model,kind)
 if kind=="BMP" then
  return (CFrame.new(model:GetAttribute("TankPos"))*CFrame.Angles(0,model:GetAttribute("TankYaw") or 0,0))*(model:GetAttribute("HullCenterRel") or Vector3.zero)
 end
 local sum,n=Vector3.zero,0
 for _,unit in ipairs(workspace.CommandInfantry:GetChildren()) do
  local h=unit:FindFirstChildOfClass("Humanoid")
  if unit:GetAttribute("OwnerUserId")==model:GetAttribute("OwnerUserId") and unit:GetAttribute("InfantrySlot")==model:GetAttribute("InfantrySlot") and h and h.Health>0 and not unit:GetAttribute("Embarked") then sum+=unit:GetPivot().Position; n+=1 end
 end
 return n>0 and sum/n or model:GetPivot().Position
end
function W.active(models)
 for _,m in ipairs(models) do if m:GetAttribute("WatchYaw")~=nil then return true end end
 return false
end
local function remote(kind) return kind=="BMP" and RS.Remotes.TankCommand or RS.Remotes.InfantryCommand end
function W.cancel(models,kind)
 for _,m in ipairs(models) do if m.Parent then remote(kind):FireServer("CancelWatch",Vector3.zero,nil,m) end end
end
function W.new(models,kind)
 local model=Instance.new("Model"); model.Name="WatchDirectionPreview"; model.Parent=U.folder("ClientFX")
 local self=setmetatable({Models=table.clone(models),Kind=kind,Model=model,Pool={},Direction=Vector3.new(0,0,-1)},W)
 self:Update(Aim.groundHit())
 return self
end
function W:Update(hit)
 if not self.Model.Parent then return end
 local sum,n=Vector3.zero,0
 for _,m in ipairs(self.Models) do if m.Parent then sum+=centre(m,self.Kind); n+=1 end end
 if n==0 then return end
 if hit then self.Direction=U.flat(hit-sum/n) or self.Direction end
 local yaw=U.yawOf(self.Direction)
 local prof=Profiles[self.Kind]
 local half=math.rad(prof.VisionAngle/2)
 local params=U.groundParams()
 local function floor(p)
  local h=workspace:Raycast(p+Vector3.new(0,30,0),Vector3.new(0,-100,0),params)
  return (h and h.Position or p)+Vector3.new(0,.28,0)
 end
 local used=0
 local function line(a,b)
  used+=1; local p=self.Pool[used]
  if not p then p=Instance.new("Part"); p.Name="WatchLine"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.CastShadow=false; p.Color=Color3.new(1,1,1); p.Material=Enum.Material.Neon; p.Transparency=.12; p.Parent=self.Model; self.Pool[used]=p end
  p.Size=Vector3.new(.15,.025,math.max(.01,(b-a).Magnitude)); p.CFrame=CFrame.lookAt((a+b)/2,b)
 end
 for _,m in ipairs(self.Models) do if m.Parent then
  local c=centre(m,self.Kind)
  local a=floor(c+U.dirOf(yaw+half)*prof.VisionRange)
  local b=floor(c+U.dirOf(yaw-half)*prof.VisionRange)
  local base=floor(c)
  line(base,a); line(base,b)
  local prev=a
  for i=1,14 do local p=floor(c+U.dirOf(yaw+half-2*half*i/14)*prof.VisionRange); line(prev,p); prev=p end
 end end
end
function W:Confirm()
 for _,m in ipairs(self.Models) do if m.Parent then remote(self.Kind):FireServer("Watch",self.Direction,nil,m) end end
end
return W
