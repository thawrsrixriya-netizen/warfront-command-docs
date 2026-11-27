-- StarterPlayer.StarterPlayerScripts.MatchHUD  (LocalScript)
-- MatchHUD: the in-match screen (owner's layout sketch, 2026-11-21).
--   top centre   : wave info + AUTO SKIP toggle + SKIP WAVE / SKIP BREAK button
--   bottom left  : money (summon units, buy equipment) and points (skills)
--   bottom centre: unit slots 1-6 (number keys 1-6) + SHOP + SKILLS
--   right        : buy panel, only while SHOP or SKILLS is open
--   hint bar     : while aiming a skill / placing a unit, with CANCEL
-- Waves are not built yet. Money, points, prices and cooldowns come from EconomyConfig and the
-- player attributes set by the server Economy (Money, Points, Cooldown_<key>).
-- Match values are read from ReplicatedStorage attributes (MatchWave, MatchWaveTotal,
-- MatchEnemiesLeft, MatchPhase "Waiting"|"Wave"|"Break") and player attributes (Money, Points).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("WarConfig"))
local Client = ReplicatedStorage:WaitForChild("WarClient")
local InputMode = require(Client:WaitForChild("InputMode"))
local SkillActions = require(Client:WaitForChild("SkillActions"))
local UnitSlots = require(Client:WaitForChild("UnitSlots"))
local Economy = require(ReplicatedStorage:WaitForChild("EconomyConfig"))
local player = Players.LocalPlayer

-- number keys 1-6 belong to the unit slots, not the Roblox tool backpack
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

---------------------------------------------------------------- style
local C = {
	Panel = Color3.fromRGB(18, 21, 26),
	Panel2 = Color3.fromRGB(30, 34, 42),
	Line = Color3.fromRGB(70, 78, 92),
	Text = Color3.fromRGB(236, 239, 244),
	Muted = Color3.fromRGB(150, 158, 172),
	Accent = Color3.fromRGB(255, 196, 64),
	Green = Color3.fromRGB(64, 176, 96),
	Red = Color3.fromRGB(206, 64, 64),
	Grey = Color3.fromRGB(78, 84, 96),
	Money = Color3.fromRGB(110, 210, 120),
	Points = Color3.fromRGB(120, 180, 255),
}
local DASH = "–"

-- seconds until a summon / skill key is ready again (server time on the player attribute)
local function cooldownLeft(key)
	if not key or player:GetAttribute("NoCooldowns") then
		return 0
	end
	return math.max(0, (player:GetAttribute("Cooldown_" .. key) or 0) - workspace:GetServerTimeNow())
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	end
	o.Parent = parent
	return o
end

local function corner(parent, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or C.Line,
		Thickness = thickness or 1,
		Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function panel(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or C.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	local f = new("Frame", props, parent)
	corner(f, 10)
	stroke(f)
	return f
end

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or C.Text
	props.Font = props.Font or Enum.Font.GothamBold
	return new("TextLabel", props, parent)
end

local function button(props, parent)
	props.AutoButtonColor = true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.GothamBold
	local b = new("TextButton", props, parent)
	corner(b, 8)
	return b
end

---------------------------------------------------------------- root
local gui = new("ScreenGui", { Name = "MatchHUD", ResetOnSpawn = false, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------- top: wave info
local top = new("Frame", {
	Name = "Top",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(420, 104),
	BackgroundTransparency = 1,
}, gui)

local wave = panel({ Name = "Wave", Size = UDim2.fromOffset(300, 64) }, top)
local waveTitle = label({
	Position = UDim2.fromOffset(16, 6),
	Size = UDim2.new(1, -32, 0, 30),
	Text = "WAVE 0 / 30",
	TextSize = 24,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
}, wave)
local waveSub = label({
	Position = UDim2.fromOffset(16, 36),
	Size = UDim2.new(1, -32, 0, 20),
	Text = "ENEMIES LEFT  0",
	TextSize = 14,
	TextColor3 = C.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
}, wave)
local phaseTag = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 10),
	Size = UDim2.fromOffset(110, 20),
	Text = "WAITING",
	TextSize = 12,
	TextColor3 = C.Accent,
	TextXAlignment = Enum.TextXAlignment.Right,
}, wave)

local auto = panel({ Name = "AutoSkip", Position = UDim2.fromOffset(308, 0), Size = UDim2.fromOffset(112, 64) }, top)
label({
	Position = UDim2.fromOffset(0, 6),
	Size = UDim2.new(1, 0, 0, 16),
	Text = "AUTO SKIP",
	TextSize = 12,
	TextColor3 = C.Muted,
}, auto)
local autoBtn = button({
	Name = "Toggle",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(1, -20, 0, 30),
	BackgroundColor3 = C.Grey,
	Text = "OFF",
	TextSize = 15,
}, auto)

local skipBtn = button({
	Name = "Skip",
	Position = UDim2.fromOffset(60, 72),
	Size = UDim2.fromOffset(180, 30),
	BackgroundColor3 = C.Panel2,
	Text = "SKIP WAVE",
	TextSize = 14,
}, top)
stroke(skipBtn)

---------------------------------------------------------------- bottom left: money / points
local wallet = panel({
	Name = "Wallet",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(200, 84),
}, gui)

local function walletRow(y, name, color)
	local dot = new("Frame", { Position = UDim2.fromOffset(14, y + 9), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = color }, wallet)
	corner(dot, 6)
	label({
		Position = UDim2.fromOffset(34, y),
		Size = UDim2.fromOffset(80, 30),
		Text = name,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, wallet)
	return label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, y),
		Size = UDim2.fromOffset(100, 30),
		Text = DASH,
		TextSize = 20,
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, wallet)
end
local moneyValue = walletRow(10, "MONEY", C.Money)
local pointsValue = walletRow(44, "POINTS", C.Points)

