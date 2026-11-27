-- ServerScriptService.WarServer.AutoFire  (ModuleScript)
-- AutoFire (server, OWNER system): picks what an infantry soldier shoots at.
-- Order: 1) manual ground fire (old Fire command) is left alone
--        2) a clicked enemy (st.ManualTargetModel) if it is SEEN and in WeaponRange
--        3) otherwise the NEAREST seen enemy in WeaponRange
-- Also turns the soldier toward a shooter after VisionService.notifyAttacked (st.FaceTarget).
local Config = require(game.ReplicatedStorage.VisionConfig)
local Vision = require(script.Parent.VisionService)
local AutoFire = {}
local Overhead=require(game.ReplicatedStorage.WarShared.InfantryOverhead)

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

-- Keep a valid target instead of restarting the reaction delay when nearest units swap.
local Registry=require(game.ReplicatedStorage.WarShared.EnemyRegistry)
local U=require(game.ReplicatedStorage.WarShared.WarUtil)
local function shootable(st,model,range)
 if not model or not model.Parent or not Vision.isVisible(model,"Player") then return false end
 local h=model:FindFirstChildOfClass("Humanoid")
 local r=rootOf(model)
 if not r or (h and h.Health<=0) then return false end
 if Vector3.new(r.Position.X-st.Pos.X,0,r.Position.Z-st.Pos.Z).Magnitude>range then return false end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 local exclude={}
 for _,name in ipairs(U.EFFECT_FOLDERS) do local f=workspace:FindFirstChild(name); if f then table.insert(exclude,f) end end
 for _,p in ipairs(game.Players:GetPlayers()) do if p.Character then table.insert(exclude,p.Character) end end
 for _,tag in ipairs({"TankReactiveTree","TankPassThroughVegetation"}) do
  for _,v in ipairs(game:GetService("CollectionService"):GetTagged(tag)) do table.insert(exclude,v) end
 end
 local from=st.Pos+Vector3.new(0,st.Prone and -.65 or .15,0)
 if Overhead.eligible(st.Model) then
  local body=from
  if Overhead.normal(st.Model) then
   local pose=require(game.ReplicatedStorage.InfantryRiflePose)
   local base=pose.frame(st.Root.CFrame,st.Prone and 1 or 0,r.Position,st.Crouched and 1 or 0,st.Model:GetScale())
   from=Overhead.normalFrame(st.Model,st.Root.CFrame,r.Position,base).Position
  else from=Overhead.origin(st.Model,st.Root.CFrame) end
  local friendly=workspace:FindFirstChild("CommandInfantry") if friendly then table.insert(exclude,friendly) end
  params.FilterDescendantsInstances=exclude
  if workspace:Raycast(body,from-body,params) then return false end
 end
 for _=1,12 do
  params.FilterDescendantsInstances=exclude
  local hit=workspace:Raycast(from,r.Position-from,params)
  if not hit or hit.Instance:IsDescendantOf(model) then return true end
  if hit.Instance.Transparency>=Config.SeeThroughTransparency then table.insert(exclude,hit.Instance) else return false end
 end
 return false
end
function AutoFire.update(st, rifle, profileName)
 if st.CommandStopped then st.FaceTarget=nil return end
	local now = os.clock()
	st.FaceTarget = st.WatchYaw and (st.Pos+Vector3.new(-math.sin(st.WatchYaw),0,-math.cos(st.WatchYaw))*100)
		or ((st.AlertUntil and now < st.AlertUntil) and st.AlertPos or nil)
	if st.Embarked then return end
	if st.FireTarget and not st.AutoFiring then return end -- manual ground fire
	local prof = Vision.profile(profileName or "Infantry")
	local target
	local m = st.ManualTargetModel
	if m then
		-- the ordered target is gone or dead -> back to automatic fire
		local h = m:FindFirstChildOfClass("Humanoid")
		if not m.Parent or (h and h.Health <= 0) then st.ManualTargetModel = nil m = nil end
	end
	if m and shootable(st,m,prof.WeaponRange) then target=m end
	if not target and st.AutoFiring and shootable(st,st.AutoModel,prof.WeaponRange) then target=st.AutoModel end
	if not target then
		local best=math.huge
		for _,e in ipairs(Registry.all(false)) do
			local d=Vector3.new(e.Position.X-st.Pos.X,0,e.Position.Z-st.Pos.Z).Magnitude
			if d<best and shootable(st,e.Model,prof.WeaponRange) then target=e.Model; best=d end
		end
	end
	local r = target and rootOf(target)
	if r then
		if not st.AutoFiring or st.AutoModel ~= target then rifle.begin(st) end
		st.AutoFiring = true
		st.AutoModel = target
		st.FireTarget = r.Position
		st.FaceTarget = nil
		st.Model:SetAttribute("FireActive", true)
		st.Model:SetAttribute("FireTarget", r.Position)
	elseif st.AutoFiring then
		rifle.stop(st)
		st.AutoFiring = false
		st.AutoModel = nil
	end
end

-- Called when the soldier is hit: face the shooter for AlertSeconds.
function AutoFire.alert(st, fromPosition)
	st.AlertPos = fromPosition
	st.AlertUntil = os.clock() + Config.AlertSeconds
end

return AutoFire
