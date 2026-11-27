-- StarterPlayer.StarterPlayerScripts.CompactDummyHealth  (LocalScript)
-- CompactDummyHealth: small overhead HP bar for every registered enemy.
-- Bars are sized in studs (so they shrink when zoomed out instead of covering the map).
-- Numeric text only shows within TextHideDistance of the camera; the bar always shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage:WaitForChild("WarConfig")).Dummies
local Registry = require(ReplicatedStorage:WaitForChild("WarShared"):WaitForChild("EnemyRegistry"))
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local holder = Instance.new("Folder") -- BillboardGuis render from PlayerGui; ResetOnSpawn=false on each
holder.Name = "WarHealthBars"
holder.Parent = playerGui

local bars = {} -- [Model] = { Gui, Fill, Text, Adornee, Conn }

local function colorFor(ratio)
	return Color3.fromHSV(0.33 * math.clamp(ratio, 0, 1), 0.85, 0.9)
end

local function refresh(entry, humanoid)
	local max = math.max(humanoid.MaxHealth, 1)
	local hp = math.max(humanoid.Health, 0)
	local ratio = hp / max
	entry.Fill.Size = UDim2.fromScale(ratio, 1)
	entry.Fill.BackgroundColor3 = colorFor(ratio)
	entry.Text.Text = string.format("%d/%d", math.ceil(hp), math.floor(max + 0.5))
end

local function makeBar(model, humanoid)
	local adornee = model:FindFirstChild("Head") or Registry.rootOf(model)
	if not adornee then
		return
	end
	-- Avoid duplicate labels: default Humanoid name and any old TopHealth billboard.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Name == "TopHealth" then
			d.Enabled = false
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "WarHealthBar"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(C.BarSize.X, C.BarSize.Y) -- scale = studs
	gui.StudsOffsetWorldSpace = Vector3.new(0, C.OffsetY, 0)
	gui.MaxDistance = C.MaxDistance
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.3, 0)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.3, 0)

	local text = Instance.new("TextLabel")
	text.Name = "HealthText"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.ZIndex = 2
	text.Parent = back

	gui.Parent = holder
	local entry = { Gui = gui, Fill = fill, Text = text, Adornee = adornee }
	entry.Conn = humanoid.HealthChanged:Connect(function()
		refresh(entry, humanoid)
	end)
	refresh(entry, humanoid)
	bars[model] = entry
end

local function removeBar(model)
	local entry = bars[model]
	if entry then
		entry.Conn:Disconnect()
		entry.Gui:Destroy()
		bars[model] = nil
	end
end

while true do
	local seen = {}
	for _, e in ipairs(Registry.all(true)) do
		seen[e.Model] = true
		if not bars[e.Model] then
			makeBar(e.Model, e.Humanoid)
		end
	end
	local camPos = workspace.CurrentCamera.CFrame.Position
	for model, entry in pairs(bars) do
		if not seen[model] or not entry.Adornee:IsDescendantOf(workspace) then
			removeBar(model)
		else
			entry.Text.Visible = (entry.Adornee.Position - camPos).Magnitude <= C.TextHideDistance
		end
	end
	task.wait(C.CheckInterval)
end