---------------------------------------------------------------- bottom centre: hotbar
local SLOT, GAP, WIDE = 66, 6, 80
local hotbarWidth = 6 * SLOT + 5 * GAP + 14 + 2 * WIDE + GAP
local hotbar = new("Frame", {
	Name = "Hotbar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(hotbarWidth, SLOT + 18),
	BackgroundTransparency = 1,
}, gui)

local slots = {}
for i = 1, 6 do
	local f = new("Frame", {
		Name = "Slot" .. i,
		Position = UDim2.fromOffset((i - 1) * (SLOT + GAP), 18),
		Size = UDim2.fromOffset(SLOT, SLOT),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.12,
	}, hotbar)
	corner(f, 10)
	local st = stroke(f)
	local vp = new("ViewportFrame", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -22),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
	}, f)
	local key = label({
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.fromOffset(14, 14),
		Text = tostring(i),
		TextSize = 12,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	key.ZIndex = 3
	local count = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 3),
		Size = UDim2.fromOffset(40, 14),
		Text = "",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, f)
	count.ZIndex = 3
	local name = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0, 14),
		Text = "EMPTY",
		TextSize = 11,
		TextColor3 = C.Muted,
	}, f)
	name.ZIndex = 3
	-- summon cost tag above the slot
	local cost = label({
		Position = UDim2.fromOffset(0, -18),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		TextSize = 13,
		TextColor3 = C.Money,
		TextStrokeTransparency = 0.5,
	}, f)
	-- cooldown cover with the seconds left
	local cd = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 3 }, f)
	corner(cd, 10)
	local cdText = label({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 22, Font = Enum.Font.GothamBlack, ZIndex = 3 }, cd)
	local click = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4 }, f)
	slots[i] = { Frame = f, Stroke = st, Viewport = vp, Count = count, Name = name, Cost = cost, Click = click, Cooldown = cd, CooldownText = cdText, IconBuilt = false }
end

local wideX = 6 * (SLOT + GAP) + 14 - GAP
local shopBtn = button({
	Name = "Shop",
	Position = UDim2.fromOffset(wideX, 18),
	Size = UDim2.fromOffset(WIDE, SLOT),
	BackgroundColor3 = C.Panel,
	Text = "SHOP",
	TextSize = 15,
}, hotbar)
local shopStroke = stroke(shopBtn)
local skillsBtn = button({
	Name = "Skills",
	Position = UDim2.fromOffset(wideX + WIDE + GAP, 18),
	Size = UDim2.fromOffset(WIDE, SLOT),
	BackgroundColor3 = C.Panel,
	Text = "SKILLS",
	TextSize = 15,
}, hotbar)
local skillsStroke = stroke(skillsBtn)

