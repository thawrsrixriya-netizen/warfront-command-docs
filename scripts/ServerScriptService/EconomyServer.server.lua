-- ServerScriptService.EconomyServer  (Script)
-- EconomyServer: starts every player's wallet, pays kills, admin test commands.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")
local Economy = require(ServerScriptService.WarServer.Economy)
local Damage = require(ServerScriptService.WarServer.Damage)
local Config = Economy.Config

for _, p in ipairs(Players:GetPlayers()) do
	Economy.setup(p)
end
Players.PlayerAdded:Connect(Economy.setup)

Damage.Killed:Connect(function(model, _source, attacker)
	Economy.rewardKill(model, attacker)
end)

---------------------------------------------------------------- admin commands (testing)
--   /money [n]   set money (default TestMoney)    /points [n]   set points
--   /cooldowns   turn cooldowns off / on for yourself
local COMMANDS = {
	money = function(p, n)
		p:SetAttribute("Money", n or Config.TestMoney)
	end,
	points = function(p, n)
		p:SetAttribute("Points", n or Config.TestPoints)
	end,
	cooldowns = function(p)
		local off = not p:GetAttribute("NoCooldowns")
		p:SetAttribute("NoCooldowns", off or nil)
		Economy.tell(p, off and "Cooldowns OFF" or "Cooldowns ON")
	end,
}

local function run(player, text)
	if not (player and Config.Admins[player.UserId]) then
		return
	end
	local name, arg = string.match(text, "^/(%a+)%s*(%-?%d*)")
	local fn = name and COMMANDS[string.lower(name)]
	if fn then
		fn(player, tonumber(arg))
	end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	for name in pairs(COMMANDS) do
		local c = Instance.new("TextChatCommand")
		c.Name = "Admin_" .. name
		c.PrimaryAlias = "/" .. name
		c.Parent = TextChatService
		c.Triggered:Connect(function(source, text)
			run(Players:GetPlayerByUserId(source.UserId), text)
		end)
	end
else
	local function hook(p)
		p.Chatted:Connect(function(text)
			run(p, text)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerAdded:Connect(hook)
end
