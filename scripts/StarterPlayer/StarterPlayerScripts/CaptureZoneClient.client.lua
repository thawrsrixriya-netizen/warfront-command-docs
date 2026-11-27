-- StarterPlayer.StarterPlayerScripts.CaptureZoneClient  (LocalScript)
-- CaptureZoneClient: draws the centre base zone (faint red dashed outline + very faint fill) and the
-- capture bar under the wave panel, and announces when the centre changes hands.
-- Data comes from CaptureServer via ReplicatedStorage attributes (Center*), because the zone part itself
-- may not be streamed in on this client. Settings: CaptureConfig.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("CaptureConfig"))
local player = Players.LocalPlayer
local V = Config.Visual

-- `zone` = a small stand-in for the zone part, built from the replicated attributes
local ATTR = {
	CaptureOwner = "CenterOwner",
	CaptureControl = "CenterControl",
	CaptureBy = "CenterBy",
	PlayerStrength = "CenterPlayerStrength",
	EnemyStrength = "CenterEnemyStrength",
	Contested = "CenterContested",
}
while typeof(ReplicatedStorage:GetAttribute("CenterZoneCFrame")) ~= "CFrame" do
	task.wait(0.2)
end
local zoneCF, zoneSize = ReplicatedStorage:GetAttribute("CenterZoneCFrame"), ReplicatedStorage:GetAttribute("CenterZoneSize")
local zone = {
	CFrame = zoneCF,
	Size = zoneSize,
	Position = zoneCF.Position,
	GetAttribute = function(_, name)
		return ReplicatedStorage:GetAttribute(ATTR[name] or name)
	end,
	GetAttributeChangedSignal = function(_, name)
		return ReplicatedStorage:GetAttributeChangedSignal(ATTR[name] or name)
	end,
}

---------------------------------------------------------------- zone outline (local parts, no collisions)
local fxFolder = workspace:FindFirstChild("ClientFX") or Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace
local model = Instance.new("Model")
model.Name = "CenterZoneOutline"
model.Parent = fxFolder

-- only the ground model counts, so dashes never sit on trees, houses or units
local groundModel = workspace:WaitForChild(Config.GroundModel or "GroundAndTrenches", 10)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { groundModel or workspace.Terrain }
local function groundY(x, z, fallback)
	local r = workspace:Raycast(Vector3.new(x, zone.Position.Y + 60, z), Vector3.new(0, -140, 0), rayParams)
	return r and r.Position.Y or fallback
end

local function part(size, cf, color, transparency)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Transparency = transparency
	p.Parent = model
	return p
end

local function build()
	model:ClearAllChildren()
	if groundModel then
		-- wait until the ground under the zone has streamed in (otherwise dashes would be missing)
		local t0 = os.clock()
		while os.clock() - t0 < 10 and not workspace:Raycast(Vector3.new(zone.Position.X, zone.Position.Y + 60, zone.Position.Z), Vector3.new(0, -140, 0), rayParams) do
			task.wait(0.5)
		end
	end
	local cf, size = zone.CFrame, zone.Size
	local hx, hz = size.X / 2, size.Z / 2
	local baseY = zone.Position.Y + size.Y / 2
	local centreY = groundY(cf.Position.X, cf.Position.Z, baseY)
	-- very faint fill
	local fill = part(Vector3.new(size.X, 0.05, size.Z), CFrame.new(cf.Position.X, math.max(baseY, centreY) + 0.08, cf.Position.Z) * cf.Rotation, V.FillColor, V.FillTransparency)
	fill.Material = Enum.Material.SmoothPlastic
	-- dashed edges, each dash sits on the ground under it
	local corners = {
		{ Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz) },
		{ Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz) },
		{ Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz) },
		{ Vector3.new(-hx, 0, hz), Vector3.new(-hx, 0, -hz) },
	}
	for _, e in ipairs(corners) do
		local a = cf:PointToWorldSpace(e[1])
		local b = cf:PointToWorldSpace(e[2])
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = dir.Magnitude
		dir = dir.Unit
		local t = 0
		while t < len do
			local d = math.min(V.DashLength, len - t)
			local mid = a + dir * (t + d / 2)
			local y = math.max(groundY(mid.X, mid.Z, baseY), groundY(mid.X - dir.X * d / 2, mid.Z - dir.Z * d / 2, baseY), groundY(mid.X + dir.X * d / 2, mid.Z + dir.Z * d / 2, baseY)) + 0.15
			part(Vector3.new(V.LineWidth, 0.1, d), CFrame.lookAlong(Vector3.new(mid.X, y, mid.Z), dir), V.LineColor, V.LineTransparency)
			t += V.DashLength + V.GapLength
		end
	end
end
task.defer(build)

---------------------------------------------------------------- capture bar (under the MatchHUD wave panel)
local BLUE, RED, GREY = Color3.fromRGB(80, 190, 255), Color3.fromRGB(240, 70, 60), Color3.fromRGB(150, 160, 175)
local gui = Instance.new("ScreenGui")
gui.Name = "CaptureHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Center"
-- top row, to the right of MatchHUD's AUTO SKIP panel (MatchHUD.Top is 420 wide, centred, y = 8)
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0.5, 218, 0, 8)
panel.Size = UDim2.fromOffset(270, 64)
panel.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
panel.BackgroundTransparency = 0.1
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 78, 92)
stroke.Parent = panel