---------------------------------------------------------------- right: buy panel
local side = panel({
	Name = "BuyPanel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 120),
	Size = UDim2.new(0, 310, 1, -236),
	Visible = false,
}, gui)
local sideTitle = label({
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -70, 0, 30),
	Text = "SHOP",
	TextSize = 22,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
}, side)
local sideSub = label({
	Position = UDim2.fromOffset(16, 38),
	Size = UDim2.new(1, -32, 0, 16),
	Text = "",
	TextSize = 12,
	TextColor3 = C.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
}, side)
local sideClose = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = C.Panel2,
	Text = "X",
	TextSize = 14,
}, side)
local list = new("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(12, 64),
	Size = UDim2.new(1, -24, 1, -76),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Line,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, side)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

-- a card: colour bar, name, kind, two info lines, price, action button
local function card(order, color, name, kind, lines, price, priceColor, parent)
	local f = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -4, 0, 112),
		BackgroundColor3 = C.Panel2,
		BackgroundTransparency = 0.05,
	}, parent)
	corner(f, 8)
	new("Frame", { Size = UDim2.new(0, 5, 1, -16), Position = UDim2.fromOffset(6, 8), BackgroundColor3 = color }, f)
	label({
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -110, 0, 14),
		Text = kind,
		TextSize = 11,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	label({
		Position = UDim2.fromOffset(20, 22),
		Size = UDim2.new(1, -110, 0, 22),
		Text = name,
		TextSize = 17,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, f)
	for j, line in ipairs(lines) do
		label({
			Position = UDim2.fromOffset(20, 44 + (j - 1) * 17),
			Size = UDim2.new(1, -30, 0, 16),
			Text = line,
			TextSize = 12,
			TextColor3 = C.Muted,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, f)
	end
	label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(90, 18),
		Text = price,
		TextSize = 15,
		Font = Enum.Font.GothamBlack,
		TextColor3 = priceColor,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, f)
	local status = label({
		Position = UDim2.new(0, 20, 1, -28),
		Size = UDim2.new(1, -140, 0, 20),
		Text = "",
		TextSize = 11,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local b = button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -8),
		Size = UDim2.fromOffset(100, 30),
		BackgroundColor3 = C.Green,
		Text = "CALL",
		TextSize = 14,
	}, f)
	return f, b, status
end

-- SHOP: placed equipment (bought with money). Models / placement come later.
local EQUIPMENT = {
	{ Name = "AA GUN", Kind = "AIR DEFENCE", Color = Color3.fromRGB(120, 180, 255), Lines = { "Shoots down aircraft", "Placed on the ground" } },
	{ Name = "HEAVY MG", Kind = "DEFENCE", Color = Color3.fromRGB(230, 150, 70), Lines = { "Fast fire vs infantry", "Placed on the ground" } },
	{ Name = "SANDBAGS", Kind = "COVER", Color = Color3.fromRGB(196, 170, 120), Lines = { "Cover for your soldiers", "Placed on the ground" } },
}
local shopPage = new("Frame", { Name = "ShopPage", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false }, list)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, shopPage)
for i, e in ipairs(EQUIPMENT) do
	local _, b, status = card(i, e.Color, e.Name, e.Kind, e.Lines, "$ " .. DASH, C.Money, shopPage)
	b.Text = "SOON"
	b.BackgroundColor3 = C.Grey
	b.AutoButtonColor = false
	status.Text = "NOT AVAILABLE YET"
end

-- SKILLS: paid with points, 3 skill slots
local SKILLS = {
	{ Id = "Bomber", Name = "SU-34 BOMBER", Kind = "AIRSTRIKE", Color = Color3.fromRGB(230, 130, 60),
		Lines = { string.format("%d bombs, up to %d dmg", Config.Bomber.BombCount, Config.Bomber.MaxDamage), string.format("Strike area %dx%d", Config.Bomber.RectWidth, Config.Bomber.RectLength) } },
	{ Id = "FPV", Name = "FPV DRONE", Kind = "KAMIKAZE", Color = Color3.fromRGB(80, 160, 230),
		Lines = { string.format("Dives into the first enemy, %d dmg", Config.FPV.Damage), string.format("Range %d studs", Config.FPV.Length) } },
	{ Id = "AC130", Name = "AC-130 GUNSHIP", Kind = "AIR SUPPORT", Color = Color3.fromRGB(220, 70, 70),
		Lines = { string.format("Orbits and fires for %d s", Config.AC130.AttackDuration), "Recall any time" } },
}
local skillPage = new("Frame", { Name = "SkillsPage", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false }, list)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, skillPage)
local skillCards = {}
for i, s in ipairs(SKILLS) do
	local price = Economy.Skills[s.Id] and (Economy.Skills[s.Id].Points .. " PTS") or (DASH .. " PTS")
	local f, b, status = card(i, s.Color, s.Name, s.Kind, s.Lines, price, C.Points, skillPage)
	f.Name = s.Id
	skillCards[s.Id] = { Button = b, Status = status }
