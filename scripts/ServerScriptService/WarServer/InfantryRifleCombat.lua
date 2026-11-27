-- ServerScriptService.WarServer.InfantryRifleCombat  (ModuleScript)
local RS=game.ReplicatedStorage
local C=require(RS.InfantryConfig)
local Pose=require(RS.InfantryRiflePose)
local Damage=require(script.Parent.Damage)
local Remote=RS.Remotes.InfantryCommand
local M={}
local Overhead=require(RS.WarShared.InfantryOverhead)
local rng=Random.new()
local function chooseTrenchStyle(st)
 st.Model:SetAttribute("TrenchFireStyle",Overhead.eligible(st.Model) and (rng:NextNumber()<C.TrenchOverheadChance and "Overhead" or "Normal") or nil)
 st.OverheadReadyAt=nil
end
function M.begin(st)
 chooseTrenchStyle(st) st.NextTrenchStyleAt=nil
 st.AimReadyAt=nil
 st.SemiReaction=0.12+(st.Model:GetAttribute("SquadIndex") or 1)*0.08+rng:NextNumber(0,.35)
 st.SemiCadence=rng:NextNumber(.9,1.1)
 st.SemiShots=0 st.SemiPauseAfter=rng:NextInteger(4,7)
 st.NextShot=workspace:GetServerTimeNow()+st.SemiReaction
 st.Model:SetAttribute("RifleFireMode","Semi")
end
function M.stop(st)
 st.FireTarget=nil st.NextTrenchStyleAt=nil
 st.Model:SetAttribute("TrenchFireStyle",nil)
 st.Model:SetAttribute("OverheadShoot",false)
 st.Model:SetAttribute("FireActive",false)
 st.Model:SetAttribute("FireTarget",nil)
end
function M.step(st)
 if st.NextTrenchStyleAt and workspace:GetServerTimeNow()>=st.NextTrenchStyleAt then
  chooseTrenchStyle(st) st.NextTrenchStyleAt=nil
 end
 local raised=st.FireTarget~=nil and Overhead.active(st.Model) or false
 st.Model:SetAttribute("OverheadShoot",raised)
 if not raised then st.OverheadReadyAt=nil
 elseif not st.OverheadReadyAt then st.OverheadReadyAt=workspace:GetServerTimeNow()+.3 end
 if not st.FireTarget then return end
 local model=st.Model
 local now=workspace:GetServerTimeNow()
 local remaining=model:GetAttribute("RifleReloadUntil") or 0
 if now<remaining then return end
 if raised and now<(st.OverheadReadyAt or 0) then return end
 st.Ammo=st.Ammo or C.MagazineSize
 if st.Ammo<=0 then st.Ammo=C.MagazineSize model:SetAttribute("RifleAmmo",st.Ammo) end
 local delta=st.FireTarget-st.Pos
 local wanted=math.atan2(-delta.X,-delta.Z)
 local err=(wanted-st.Yaw+math.pi)%(2*math.pi)-math.pi
 if math.abs(err)>math.rad(4) then st.AimReadyAt=nil return end
 if not st.AimReadyAt then
  st.AimReadyAt=now st.NextShot=math.max(st.NextShot or 0,now+(st.SemiReaction or .3))
  return
 end
 if now<(st.NextShot or 0) then return end
 local frame=Pose.frame(st.Root.CFrame,st.Prone and 1 or 0,st.FireTarget,st.Crouched and 1 or 0,st.Model:GetScale(),st.Model:GetAttribute("Moving") and .72 or .9677603245)
 local overhead=Overhead.eligible(model) and model:GetAttribute("TrenchFireStyle")~="Normal"
 if overhead then frame=Overhead.frame(model,st.Root.CFrame,st.FireTarget)
 elseif Overhead.normal(model) then frame=Overhead.normalFrame(model,st.Root.CFrame,st.FireTarget,frame) end
 local gun=model:FindFirstChild("Rifle")
 if not gun then return end
 local muzzle=frame*(gun:GetAttribute("MuzzleOffset") or Vector3.new(0,.1,-1))
 local aimPoint=st.FireTarget
 local missed=false
 if overhead then
  missed=rng:NextNumber()>C.OverheadHitChance
  model:SetAttribute("LastOverheadShotAccurate",not missed)
  if missed then
   local spread=4
   local target=st.AutoModel or st.ManualTargetModel
   if target and target.Parent then local size=target:GetExtentsSize() spread=math.max(spread,math.sqrt(size.X*size.X+size.Z*size.Z)*.6+2) end
   aimPoint+=frame.RightVector*spread*(rng:NextNumber()<.5 and -1 or 1)+Vector3.yAxis*rng:NextNumber(1,3)
  end
 else model:SetAttribute("LastOverheadShotAccurate",nil) end
 local to=aimPoint-muzzle
 if to.Magnitude<0.1 then return end
 local rp=RaycastParams.new()
 rp.FilterType=Enum.RaycastFilterType.Exclude
 local exclude={model}
 -- Friendly units are not projectile targets and must not occlude squad mates.
 for _,name in ipairs({"CommandInfantry","CommandTanks","WarFX"}) do
  local f=workspace:FindFirstChild(name)
  if f then table.insert(exclude,f) end
 end
 if st.Owner.Character then table.insert(exclude,st.Owner.Character) end
 local fx=workspace:FindFirstChild("ClientFX") if fx then table.insert(exclude,fx) end
 -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 -- trees and bushes block sight but not bullets
 for _,tag in {"TankReactiveTree","TankPassThroughVegetation"} do for _,v in game:GetService("CollectionService"):GetTagged(tag) do table.insert(exclude,v) end end
 -- [SHARED:Vision] END
 rp.FilterDescendantsInstances=exclude
 local direction=to.Unit*math.min(C.RifleRange,to.Magnitude+0.5)
 -- Check the segment from the torso too: a muzzle protruding through cover cannot bypass it.
 local base=st.Pos+Vector3.new(0,st.Prone and -0.65 or st.Crouched and -0.2 or 0.15,0)
 local cover=workspace:Raycast(base,muzzle-base,rp)
 local result=cover or workspace:Raycast(muzzle,direction,rp)
 local impact=result and result.Position or muzzle+direction
 if result and not missed then
  local ancestor=result.Instance
  while ancestor and ancestor~=workspace do
   if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
    -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove) (st.Owner gets the kill money)
    Damage.apply(ancestor,C.RifleDamage,"InfantryAK74",st.Owner)
    -- [SHARED:Vision] END
    break
   end
   ancestor=ancestor.Parent
  end
 end
 st.SemiShots=(st.SemiShots or 0)+1
 local interval=rng:NextNumber(C.SemiShotMin,C.SemiShotMax)*(st.SemiCadence or 1)
 if st.SemiShots>=(st.SemiPauseAfter or 5) then
  interval+=rng:NextNumber(C.SemiPauseMin,C.SemiPauseMax)
  if Overhead.eligible(model) then st.NextTrenchStyleAt=now+interval end
  st.SemiShots=0 st.SemiPauseAfter=rng:NextInteger(4,7)
 end
 st.NextShot=now+interval
 st.Ammo-=1
 model:SetAttribute("RifleAmmo",st.Ammo)
 model:SetAttribute("LastRifleShot",now)
 Remote:FireAllClients("Shot",model,muzzle,impact)
 if st.Ammo<=0 then model:SetAttribute("RifleReloadUntil",now+C.ReloadTime) end
end
return M