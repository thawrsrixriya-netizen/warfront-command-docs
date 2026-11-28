-- StarterPlayer.StarterPlayerScripts.LobbyUI  (LocalScript)
-- LobbyUI (client, owner): the 2D lobby shown when a player joins (military-base look, red neon edges).
-- PLAY opens the battlefield map (child module PlayScreen). Layout (owner's sketch): left column PLAY / UNIT / SHOP / TRADE (SOON), two small square buttons under it
-- (settings, leaderboard), a grey "monitor" screen in the middle. Buttons do nothing yet (hover only).
-- While the lobby is open it covers the match and swallows game keys. Admins (EconomyConfig.Admins) get a small
-- "CLOSE LOBBY (TEST)" button; when closed, a small "LOBBY" button reopens it.
-- Other scripts: player attribute InLobby (true while open).
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage:WaitForChild("EconomyConfig"))
local player = Players.LocalPlayer
local isAdmin = EconomyConfig.Admins[player.UserId] == true

local C = {
	Bg1 = Color3.fromRGB(14, 17, 15),
	Bg2 = Color3.fromRGB(28, 32, 27),
	Steel = Color3.fromRGB(34, 38, 36),
	SteelHi = Color3.fromRGB(48, 53, 50),
	Neon = Color3.fromRGB(255, 40, 40),
	NeonSoft = Color3.fromRGB(255, 90, 90),
	Text = Color3.fromRGB(236, 230, 226),
	Muted = Color3.fromRGB(140, 140, 135),
	Screen = Color3.fromRGB(78, 82, 86),
	ScreenDark = Color3.fromRGB(58, 61, 64),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 4) }, p)
end
-- red neon edge: a sharp line + a soft wider glow
local function neon(p, thickness)
	local glow = new("UIStroke", { Color = C.Neon, Thickness = (thickness or 2) + 5, Transparency = 0.82, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	local line = new("UIStroke", { Color = C.Neon, Thickness = thickness or 2, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	return line, glow
end

local gui = new("ScreenGui", { Name = "Lobby", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------- background: base wall, grid, vignette, hazard bands
-- note: a UIGradient's colours MULTIPLY the background colour, so gradient parents use white
local bg = new("TextButton", { Name = "Background", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
new("UIGradient", { Rotation = 70, Color = ColorSequence.new(C.Bg2, C.Bg1) }, bg)
local grid = new("Frame", { Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bg)
for i = 0, 40 do
	new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(i / 40, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(70, 80, 70), BackgroundTransparency = 0.9, BorderSizePixel = 0 }, grid)
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, i / 24, 0), BackgroundColor3 = Color3.fromRGB(70, 80, 70), BackgroundTransparency = 0.9, BorderSizePixel = 0 }, grid)
end
local function band(y, anchorY)
	local b = new("Frame", { Name = "HazardBand", AnchorPoint = Vector2.new(0, anchorY), Position = UDim2.new(0, 0, y, 0), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = C.Steel, BorderSizePixel = 0, ClipsDescendants = true }, bg)
	for i = 0, 120 do
		new("Frame", { Size = UDim2.fromOffset(10, 30), Position = UDim2.fromOffset(i * 24 - 10, -10), Rotation = 45, BackgroundColor3 = Color3.fromRGB(120, 25, 25), BorderSizePixel = 0 }, b)
	end
	new("Frame", { AnchorPoint = Vector2.new(0, anchorY == 0 and 1 or 0), Position = UDim2.new(0, 0, anchorY == 0 and 1 or 0, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Neon, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, b)
	return b
end
band(0, 0)
band(1, 1)
local vignette = new("Frame", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, BackgroundTransparency = 0 }, bg)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0.35) }) }, vignette)

-- the main lobby page (menu + monitor); hidden while a sub-screen such as PLAY is open
local main = new("Frame", { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)

---------------------------------------------------------------- left column
local LEFT, TOP, COL_W, BTN_H = 28, 70, 330, 128
local column = new("Frame", { Name = "Menu", Position = UDim2.fromOffset(LEFT, TOP), Size = UDim2.fromOffset(COL_W, BTN_H * 4), BackgroundTransparency = 1 }, main)

local buttons = {}
local function menuButton(i, title, sub, disabled)
	local b = new("TextButton", {
		Name = title,
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, (i - 1) * BTN_H),
		Size = UDim2.fromOffset(COL_W, BTN_H - 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, column)
	corner(b, 3)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.SteelHi, C.Steel) }, b)
	local line, glow = neon(b, 2)
	-- side marker + rivets
	local marker = new("Frame", { Name = "Marker", Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0, 5, 1, -20), BackgroundColor3 = C.Neon, BorderSizePixel = 0 }, b)
	for _, pos in ipairs({ UDim2.fromOffset(10, 8), UDim2.new(1, -16, 0, 8), UDim2.new(0, 10, 1, -14), UDim2.new(1, -16, 1, -14) }) do
		corner(new("Frame", { Size = UDim2.fromOffset(6, 6), Position = pos, BackgroundColor3 = Color3.fromRGB(80, 85, 82), BorderSizePixel = 0 }, b), 3)
	end
	local label = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -60, 1, sub and -22 or 0),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = disabled and C.Muted or C.Text,
		Text = title,
	}, b)
	if sub then
		new("TextLabel", {
			Name = "Tag",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 32, 1, -42),
			Size = UDim2.new(1, -60, 0, 18),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.NeonSoft,
			Text = sub,
		}, b)
	end
	if disabled then
		line.Transparency, glow.Transparency, marker.BackgroundTransparency = 0.6, 0.95, 0.6
	end
	-- hover: brighter glow, slight slide (buttons do nothing yet)
	b.MouseEnter:Connect(function()
		if disabled then
			return
		end
		TweenService:Create(glow, TweenInfo.new(0.15), { Transparency = 0.55 }):Play()
		TweenService:Create(label, TweenInfo.new(0.15), { Position = UDim2.fromOffset(40, 0) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.15), { Transparency = disabled and 0.95 or 0.82 }):Play()
		TweenService:Create(label, TweenInfo.new(0.15), { Position = UDim2.fromOffset(30, 0) }):Play()
	end)
	buttons[title] = b
	return b
