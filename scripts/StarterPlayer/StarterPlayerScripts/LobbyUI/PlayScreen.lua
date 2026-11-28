-- StarterPlayer.StarterPlayerScripts.LobbyUI.PlayScreen  (ModuleScript)
-- PlayScreen (client, owner): the lobby's PLAY window — a country map (LobbyMapConfig) with battlefield
-- markers. Click a marker -> panel on the right (picture placeholder, status, 4-slot weather forecast) and a
-- line from the marker to the panel. NEXT (bottom right) lights up for playable places; it does nothing yet.
-- BACK (top right) returns to the lobby menu.
-- API: local screen = PlayScreen.new(parentGui, onBack); screen.Open(); screen.Close(); screen.Selected()
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Map = require(ReplicatedStorage:WaitForChild("LobbyMapConfig"))

local C = {
	SeaA = Color3.fromRGB(26, 36, 38), SeaB = Color3.fromRGB(16, 22, 24),
	Land = Color3.fromRGB(58, 68, 62), LandEdge = Color3.fromRGB(128, 146, 136),
	Relief = Color3.fromRGB(125, 135, 120), Contour = Color3.fromRGB(120, 132, 118),
	River = Color3.fromRGB(70, 104, 116), Road = Color3.fromRGB(150, 150, 135),
	Grid = Color3.fromRGB(140, 160, 150),
	Steel = Color3.fromRGB(30, 34, 33), SteelHi = Color3.fromRGB(44, 49, 47),
	Neon = Color3.fromRGB(255, 40, 40), NeonSoft = Color3.fromRGB(255, 90, 90),
	Text = Color3.fromRGB(236, 230, 226), Muted = Color3.fromRGB(140, 145, 140),
	Marker = Color3.fromRGB(205, 212, 205), Pick = Color3.fromRGB(255, 70, 50),
	Ok = Color3.fromRGB(110, 220, 120),
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
	return new("UICorner", { CornerRadius = UDim.new(0, r or 3) }, p)
end
local function neon(p, t)
	local glow = new("UIStroke", { Color = C.Neon, Thickness = (t or 2) + 5, Transparency = 0.82, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	local line = new("UIStroke", { Color = C.Neon, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	return line, glow
end

local PlayScreen = {}

function PlayScreen.new(parentGui, onBack)
	local root = new("Frame", { Name = "PlayScreen", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, parentGui)

	------------------------------------------------------------ the map (everything in 0..1 scale of `map`)
	local map = new("TextButton", { Name = "Map", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, root)
	new("UIGradient", { Rotation = 25, Color = ColorSequence.new(C.SeaA, C.SeaB) }, map) -- sea

	-- land: scanline fill of a polygon (UI cannot draw polygons), in scale so it follows the screen size
	local landLayer = new("Frame", { Name = "Land", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, map)
	local ROWS = 360
	local function fillPolygon(poly)
		for r = 0, ROWS - 1 do
			local y = (r + 0.5) / ROWS
			local xs = {}
			for i = 1, #poly do
				local a, b = poly[i], poly[i % #poly + 1]
				if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
					table.insert(xs, a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1]))
				end
			end
			table.sort(xs)
			for k = 1, #xs - 1, 2 do
				new("Frame", { Position = UDim2.fromScale(xs[k], r / ROWS), Size = UDim2.new(xs[k + 1] - xs[k], 0, 1 / ROWS, 1), BackgroundColor3 = C.Land, BorderSizePixel = 0 }, landLayer)
			end
		end
	end
	fillPolygon(Map.Land)
	for _, isl in ipairs(Map.Islands) do
		fillPolygon(isl)
	end

	-- relief: soft light blobs + faint contour rings for each mountain (sizes follow the map height)
	local relief = new("Frame", { Name = "Relief", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, map)
	for _, mt in ipairs(Map.Mountains) do
		local x, y, r = mt[1], mt[2], mt[3]
		for layer = 1, 6 do
			local s = r * 2 * (1 - (layer - 1) * 0.15)
			local blob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x + (layer - 1) * 0.002, y - (layer - 1) * 0.004), Size = UDim2.fromScale(s, s), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = C.Relief, BackgroundTransparency = 0.93, BorderSizePixel = 0 }, relief)
			corner(blob, 999)
			blob:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
		end
		for ring = 1, 3 do
			local s = r * 2 * (0.35 + ring * 0.25)
			local c = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(s, s * 0.8), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1 }, relief)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, c)
			new("UIStroke", { Color = C.Contour, Transparency = 0.8, Thickness = 1 }, c)
		end
	end

	-- grid + coordinates
	local grid = new("Frame", { Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, map)
	for i = 1, 9 do
		new("Frame", { Position = UDim2.fromScale(i / 10, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.Grid, BackgroundTransparency = 0.93, BorderSizePixel = 0 }, grid)
		new("Frame", { Position = UDim2.fromScale(0, i / 10), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Grid, BackgroundTransparency = 0.93, BorderSizePixel = 0 }, grid)
		new("TextLabel", { Position = UDim2.new(i / 10, 3, 1, -16), Size = UDim2.fromOffset(30, 12), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10, TextColor3 = C.Grid, TextTransparency = 0.6, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%02d", i * 10) }, grid)
		new("TextLabel", { Position = UDim2.new(0, 4, i / 10, 2), Size = UDim2.fromOffset(30, 12), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10, TextColor3 = C.Grid, TextTransparency = 0.6, TextXAlignment = Enum.TextXAlignment.Left, Text = string.char(64 + i) }, grid)
	end

	-- names written on the map
	new("TextLabel", { Name = "Country", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.30, 0.40), Size = UDim2.fromScale(0.4, 0.08), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = C.Text, TextTransparency = 0.88, Text = Map.Country }, map)
	new("TextLabel", { Name = "Sea", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.82, 0.45), Size = UDim2.fromScale(0.3, 0.05), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = C.Text, TextTransparency = 0.85, Text = Map.SeaName }, map)

	-- pixel lines (coast, rivers, roads) are rebuilt whenever the screen size changes
	local lines = new("Frame", { Name = "Lines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, map)
	local byId = {}
	for _, loc in ipairs(Map.Locations) do
		byId[loc.Id] = loc
	end
	local function seg(parent, a, b, color, thick, transp)
		local size = map.AbsoluteSize
		local ax, ay, bx, by = a[1] * size.X, a[2] * size.Y, b[1] * size.X, b[2] * size.Y
		local dx, dy = bx - ax, by - ay
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2), Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, thick), Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = color, BackgroundTransparency = transp, BorderSizePixel = 0 }, parent)
	end
	local function dashed(parent, a, b, color, thick, transp, dash, gap)
		local size = map.AbsoluteSize
		local len = math.sqrt(((b[1] - a[1]) * size.X) ^ 2 + ((b[2] - a[2]) * size.Y) ^ 2)
		if len < 1 then
			return
		end
		local t = 0
		while t < len do
			local t2 = math.min(t + dash, len)
			seg(parent, { a[1] + (b[1] - a[1]) * t / len, a[2] + (b[2] - a[2]) * t / len }, { a[1] + (b[1] - a[1]) * t2 / len, a[2] + (b[2] - a[2]) * t2 / len }, color, thick, transp)
			t += dash + gap
		end
	end
	local function drawLines()
		lines:ClearAllChildren()
		local function outline(poly)
			for i = 1, #poly do
				seg(lines, poly[i], poly[i % #poly + 1], C.LandEdge, 2, 0.35)
			end
		end
		outline(Map.Land)
		for _, isl in ipairs(Map.Islands) do
			outline(isl)
		end
		for _, river in ipairs(Map.Rivers) do
			for i = 1, #river - 1 do
				seg(lines, river[i], river[i + 1], C.River, 2, 0.2)
			end
		end
		for _, road in ipairs(Map.Roads) do
			local a, b = byId[road[1]], byId[road[2]]
			if a and b then
				dashed(lines, a.Pos, b.Pos, C.Road, 1, 0.45, 6, 5)
			end
		end
	end

	-- vignette over the map
	local vig = new("Frame", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, map)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.8, 1), NumberSequenceKeypoint.new(1, 0.4) }) }, vig)

	------------------------------------------------------------ markers
	local markers = new("Frame", { Name = "Markers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, root)
	local selected
	local select -- forward
	local markerFrames = {}
	for _, loc in ipairs(Map.Locations) do
		local holder = new("TextButton", { Name = loc.Id, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(loc.Pos[1], -11, loc.Pos[2], 0), Size = UDim2.fromOffset(220, 30), BackgroundTransparency = 1 }, markers)
		local diamond = new("Frame", { Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11, 15), Size = UDim2.fromOffset(14, 14), Rotation = 45, BackgroundColor3 = C.SeaB, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, holder)
		local dStroke = new("UIStroke", { Color = C.Marker, Thickness = 2 }, diamond)
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = C.Marker, BorderSizePixel = 0 }, diamond)
		local label = new("TextLabel", { Name = "Label", Position = UDim2.fromOffset(28, 3), Size = UDim2.new(1, -28, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = loc.Playable and C.Text or C.Muted, TextStrokeTransparency = 0.6, Text = loc.Name }, holder)
		local underline = new("Frame", { Position = UDim2.fromOffset(28, 24), Size = UDim2.fromOffset(label.TextBounds.X > 0 and label.TextBounds.X or 120, 1), BackgroundColor3 = loc.Playable and C.Text or C.Muted, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, holder)
		label:GetPropertyChangedSignal("TextBounds"):Connect(function()
			underline.Size = UDim2.fromOffset(label.TextBounds.X, 1)
		end)
		if not loc.Playable then
			new("TextLabel", { Name = "Locked", Position = UDim2.fromOffset(28, 26), Size = UDim2.fromOffset(120, 12), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted, Text = "LOCKED" }, holder)
		end
		markerFrames[loc.Id] = { Holder = holder, Diamond = diamond, Stroke = dStroke, Dot = dot, Label = label, Loc = loc }
		holder.MouseEnter:Connect(function()
			if selected ~= loc then
				dStroke.Color = C.NeonSoft
			end
		end)
		holder.MouseLeave:Connect(function()
			if selected ~= loc then
				dStroke.Color = C.Marker
			end
		end)
		holder.Activated:Connect(function()
			select(loc)
		end)
	end

	------------------------------------------------------------ top bar: MAP title, BACK
	local title = new("Frame", { Name = "Title", Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(200, 46), BackgroundColor3 = C.Steel, BorderSizePixel = 0, ZIndex = 4 }, root)
	corner(title)
	neon(title, 2)
	new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 26, TextColor3 = C.Text, Text = Map.Title, ZIndex = 4 }, title)
	local back = new("TextButton", { Name = "Back", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 18), Size = UDim2.fromOffset(140, 46), BackgroundColor3 = C.Steel, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = C.Text, Text = "BACK", AutoButtonColor = false, ZIndex = 4 }, root)
	corner(back)
	local _, backGlow = neon(back, 2)
	back.MouseEnter:Connect(function()
		backGlow.Transparency = 0.55
	end)
	back.MouseLeave:Connect(function()
		backGlow.Transparency = 0.82
	end)

	------------------------------------------------------------ right panel (shown when a place is selected)
	local PANEL_W = 340
	local panel = new("Frame", { Name = "Panel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 100), Size = UDim2.fromOffset(PANEL_W, 410), BackgroundColor3 = C.Steel, BackgroundTransparency = 0.05, BorderSizePixel = 0, Visible = false, ZIndex = 4 }, root)
	corner(panel)
	neon(panel, 2)
	local pName = new("TextLabel", { Name = "Name", Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 26), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Text, ZIndex = 4 }, panel)
	local pStatus = new("TextLabel", { Name = "Status", Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -32, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 }, panel)
	local picture = new("ImageLabel", { Name = "Picture", Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 170), BackgroundColor3 = Color3.fromRGB(20, 24, 24), BorderSizePixel = 0, Image = "", ScaleType = Enum.ScaleType.Crop, ZIndex = 4 }, panel)
	new("UIStroke", { Color = C.NeonSoft, Thickness = 2, Transparency = 0.2 }, picture)
	local noPic = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 14, TextColor3 = C.Muted, Text = "NO IMAGE", ZIndex = 4 }, picture)
	local pInfo = new("TextLabel", { Name = "Info", Position = UDim2.fromOffset(16, 238), Size = UDim2.new(1, -32, 0, 40), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Muted, ZIndex = 4 }, panel)
	new("TextLabel", { Name = "WeatherTitle", Position = UDim2.fromOffset(16, 282), Size = UDim2.new(1, -32, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Text, Text = "WEATHER FORECAST", ZIndex = 4 }, panel)
	local slots = {}
	local SLOT_W = math.floor((PANEL_W - 32 - 3 * 8) / 4)
	for i, w in ipairs(Map.WeatherSlots) do
		local slot = new("Frame", { Name = w.Key, Position = UDim2.fromOffset(16 + (i - 1) * (SLOT_W + 8), 306), Size = UDim2.fromOffset(SLOT_W, 84), BackgroundColor3 = C.SteelHi, BorderSizePixel = 0, ZIndex = 4 }, panel)
		corner(slot)
		local st = new("UIStroke", { Color = C.NeonSoft, Thickness = 1, Transparency = 0.5 }, slot)
		local icon = new("TextLabel", { Name = "Icon", Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 30, TextColor3 = C.Text, Text = w.Icon, ZIndex = 4 }, slot)
		local lbl = new("TextLabel", { Name = "Label", Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.Text, Text = w.Label, ZIndex = 4 }, slot)
		slots[w.Key] = { Frame = slot, Stroke = st, Icon = icon, Label = lbl }
	end

	-- line from the selected marker to the panel
	local link = new("Frame", { Name = "Link", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Pick, BorderSizePixel = 0, Visible = false, ZIndex = 3 }, root)

	------------------------------------------------------------ NEXT
	local nextBtn = new("TextButton", { Name = "Next", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(340, 96), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 4 }, root)
	corner(nextBtn)
	-- the text is a child label: a UIGradient also tints its parent's own text
	local nextText = new("TextLabel", { Name = "Label", Size = UDim2.new(1, 0, 1, -10), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 38, Text = "NEXT", ZIndex = 5 }, nextBtn)
	local nextGrad = new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.fromRGB(60, 62, 60), Color3.fromRGB(40, 42, 40)) }, nextBtn)
	local nextLine, nextGlow = neon(nextBtn, 2)
	local nextHint = new("TextLabel", { Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.Text, TextTransparency = 0.3, Text = "SELECT A BATTLEFIELD", ZIndex = 5 }, nextBtn)
	local function setNext(enabled)
		nextText.TextColor3 = enabled and C.Text or C.Muted
		nextGrad.Color = enabled and ColorSequence.new(Color3.fromRGB(210, 40, 30), Color3.fromRGB(140, 20, 16)) or ColorSequence.new(Color3.fromRGB(60, 62, 60), Color3.fromRGB(40, 42, 40))
		nextLine.Transparency = enabled and 0 or 0.6
		nextGlow.Transparency = enabled and 0.7 or 0.95
		nextHint.Text = enabled and "" or (selected and "LOCKED - COMING SOON" or "SELECT A BATTLEFIELD")
		nextBtn:SetAttribute("Enabled", enabled)
	end
	nextBtn.MouseEnter:Connect(function()
		if nextBtn:GetAttribute("Enabled") then
			nextGlow.Transparency = 0.45
		end
	end)
	nextBtn.MouseLeave:Connect(function()
		nextGlow.Transparency = nextBtn:GetAttribute("Enabled") and 0.7 or 0.95
	end)
	-- NEXT does nothing yet (the owner will design the next screen)

	------------------------------------------------------------ selection
	local function placeLink()
		if not selected then
			link.Visible = false
			return
		end
		local mf = markerFrames[selected.Id]
		local a = mf.Diamond.AbsolutePosition + mf.Diamond.AbsoluteSize / 2 - root.AbsolutePosition
		local b = Vector2.new(panel.AbsolutePosition.X - root.AbsolutePosition.X, panel.AbsolutePosition.Y - root.AbsolutePosition.Y + 24)
		local d = b - a
		link.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		link.Size = UDim2.fromOffset(d.Magnitude, 2)
		link.Rotation = math.deg(math.atan2(d.Y, d.X))
		link.Visible = true
	end

	function select(loc)
		selected = loc
		for id, mf in pairs(markerFrames) do
			local on = loc and id == loc.Id
			mf.Stroke.Color = on and C.Pick or C.Marker
			mf.Dot.BackgroundColor3 = on and C.Pick or C.Marker
			mf.Diamond.Size = on and UDim2.fromOffset(20, 20) or UDim2.fromOffset(14, 14)
			mf.Label.TextColor3 = on and C.Pick or (mf.Loc.Playable and C.Text or C.Muted)
			mf.Label.TextSize = on and 19 or 16
		end
		panel.Visible = loc ~= nil
		if loc then
			pName.Text = loc.Name
			pStatus.Text = loc.Playable and "AVAILABLE" or "LOCKED - COMING SOON"
			pStatus.TextColor3 = loc.Playable and C.Ok or C.Muted
			picture.Image = loc.Image or ""
			noPic.Visible = (loc.Image or "") == ""
			pInfo.Text = loc.Info or ""
			for _, w in ipairs(Map.WeatherSlots) do
				local s = slots[w.Key]
				local yes = loc.Weather and loc.Weather[w.Key] == true
				s.Frame.BackgroundTransparency = yes and 0 or 0.6
				s.Icon.TextTransparency = yes and 0 or 0.75
				s.Label.TextTransparency = yes and 0 or 0.6
				s.Stroke.Transparency = yes and 0.3 or 0.9
				s.Label.Text = yes and w.Label or (w.Label .. " -")
			end
		end
		setNext(loc ~= nil and loc.Playable == true)
		task.defer(placeLink)
	end

	map.Activated:Connect(function()
		select(nil) -- click empty map = clear selection
	end)
	back.Activated:Connect(function()
		if onBack then
			onBack()
		end
	end)
	map:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		drawLines()
		placeLink()
	end)

	local screen = {}
	function screen.Open()
		root.Visible = true
		task.defer(function()
			drawLines()
			select(selected)
		end)
	end
	function screen.Close()
		root.Visible = false
	end
	function screen.Selected()
		return selected
	end
	setNext(false)
	return screen
end

return PlayScreen
