-- StarterPlayer.StarterPlayerScripts.AircraftTestButton  (LocalScript)
-- AircraftTestButton (admins only): bottom-left button above the wallet that shoots down
-- your own AC-130 / SU-34 / FPV that is flying right now (tests the shoot-down system).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage:WaitForChild("EconomyConfig"))
local player = Players.LocalPlayer
if not EconomyConfig.Admins[player.UserId] then
	return
end
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AircraftTest")

local gui = Instance.new("ScreenGui")
gui.Name = "AircraftTest"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "ShootDown"
button.AnchorPoint = Vector2.new(0, 1)
button.Position = UDim2.new(0, 16, 1, -108) -- just above the MatchHUD wallet
button.Size = UDim2.fromOffset(200, 32)
button.Font = Enum.Font.GothamBold
button.TextSize = 13
button.TextColor3 = Color3.new(1, 1, 1)
button.AutoButtonColor = true
button.Text = "SHOOT DOWN (TEST)"
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 78, 92)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button

local ON, OFF = Color3.fromRGB(190, 45, 40), Color3.fromRGB(30, 34, 42)
local function mine()
	return (player:GetAttribute("AircraftFlying") or 0) > 0 -- set by AircraftService
end

task.spawn(function()
	while gui.Parent do
		local any = mine()
		button.BackgroundColor3 = any and ON or OFF
		button.TextTransparency = any and 0 or 0.5
		task.wait(0.25)
	end
end)

button.Activated:Connect(function()
	if mine() then
		remote:FireServer("ShootDownMine")
	end
end)
