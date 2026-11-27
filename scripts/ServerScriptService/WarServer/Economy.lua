-- ServerScriptService.WarServer.Economy  (ModuleScript)
-- Economy (server): in-match money and points, summon costs, skill points and cooldowns.
-- Values live on the player as attributes the MatchHUD reads:
--   Money, Points, Kills, Cooldown_<key> (server time when ready), NoCooldowns (admin test)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("EconomyConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local notice = Remotes:FindFirstChild("EconomyMessage")
if not notice then
	notice = Instance.new("RemoteEvent")
	notice.Name = "EconomyMessage"
	notice.Parent = Remotes
end

local Economy = {}
Economy.Config = Config

local function now()
	return workspace:GetServerTimeNow()
end

function Economy.tell(player, text)
	if player.Parent then
		notice:FireClient(player, text)
	end
end

function Economy.setup(player)
	if player:GetAttribute("Money") ~= nil then
		return
	end
	player:SetAttribute("Money", Config.TestMode and Config.TestMoney or Config.StartMoney[Config.Difficulty] or 0)
	player:SetAttribute("Points", Config.TestMode and Config.TestPoints or Config.StartPoints)
	player:SetAttribute("Kills", 0)
end

function Economy.add(player, money, points)
	Economy.setup(player)
	if money and money ~= 0 then
		player:SetAttribute("Money", math.max(0, math.floor(player:GetAttribute("Money") + money + 0.5)))
	end
	if points and points ~= 0 then
		player:SetAttribute("Points", math.max(0, math.floor(player:GetAttribute("Points") + points + 0.5)))
	end
end

local function cooldownLeft(player, key)
	if player:GetAttribute("NoCooldowns") then
		return 0
	end
	return math.max(0, (player:GetAttribute("Cooldown_" .. key) or 0) - now())
end

local function startCooldown(player, key, seconds)
	if seconds and seconds > 0 and player.Parent and not player:GetAttribute("NoCooldowns") then
		player:SetAttribute("Cooldown_" .. key, now() + seconds)
	end
end

-- Summon check before placing; returns false (and tells the player why) if it cannot be paid.
function Economy.canSummon(player, key)
	local def = Config.Units[key]
	if not def then
		return true
	end
	Economy.setup(player)
	local left = cooldownLeft(player, key)
	if left > 0 then
		Economy.tell(player, string.format("%s ready in %d s", def.Label or key, math.ceil(left)))
		return false
	end
	if player:GetAttribute("Money") < def.Cost then
		Economy.tell(player, string.format("Not enough money ($%d)", def.Cost))
		return false
	end
	return true
end

-- Call only after the unit was really placed.
function Economy.chargeSummon(player, key)
	local def = Config.Units[key]
	if def then
		Economy.add(player, -def.Cost)
		startCooldown(player, key, def.Cooldown)
	end
end

-- Pays the skill's points; false (with a message) if on cooldown or not enough points.
function Economy.trySkill(player, id)
	local def = Config.Skills[id]
	if not def then
		return true
	end
	Economy.setup(player)
	local left = cooldownLeft(player, id)
	if left > 0 then
		Economy.tell(player, string.format("Skill ready in %d s", math.ceil(left)))
		return false
	end
	if player:GetAttribute("Points") < def.Points then
		Economy.tell(player, string.format("Not enough points (%d)", def.Points))
		return false
	end
	Economy.add(player, 0, -def.Points)
	return true
end

-- The skill has finished (plane gone, drone exploded): its cooldown starts now.
function Economy.skillEnded(player, id)
	local def = Config.Skills[id]
	if def then
		startCooldown(player, id, def.Cooldown)
	end
end

-- A flying skill was shot down: its cooldown becomes ShotDownCooldownMultiplier times longer
-- (whole seconds), counted from `from` (server time it was called; default = now).
function Economy.skillShotDown(player, id, from)
	local def = Config.Skills[id]
	if def and def.Cooldown and def.Cooldown > 0 and player.Parent and not player:GetAttribute("NoCooldowns") then
		local seconds = math.floor(def.Cooldown * (Config.ShotDownCooldownMultiplier or 1.75) + 0.5)
		player:SetAttribute("Cooldown_" .. id, (from or now()) + seconds)
	end
end

-- Kill money (+ a point every KillsPerPoint kills). Without a known attacker every player is paid.
function Economy.rewardKill(model, attacker)
	local amount = Config.KillReward[model:GetAttribute("UnitType") or ""] or Config.KillReward.Default
	local targets = (typeof(attacker) == "Instance" and attacker:IsA("Player") and attacker.Parent) and { attacker } or Players:GetPlayers()
	for _, p in ipairs(targets) do
		Economy.add(p, amount * (Config.MoneyMultiplier or 1))
		local kills = (p:GetAttribute("Kills") or 0) + 1
		p:SetAttribute("Kills", kills)
		if kills % Config.KillsPerPoint == 0 then
			Economy.add(p, 0, 1)
		end
	end
end

return Economy
