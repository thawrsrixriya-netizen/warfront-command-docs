-- ServerScriptService.AircraftTestServer  (Script)
-- AircraftTestServer: admin-only test of the shoot-down system (AircraftService).
-- The "SHOOT DOWN (TEST)" button (StarterPlayerScripts.AircraftTestButton) fires Remotes.AircraftTest;
-- every flying skill this admin owns is shot down at once, even while AircraftConfig.Health is 0.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Air = require(ServerScriptService.WarServer.AircraftService)
local EconomyConfig = require(ReplicatedStorage:WaitForChild("EconomyConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = Remotes:FindFirstChild("AircraftTest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "AircraftTest"
	remote.Parent = Remotes
end

remote.OnServerEvent:Connect(function(player, action)
	if action ~= "ShootDownMine" or not EconomyConfig.Admins[player.UserId] then
		return
	end
	for _, handle in ipairs(Air.all()) do
		if handle.Owner == player then
			Air.shootDown(handle)
		end
	end
end)