end
menuButton(1, "PLAY")
menuButton(2, "UNIT")
menuButton(3, "SHOP")
menuButton(4, "TRADE", "SOON", true)

-- two small square buttons under the column: settings, leaderboard
local function squareButton(x, name, icon, fallback)
	local b = new("ImageButton", {
		Name = name,
		AutoButtonColor = false,
		Position = UDim2.fromOffset(LEFT + x, TOP + BTN_H * 4 + 6),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Steel,
		BorderSizePixel = 0,
		Image = "",
	}, main)
	corner(b, 3)
	local _, glow = neon(b, 2)
	new("ImageLabel", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Image = icon, ImageColor3 = C.Text }, b)
	b:SetAttribute("Label", fallback)
	b.MouseEnter:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.15), { Transparency = 0.55 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.15), { Transparency = 0.82 }):Play()
	end)
	buttons[name] = b
	return b
end
squareButton(0, "Settings", "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png", "SETTINGS")
squareButton(70, "Leaderboard", "rbxasset://textures/ui/Settings/MenuBarIcons/PlayersTabIcon.png", "LEADERBOARD")

---------------------------------------------------------------- centre: grey monitor screen
local screenLeft = LEFT + COL_W + 40
local monitor = new("Frame", {
	Name = "Monitor",
	Position = UDim2.new(0, screenLeft, 0, TOP),
	Size = UDim2.new(1, -(screenLeft + 40), 1, -(TOP + 60)),
	BackgroundColor3 = C.Steel,
	BorderSizePixel = 0,
}, main)
corner(monitor, 6)
neon(monitor, 2)
local glass = new("Frame", { Name = "Screen", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true }, monitor)
corner(glass, 4)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Screen, C.ScreenDark) }, glass)
for i = 0, 150 do -- scanlines
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, i * 4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.88, BorderSizePixel = 0 }, glass)
end
new("TextLabel", { Name = "Status", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 18), Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 195, 190), TextTransparency = 0.3, Text = "WARFRONT COMMAND // MONITOR 01 // STANDBY" }, glass)
-- corner brackets on the monitor
for _, a in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
	local br = new("Frame", { AnchorPoint = Vector2.new(a[1], a[2]), Position = UDim2.new(a[1], a[1] == 0 and -6 or 6, a[2], a[2] == 0 and -6 or 6), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1 }, monitor)
	new("Frame", { AnchorPoint = Vector2.new(a[1], a[2]), Position = UDim2.fromScale(a[1], a[2]), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.NeonSoft, BorderSizePixel = 0 }, br)
	new("Frame", { AnchorPoint = Vector2.new(a[1], a[2]), Position = UDim2.fromScale(a[1], a[2]), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = C.NeonSoft, BorderSizePixel = 0 }, br)
end

---------------------------------------------------------------- open / close (admin test)
local SINK = "LobbySinkKeys"
local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
	Enum.KeyCode.M, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space,
	Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Z, Enum.KeyCode.F, Enum.KeyCode.T, Enum.KeyCode.C, Enum.KeyCode.G,
	Enum.KeyCode.X, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
}
local reopen
local function setOpen(open)
	gui.Enabled = open
	player:SetAttribute("InLobby", open)
	if open then
		ContextActionService:BindActionAtPriority(SINK, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 200, table.unpack(KEYS))
	else
		ContextActionService:UnbindAction(SINK)
	end
	if reopen then
		reopen.Visible = not open
	end
end

if isAdmin then
	local close = new("TextButton", { Name = "CloseTest", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), ZIndex = 5, Size = UDim2.fromOffset(170, 30), BackgroundColor3 = C.Steel, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.Text, Text = "CLOSE LOBBY (TEST)" }, gui)
	corner(close, 3)
	neon(close, 1)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	local tiny = new("ScreenGui", { Name = "LobbyReopen", ResetOnSpawn = false, DisplayOrder = 49 }, player.PlayerGui)
	reopen = new("TextButton", { Name = "Lobby", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(80, 26), BackgroundColor3 = C.Steel, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.Text, Text = "LOBBY", Visible = false }, tiny)
	corner(reopen, 3)
	neon(reopen, 1)
	reopen.Activated:Connect(function()
		setOpen(true)
	end)
end

---------------------------------------------------------------- PLAY -> battlefield map screen (child module PlayScreen)
local PlayScreen = require(script:WaitForChild("PlayScreen"))
local play
play = PlayScreen.new(gui, function()
	play.Close()
	main.Visible = true
end)
buttons.PLAY.Activated:Connect(function()
	main.Visible = false
	play.Open()
end)

setOpen(true)