end

---------------------------------------------------------------- hint bar
local hint = panel({
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 120),
	Size = UDim2.fromOffset(580, 40),
	Visible = false,
}, gui)
local hintText = label({
	Position = UDim2.fromOffset(14, 0),
	Size = UDim2.new(1, -130, 1, 0),
	Text = "",
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, hint)
local cancelBtn = button({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.fromOffset(100, 28),
	BackgroundColor3 = C.Red,
	Text = "CANCEL",
	TextSize = 13,
}, hint)

---------------------------------------------------------------- toast (why something cannot be bought)
local toast = label({
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 212),
	Size = UDim2.fromOffset(560, 26),
	Text = "",
	TextSize = 17,
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(255, 110, 100),
	TextStrokeTransparency = 0.4,
	Visible = false,
}, gui)
local toastToken = 0
local function showToast(text)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(2.5, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end
task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EconomyMessage", 30)
	if remote then
		remote.OnClientEvent:Connect(showToast)
	end
end)

---------------------------------------------------------------- behaviour: buy panel
local openPage = nil -- nil | "Shop" | "Skills"

local function refreshSkill(id)
	local c = skillCards[id]
	if not c then
		return
	end
	local def = SkillActions.get(id)
	local state = def and def.State and def.State() or "Ready"
	if not def then
		c.Button.Text, c.Button.BackgroundColor3, c.Status.Text = "...", C.Grey, ""
	elseif state == "Active" and def.Recall then
		c.Button.Text, c.Button.BackgroundColor3, c.Status.Text = "RECALL", C.Red, "IN THE AIR"
	elseif state == "Leaving" then
		c.Button.Text, c.Button.BackgroundColor3, c.Status.Text = "LEAVING", C.Grey, "RETURNING TO BASE"
	else
		local cost = Economy.Skills[id]
		local left = cooldownLeft(id)
		if left > 0 then
			c.Button.Text, c.Button.BackgroundColor3, c.Status.Text = string.format("%ds", math.ceil(left)), C.Grey, "COOLDOWN"
		elseif cost and (player:GetAttribute("Points") or 0) < cost.Points then
			c.Button.Text, c.Button.BackgroundColor3, c.Status.Text = "CALL", C.Grey, "NOT ENOUGH POINTS"
		else
			c.Button.Text, c.Button.BackgroundColor3, c.Status.Text = "CALL", C.Green, ""
		end
	end
end

local function setPage(page)
	openPage = page
	side.Visible = page ~= nil
	shopPage.Visible = page == "Shop"
	skillPage.Visible = page == "Skills"
	shopStroke.Color = page == "Shop" and C.Accent or C.Line
	skillsStroke.Color = page == "Skills" and C.Accent or C.Line
	shopStroke.Thickness = page == "Shop" and 2 or 1
	skillsStroke.Thickness = page == "Skills" and 2 or 1
	if page == "Shop" then
		sideTitle.Text, sideSub.Text = "SHOP", "Defences  ·  paid with money"
	elseif page == "Skills" then
		sideTitle.Text, sideSub.Text = "SKILLS", "Support  ·  paid with points"
		for id in pairs(skillCards) do
			refreshSkill(id)
		end
	end
	list.CanvasPosition = Vector2.zero
end

shopBtn.Activated:Connect(function()
	setPage(openPage ~= "Shop" and "Shop" or nil)
end)
skillsBtn.Activated:Connect(function()
	setPage(openPage ~= "Skills" and "Skills" or nil)
end)
sideClose.Activated:Connect(function()
	setPage(nil)
end)