local function label(name, pos, size, align, textSize, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = Color3.fromRGB(236, 239, 244)
	l.TextXAlignment = align
	l.Parent = panel
	return l
end
local title = label("Title", UDim2.fromOffset(12, 6), UDim2.new(0.5, -12, 0, 16), Enum.TextXAlignment.Left, 13, Enum.Font.GothamBlack)
title.Text = "CENTER BASE"
local state = label("State", UDim2.new(0.4, 0, 0, 6), UDim2.new(0.6, -12, 0, 16), Enum.TextXAlignment.Right, 12)
local barBack = Instance.new("Frame")
barBack.Name = "Bar"
barBack.Position = UDim2.fromOffset(12, 27)
barBack.Size = UDim2.new(1, -24, 0, 12)
barBack.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
barBack.BorderSizePixel = 0
barBack.Parent = panel
Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 4)
local barFill = Instance.new("Frame")
barFill.BorderSizePixel = 0
barFill.Size = UDim2.fromScale(0, 1)
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)
-- tick marks at 25 / 50 / 75 %
for _, t in ipairs({ 0.25, 0.5, 0.75 }) do
	local tick = Instance.new("Frame")
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.fromScale(t, 0.5)
	tick.Size = UDim2.fromOffset(2, 14)
	tick.BackgroundColor3 = Color3.fromRGB(236, 239, 244)
	tick.BackgroundTransparency = 0.25
	tick.BorderSizePixel = 0
	tick.ZIndex = 3
	tick.Parent = barBack
end
local force = label("Force", UDim2.fromOffset(12, 44), UDim2.new(1, -24, 0, 14), Enum.TextXAlignment.Center, 11, Enum.Font.GothamMedium)
force.TextColor3 = GREY

-- one bar: blue = ours (fills while we hold / capture), red = enemy's
local function refresh()
	local owner = zone:GetAttribute("CaptureOwner") or "Enemy"
	local c = zone:GetAttribute("CaptureControl") or (owner == "Player" and 1 or -1)
	local by = zone:GetAttribute("CaptureBy") or ""
	local ps, es = zone:GetAttribute("PlayerStrength") or 0, zone:GetAttribute("EnemyStrength") or 0
	local ownerColor = owner == "Player" and BLUE or owner == "Enemy" and RED or GREY
	stroke.Color = ownerColor
	local pct = math.floor(math.abs(c) * 100 + 0.5)
	if zone:GetAttribute("Contested") then
		state.Text = "CONTESTED"
		state.TextColor3 = Color3.fromRGB(255, 205, 70)
	elseif by == "Player" then
		state.Text = c < 0 and "PUSHING ENEMY OUT" or string.format("CAPTURING %d%%", pct)
		state.TextColor3 = BLUE
	elseif by == "Enemy" then
		state.Text = c > 0 and "UNDER ATTACK" or string.format("ENEMY CAPTURING %d%%", pct)
		state.TextColor3 = RED
	else
		state.Text = owner == "Player" and "HELD BY YOU" or owner == "Enemy" and "ENEMY HELD" or "NEUTRAL"
		state.TextColor3 = ownerColor
	end
	barFill.BackgroundColor3 = c >= 0 and BLUE or RED
	barFill.Size = UDim2.fromScale(math.abs(c), 1)
	force.Text = string.format("Your force %.1f   |   Enemy force %.1f   (need +%d%%)", ps, es, math.floor((Config.AdvantageRatio - 1) * 100 + 0.5))
end
for _, a in ipairs({ "CaptureOwner", "CaptureControl", "CaptureBy", "PlayerStrength", "EnemyStrength", "Contested" }) do
	zone:GetAttributeChangedSignal(a):Connect(refresh)
end
refresh()

---------------------------------------------------------------- announcement when the centre changes hands
local banner = Instance.new("TextLabel")
banner.Name = "Announcement"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.32)
banner.Size = UDim2.fromOffset(600, 50)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 34
banner.TextStrokeTransparency = 0.4
banner.Visible = false
banner.Parent = gui
local token = 0
local lastOwner = zone:GetAttribute("CaptureOwner")
local lastOwnerWasPlayer = lastOwner == "Player"
zone:GetAttributeChangedSignal("CaptureOwner"):Connect(function()
	local owner = zone:GetAttribute("CaptureOwner")
	if owner == lastOwner then
		return
	end
	lastOwner = owner
	token += 1
	local my = token
	if owner == "None" then
		if lastOwnerWasPlayer then
			banner.Text, banner.TextColor3 = "CENTER LOST", RED
		else
			banner.Text, banner.TextColor3 = "ENEMY PUSHED OUT", BLUE
		end
	else
		banner.Text = owner == "Player" and "CENTER CAPTURED" or "ENEMY CAPTURED THE CENTER"
		banner.TextColor3 = owner == "Player" and BLUE or RED
	end
	lastOwnerWasPlayer = owner == "Player"
	banner.TextTransparency = 0
	banner.Visible = true
	task.delay(3, function()
		if my == token then
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end)
