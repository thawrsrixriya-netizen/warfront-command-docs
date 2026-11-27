-- ServerScriptService.WarServer.AircraftService  (ModuleScript)
-- AircraftService (server): lets enemies shoot down flying skills (AC-130, SU-34, FPV).
-- Every live aircraft has an invisible hitbox Part in workspace.Aircraft that follows it:
--   tag "PlayerAircraft", attributes Skill ("AC130"/"Bomber"/"FPV"), OwnerUserId, Health, MaxHealth.
-- HOW ENEMY WEAPONS HIT IT (AA guns, HMG, bots...):
--   AircraftService.damage(hitboxPart, amount, sourceName)   -- from a server script
--   or simply lower the hitbox's "Health" attribute; at 0 the aircraft is shot down.
--   Raycasts/projectiles can hit the hitbox (CanQuery/CanTouch on, CanCollide off).
-- MaxHealth comes from AircraftConfig.Health[skill]; 0 = cannot be shot down yet.
-- On shoot-down the skill's OnDown(position, cframe) runs (crash visuals, cancel bombs...) and
-- the skill script applies Economy.skillShotDown (cooldown x1.75).
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("AircraftConfig"))
local U = require(ReplicatedStorage.WarShared.WarUtil)

local AircraftService = {}
AircraftService.Tag = "PlayerAircraft"

local folder = U.folder("Aircraft")
local live = {} -- [hitbox] = handle

-- owner's "AircraftFlying" attribute = how many of their aircraft are up (hitboxes far away may
-- not be streamed to the client, so UI reads this instead)
local function updateOwner(owner)
	if not owner or not owner.Parent then
		return
	end
	local n = 0
	for _, h in pairs(live) do
		if h.Owner == owner then
			n += 1
		end
	end
	owner:SetAttribute("AircraftFlying", n)
end

-- opts = { Skill, Owner (Player), GetCFrame = function() -> CFrame or nil, OnDown = function(position, cframe) }
function AircraftService.register(opts)
	local maxHealth = Config.Health[opts.Skill] or 0
	local box = Instance.new("Part")
	box.Name = opts.Skill .. "_" .. (opts.Owner and opts.Owner.UserId or 0)
	box.Size = Config.HitboxSize[opts.Skill] or Vector3.new(4, 4, 4)
	box.Transparency = 1
	box.Anchored = true
	box.CanCollide = false
	box.CanTouch = true
	box.CanQuery = true
	box.CastShadow = false
	box:SetAttribute("Skill", opts.Skill)
	box:SetAttribute("OwnerUserId", opts.Owner and opts.Owner.UserId or 0)
	box:SetAttribute("MaxHealth", maxHealth)
	box:SetAttribute("Health", maxHealth)
	local cf = opts.GetCFrame()
	if cf then
		box.CFrame = cf
	end
	local handle = { Box = box, Skill = opts.Skill, Owner = opts.Owner, GetCFrame = opts.GetCFrame, OnDown = opts.OnDown, Down = false }
	box:GetAttributeChangedSignal("Health"):Connect(function()
		local maxH = box:GetAttribute("MaxHealth") or 0
		if not handle.Down and maxH > 0 and (box:GetAttribute("Health") or 0) <= 0 then
			AircraftService.shootDown(handle)
		end
	end)
	CollectionService:AddTag(box, AircraftService.Tag)
	box.Parent = folder
	live[box] = handle
	updateOwner(opts.Owner)
	return handle
end

-- Normal end (plane left, drone exploded): removes the hitbox without a crash.
function AircraftService.unregister(handle)
	if handle and handle.Box then
		live[handle.Box] = nil
		handle.Box:Destroy()
		updateOwner(handle.Owner)
	end
end

function AircraftService.shootDown(handle)
	if handle.Down then
		return
	end
	handle.Down = true
	local cf = handle.Box.CFrame
	AircraftService.unregister(handle)
	if handle.OnDown then
		task.spawn(handle.OnDown, cf.Position, cf)
	end
end

-- target = hitbox Part (or any descendant of workspace.Aircraft) or a handle
function AircraftService.damage(target, amount, source)
	local handle = live[target] or (typeof(target) == "table" and target) or nil
	if not handle or handle.Down or type(amount) ~= "number" or amount <= 0 then
		return 0
	end
	local box = handle.Box
	if (box:GetAttribute("MaxHealth") or 0) <= 0 then
		return 0 -- cannot be shot down yet
	end
	local before = box:GetAttribute("Health") or 0
	box:SetAttribute("Health", math.max(0, before - amount))
	box:SetAttribute("LastHitBy", tostring(source or ""))
	return before - (box:GetAttribute("Health") or 0)
end

function AircraftService.all()
	local list = {}
	for _, h in pairs(live) do
		table.insert(list, h)
	end
	return list
end

RunService.Heartbeat:Connect(function()
	for box, h in pairs(live) do
		local ok, cf = pcall(h.GetCFrame)
		if ok and cf then
			box.CFrame = cf
		end
	end
end)

return AircraftService