for id, c in pairs(skillCards) do
	c.Button.Activated:Connect(function()
		local def = SkillActions.get(id)
		if not def then
			return
		end
		local state = def.State and def.State() or "Ready"
		if state == "Active" and def.Recall then
			def.Recall()
			return
		elseif state ~= "Ready" then
			return
		end
		local cost = Economy.Skills[id]
		local left = cooldownLeft(id)
		if left > 0 then
			showToast(string.format("Skill ready in %d s", math.ceil(left)))
			return
		elseif cost and (player:GetAttribute("Points") or 0) < cost.Points then
			showToast(string.format("Not enough points (%d)", cost.Points))
			return
		end
		setPage(nil)
		InputMode.blockClicks(0.2) -- this click must not reach the world
		InputMode.exit()
		def.Call()
	end)
end
SkillActions.Changed:Connect(refreshSkill)

---------------------------------------------------------------- behaviour: unit slots
local function refreshSlot(i)
	local s = slots[i]
	local def = UnitSlots.get(i)
	if not def then
		s.Name.Text, s.Name.TextColor3 = "EMPTY", C.Muted
		s.Cost.Text = ""
		s.Count.Text = ""
		s.Frame.BackgroundTransparency = 0.35
		return
	end
	s.Name.Text, s.Name.TextColor3 = def.Name, C.Text
	local e = def.Economy and Economy.Units[def.Economy]
	local price = (e and e.Cost) or def.Cost
	s.Cost.Text = "$ " .. (price and tostring(price) or DASH)
	s.Frame.BackgroundTransparency = 0.12
	if def.BuildIcon and not s.IconBuilt then
		s.IconBuilt = def.BuildIcon(s.Viewport) ~= false
	end
end

local function useSlot(i)
	local def = UnitSlots.get(i)
	if not def then
		return
	end
	if InputMode.get() == def.Mode then
		InputMode.exit(def.Mode) -- pressing the active slot again cancels
		return
	end
	local e = def.Economy and Economy.Units[def.Economy]
	if e then
		local left = cooldownLeft(def.Economy)
		if left > 0 then
			showToast(string.format("%s ready in %d s", e.Label or def.Name, math.ceil(left)))
			return
		elseif (player:GetAttribute("Money") or 0) < e.Cost then
			showToast(string.format("Not enough money ($%d)", e.Cost))
			return
		end
	end
	setPage(nil)
	InputMode.blockClicks(0.2)
	def.Call()
end

for i, s in ipairs(slots) do
	refreshSlot(i)
	s.Click.Activated:Connect(function()
		useSlot(i)
	end)
end
UnitSlots.Changed:Connect(refreshSlot)

local KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4, [Enum.KeyCode.KeypadFive] = 5, [Enum.KeyCode.KeypadSix] = 6,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if InputMode.isTyping() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and openPage then
		setPage(nil)
		return
	end
	if gameProcessed then
		return
	end
	local i = KEYS[input.KeyCode]
	if i then
		useSlot(i)
	end
end)

---------------------------------------------------------------- behaviour: hint bar
local function refreshHint(mode)
	local _, def = SkillActions.byMode(mode)
	local text = def and def.Hint
	local cancelKey = "Esc / X"
	if not text then
		for i = 1, 6 do
			local u = UnitSlots.get(i)
			if u and u.Mode == mode and u.Hint then
				text = u.Hint
				cancelKey = u.CancelKey or "X"
			end
		end
	end
	hint.Visible = text ~= nil
	if text then
		hintText.Text = text .. "   (" .. cancelKey .. " = cancel)"
	end
	for i, s in ipairs(slots) do
		local u = UnitSlots.get(i)
		local on = u ~= nil and mode ~= nil and u.Mode == mode
		s.Stroke.Color = on and C.Accent or C.Line
		s.Stroke.Thickness = on and 2 or 1
	end
end
InputMode.Changed:Connect(refreshHint)
game:GetService("UserInputService").InputBegan:Connect(function(input,processed)
 if processed or InputMode.isTyping() or input.KeyCode~=Enum.KeyCode.X then return end
 local mode=InputMode.get()
 if mode and SkillActions.byMode(mode) then InputMode.blockClicks(.25) InputMode.exit(mode) return end -- X cancels any skill aim
 for i=1,6 do
  local unit=UnitSlots.get(i)
  if unit and unit.Mode==mode then InputMode.blockClicks(.25) InputMode.exit(mode) return end
 end
end)
cancelBtn.Activated:Connect(function()
	InputMode.blockClicks(0.2)
	InputMode.exit()
end)

