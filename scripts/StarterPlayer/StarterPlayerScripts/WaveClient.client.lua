-- StarterPlayer.StarterPlayerScripts.WaveClient  (LocalScript)
-- WaveClient: "WAVE N" banner when a wave starts, next-wave countdown during breaks, VICTORY at the end.
-- Reads ReplicatedStorage MatchWave / MatchPhase / MatchBreakEnds (WaveServer). MatchHUD shows the rest.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "WaveHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.24)
banner.Size = UDim2.fromOffset(600, 60)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 42
banner.TextColor3 = Color3.fromRGB(255, 205, 70)
banner.TextStrokeTransparency = 0.4
banner.TextTransparency = 1
banner.Parent = gui

local countdown = Instance.new("TextLabel")
countdown.Name = "NextWave"
countdown.AnchorPoint = Vector2.new(0.5, 0)
countdown.Position = UDim2.new(0.5, 0, 0, 120)
countdown.Size = UDim2.fromOffset(300, 24)
countdown.BackgroundTransparency = 1
countdown.Font = Enum.Font.GothamBold
countdown.TextSize = 16
countdown.TextColor3 = Color3.fromRGB(236, 239, 244)
countdown.TextStrokeTransparency = 0.5
countdown.Visible = false
countdown.Parent = gui

local token = 0
local function show(text, color, hold)
	token += 1
	local my = token
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	if hold then
		return
	end
	task.delay(2.5, function()
		if my == token then
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

local lastWave = ReplicatedStorage:GetAttribute("MatchWave") or 0
ReplicatedStorage:GetAttributeChangedSignal("MatchWave"):Connect(function()
	local w = ReplicatedStorage:GetAttribute("MatchWave") or 0
	if w > lastWave and w > 0 then
		local isBoss = w % 10 == 0
		show(isBoss and ("WAVE " .. w .. "  -  BOSS") or ("WAVE " .. w), isBoss and Color3.fromRGB(200, 90, 255) or Color3.fromRGB(255, 205, 70))
	end
	lastWave = w
end)
ReplicatedStorage:GetAttributeChangedSignal("MatchPhase"):Connect(function()
	if ReplicatedStorage:GetAttribute("MatchPhase") == "Victory" then
		show("VICTORY", Color3.fromRGB(110, 220, 120), true)
	end
end)

RunService.Heartbeat:Connect(function()
	local phase = ReplicatedStorage:GetAttribute("MatchPhase")
	local ends = ReplicatedStorage:GetAttribute("MatchBreakEnds")
	if phase == "Break" and ends then
		local left = math.max(0, math.ceil(ends - workspace:GetServerTimeNow()))
		countdown.Text = "NEXT WAVE IN " .. left
		countdown.Visible = true
	else
		countdown.Visible = false
	end
end)