---------------------------------------------------------------- behaviour: wave / wallet (placeholders until those systems exist)
local function refreshAuto()
	local on = player:GetAttribute("AutoSkip") == true
	autoBtn.Text = on and "ON" or "OFF"
	TweenService:Create(autoBtn, TweenInfo.new(0.15), { BackgroundColor3 = on and C.Green or C.Grey }):Play()
end
autoBtn.Activated:Connect(function()
	local on = not (player:GetAttribute("AutoSkip") == true)
	player:SetAttribute("AutoSkip", on)
	-- client attributes do not reach the server: tell WaveServer
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("MatchCommand")
	if remote then
		remote:FireServer("AutoSkip", on)
	end
end)
player:GetAttributeChangedSignal("AutoSkip"):Connect(refreshAuto)
refreshAuto()

local function refreshWave()
	local w = ReplicatedStorage:GetAttribute("MatchWave") or 0
	local total = ReplicatedStorage:GetAttribute("MatchWaveTotal") or 30
	local left = ReplicatedStorage:GetAttribute("MatchEnemiesLeft") or 0
	local phase = ReplicatedStorage:GetAttribute("MatchPhase") or "Waiting"
	waveTitle.Text = string.format("WAVE %d / %d", w, total)
	waveSub.Text = string.format("ENEMIES LEFT  %d", left)
	phaseTag.Text = string.upper(phase)
	-- WaveServer sets MatchCanSkip once a wave has run 60 s with enemies still alive
	local canSkip = ReplicatedStorage:GetAttribute("MatchCanSkip") == true
	skipBtn.Text = "SKIP WAVE"
	skipBtn.Visible = canSkip
	skipBtn.TextColor3 = canSkip and C.Text or C.Muted
	skipBtn.AutoButtonColor = canSkip
end
for _, a in ipairs({ "MatchWave", "MatchWaveTotal", "MatchEnemiesLeft", "MatchPhase", "MatchCanSkip" }) do
	ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refreshWave)
end
refreshWave()
skipBtn.Activated:Connect(function()
	-- the wave system will listen for this; nothing to skip until waves exist
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("MatchCommand")
	if remote and ReplicatedStorage:GetAttribute("MatchCanSkip") == true then
		remote:FireServer("Skip")
	end
end)

local function refreshWallet()
	local m, p = player:GetAttribute("Money"), player:GetAttribute("Points")
	moneyValue.Text = m and tostring(m) or DASH
	pointsValue.Text = p and tostring(p) or DASH
end
player:GetAttributeChangedSignal("Money"):Connect(refreshWallet)
player:GetAttributeChangedSignal("Points"):Connect(refreshWallet)
refreshWallet()

---------------------------------------------------------------- slot counts (cheap: 5 Hz)
task.spawn(function()
	while gui.Parent do
		for i, s in ipairs(slots) do
			local def = UnitSlots.get(i)
			if def and def.BuildIcon and not s.IconBuilt then
				s.IconBuilt = def.BuildIcon(s.Viewport) ~= false -- model may load late
			end
			if def and def.Count then
				local n, max = def.Count()
				s.Count.Text = string.format("%d/%d", n, max)
				s.Count.TextColor3 = n >= max and C.Red or C.Text
			end
			local e = def and def.Economy and Economy.Units[def.Economy]
			if e then
				local left = cooldownLeft(def.Economy)
				s.Cooldown.Visible = left > 0
				s.CooldownText.Text = left > 0 and tostring(math.ceil(left)) or ""
				s.Cost.TextColor3 = (player:GetAttribute("Money") or 0) >= e.Cost and C.Money or C.Red
			else
				s.Cooldown.Visible = false
			end
		end
		if openPage == "Skills" then
			for id in pairs(skillCards) do
				refreshSkill(id)
			end
		end
		task.wait(0.2)
	end
end)

-- fit small screens: shrink the bottom bar instead of overlapping
local hotbarScale = new("UIScale", {}, hotbar)
local function fit()
	local vp = workspace.CurrentCamera.ViewportSize
	hotbarScale.Scale = math.clamp((vp.X - 2 * 230) / hotbarWidth, 0.6, 1)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
