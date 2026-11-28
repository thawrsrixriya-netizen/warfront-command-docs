-- StarterPlayer.StarterPlayerScripts.LobbyUI.SquadScreen  (ModuleScript)
-- SquadScreen (client, owner): lobby screen after PLAY -> map -> NEXT. Owner's sketch:
--   top: player character (avatar) + "+" box for player 2 (soon); START (does nothing yet) + BACK.
--   bottom: difficulty (EASY/NORMAL/HARD/NIGHTMARE) | UNIT slots 1-6 | SKILL slots 1-3 + DEFENSE slots 1-4 |
--   red box = the player's items (from the shop) with tabs UNITS / SKILLS / DEFENSE, a details strip and loadout points.
-- Click a card to see it and equip/unequip it; click a filled slot to empty it. Units cost loadout points.
-- PLACEHOLDER: state is local only (nothing saved, no shop yet). Data: ReplicatedStorage.LobbyItemsConfig.
-- API: local s = SquadScreen.new(parentGui, onBack); s.Open(location); s.Close(); s.State()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("LobbyItemsConfig"))
local player = Players.LocalPlayer

local C = {
	Steel = Color3.fromRGB(30, 34, 33), SteelHi = Color3.fromRGB(46, 51, 49), Slot = Color3.fromRGB(22, 25, 25),
	SlotBox = Color3.fromRGB(40, 44, 44), SlotFull = Color3.fromRGB(56, 61, 60),
	Neon = Color3.fromRGB(255, 40, 40), NeonSoft = Color3.fromRGB(255, 90, 90),
	Text = Color3.fromRGB(236, 230, 226), Muted = Color3.fromRGB(140, 145, 140), Ok = Color3.fromRGB(110, 220, 120),
	Unit = Color3.fromRGB(90, 160, 220), Skill = Color3.fromRGB(240, 150, 60), Defense = Color3.fromRGB(150, 190, 110),
}
local KIND_COLOR = { Unit = C.Unit, Skill = C.Skill, Defense = C.Defense }

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
local function label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.Text, TextSize = 14 }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end
local function hoverGlow(button, glow, base)
	button.MouseEnter:Connect(function()
		glow.Transparency = 0.5
	end)
	button.MouseLeave:Connect(function()
		glow.Transparency = base or 0.82
	end)
end

local byId = {}
for _, it in ipairs(Items.Items) do
	byId[it.Id] = it
end

local SquadScreen = {}

function SquadScreen.new(parentGui, onBack)
	local root = new("Frame", { Name = "SquadScreen", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, parentGui)

	-- state (local placeholder)
	local state = { Difficulty = Items.DefaultDifficulty, Units = {}, Skills = {}, Defense = {}, Location = nil }
	local selectedItem

	------------------------------------------------------------ top bar
	local title = new("Frame", { Name = "Title", Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(260, 56), BackgroundColor3 = C.Steel, BorderSizePixel = 0 }, root)
	corner(title)
	neon(title, 2)
	label(title, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -32, 0, 30), Font = Enum.Font.GothamBlack, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Text = "SQUAD" })
	local locLabel = label(title, { Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 16), TextSize = 12, TextColor3 = C.NeonSoft, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	local back = new("TextButton", { Name = "Back", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 18), Size = UDim2.fromOffset(140, 46), BackgroundColor3 = C.Steel, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = C.Text, Text = "BACK", AutoButtonColor = false }, root)
	corner(back)
	local _, backGlow = neon(back, 2)
	hoverGlow(back, backGlow)
	back.Activated:Connect(function()
		if onBack then
			onBack()
		end
	end)

	------------------------------------------------------------ player character + player 2
	local charBox = new("Frame", { Name = "Character", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.new(0, 220, 0.5, -44), BackgroundColor3 = C.Slot, BorderSizePixel = 0 }, root)
	corner(charBox, 4)
	neon(charBox, 2)
	local avatar = new("ImageLabel", { Name = "Avatar", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -36), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = "" }, charBox)
	label(charBox, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -12, 0, 20), Font = Enum.Font.GothamBlack, TextSize = 15, Text = string.upper(player.DisplayName) })
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
		end)
		if ok then
			avatar.Image = img
		end
	end)

	local p2 = new("TextButton", { Name = "Player2", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -230, 0.22, 0), Size = UDim2.fromOffset(72, 72), BackgroundColor3 = C.Steel, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextSize = 40, TextColor3 = C.Text, Text = "+", AutoButtonColor = false }, root)
	corner(p2)
	local _, p2Glow = neon(p2, 2)
	hoverGlow(p2, p2Glow)
	label(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -230, 0.22, 42), Size = UDim2.fromOffset(160, 18), TextSize = 14, Text = "PLAYER 2" })
	label(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -230, 0.22, 60), Size = UDim2.fromOffset(160, 14), TextSize = 11, TextColor3 = C.Muted, Text = "INVITE - SOON" })

	------------------------------------------------------------ START (does nothing yet)
	local start = new("TextButton", { Name = "Start", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 0.52, -12), Size = UDim2.fromOffset(300, 74), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Text = "", AutoButtonColor = false }, root)
	corner(start)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(210, 40, 30), Color3.fromRGB(140, 20, 16)) }, start)
	local _, startGlow = neon(start, 2)
	startGlow.Transparency = 0.7
	hoverGlow(start, startGlow, 0.7)
	label(start, { Size = UDim2.new(1, 0, 1, -12), Font = Enum.Font.GothamBlack, TextSize = 36, Text = "START" })
	local startHint = label(start, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextTransparency = 0.25, Text = "" })

	------------------------------------------------------------ bottom area
	local bottom = new("Frame", { Name = "Bottom", Position = UDim2.new(0, 16, 0.52, 0), Size = UDim2.new(1, -32, 0.48, -16), BackgroundTransparency = 1 }, root)
	local HEAD = 24
	local function column(name, x, w, heading, headColor)
		local col = new("Frame", { Name = name, Position = UDim2.fromScale(x, 0), Size = UDim2.new(w, -8, 1, 0), BackgroundTransparency = 1 }, bottom)
		if heading then
			label(col, { Size = UDim2.new(1, 0, 0, HEAD), Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = headColor or C.Text, Text = heading })
		end
		return col
	end

	-- difficulty
	local diffCol = column("Difficulty", 0, 0.17, "DIFFICULTY")
	local diffButtons = {}
	local function refreshDifficulty()
		for id, d in pairs(diffButtons) do
			local on = id == state.Difficulty
			d.Line.Transparency = on and 0 or 0.65
			d.Glow.Transparency = on and 0.55 or 0.95
			d.Title.TextColor3 = on and C.NeonSoft or C.Text
			d.Button.BackgroundColor3 = on and C.SteelHi or C.Steel
		end
	end
	local nd = #Items.Difficulties
	for i, d in ipairs(Items.Difficulties) do
		local b = new("TextButton", { Name = d.Id, Text = "", AutoButtonColor = false, Position = UDim2.new(0, 0, (i - 1) / nd, HEAD + 4 - (i - 1) * (HEAD + 4) / nd), Size = UDim2.new(1, 0, 1 / nd, -(HEAD + 4) / nd - 6), BackgroundColor3 = C.Steel, BorderSizePixel = 0 }, diffCol)
		corner(b)
		local line, glow = neon(b, 2)
		local t = label(b, { Size = UDim2.new(1, 0, 0.7, 0), Font = Enum.Font.GothamBlack, TextSize = 22, Text = d.Label })
		label(b, { Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.3, 0), TextSize = 11, TextColor3 = C.Muted, Text = d.Waves .. " WAVES" })
		diffButtons[d.Id] = { Button = b, Line = line, Glow = glow, Title = t }
		b.Activated:Connect(function()
			state.Difficulty = d.Id
			refreshDifficulty()
		end)
	end

	-- slots
	local slotFrames = { Unit = {}, Skill = {}, Defense = {} }
	local listFor = { Unit = state.Units, Skill = state.Skills, Defense = state.Defense }
	local refreshAll -- forward
	local function makeSlot(parent, kind, index, pos, size)
		local b = new("TextButton", { Name = kind .. index, Text = "", AutoButtonColor = false, Position = pos, Size = size, BackgroundColor3 = C.SlotBox, BorderSizePixel = 0 }, parent)
		corner(b, 4)
		local st = new("UIStroke", { Color = C.NeonSoft, Thickness = 2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local num = new("Frame", { Name = "Number", Size = UDim2.fromOffset(22, 18), BackgroundColor3 = C.Neon, BackgroundTransparency = 0.15, BorderSizePixel = 0 }, b)
		corner(num, 3)
		label(num, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 12, Text = tostring(index) })
		local name = label(b, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 18, Text = "+" })
		local extra = label(b, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -3), Size = UDim2.fromOffset(44, 13), TextSize = 11, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
		slotFrames[kind][index] = { Button = b, Stroke = st, Name = name, Extra = extra }
		b.Activated:Connect(function()
			local list = listFor[kind]
			local id = list[index]
			if id then
				table.remove(list, index) -- empty the slot (later slots move up)
				selectedItem = byId[id]
				refreshAll()
			end
		end)
	end

	local unitCol = column("Units", 0.17, 0.11, "UNIT", C.NeonSoft)
	for i = 1, Items.UnitSlots do
		makeSlot(unitCol, "Unit", i, UDim2.new(0, 0, (i - 1) / Items.UnitSlots, HEAD + 4 - (i - 1) * (HEAD + 4) / Items.UnitSlots), UDim2.new(1, 0, 1 / Items.UnitSlots, -(HEAD + 4) / Items.UnitSlots - 8))
	end
	local skillCol = column("Skills", 0.28, 0.14, "SKILL", C.NeonSoft)
	local nS, nD = Items.SkillSlots, Items.DefenseSlots
	local rows = nS + nD
	local SUB = 20
	local avail = function(i) return UDim2.new(0, 0, (i - 1) / rows, HEAD + 4 - (i - 1) * (HEAD + 4 + SUB) / rows) end
	local rowSize = UDim2.new(1, 0, 1 / rows, -(HEAD + 4 + SUB) / rows - 7)
	for i = 1, nS do
		makeSlot(skillCol, "Skill", i, avail(i), rowSize)
	end
	local defHead = label(skillCol, { Position = UDim2.new(0, 0, nS / rows, HEAD + 4 - nS * (HEAD + 4 + SUB) / rows - 2), Size = UDim2.new(1, 0, 0, SUB), Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = C.NeonSoft, Text = "DEFENSE" })
	for i = 1, nD do
		local p = avail(nS + i)
		makeSlot(skillCol, "Defense", i, UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + SUB), rowSize)
	end

	------------------------------------------------------------ inventory (red box)
	local inv = new("Frame", { Name = "Inventory", Position = UDim2.new(0.42, 0, 0, HEAD + 4), Size = UDim2.new(0.58, 0, 1, -(HEAD + 4)), BackgroundColor3 = C.Steel, BackgroundTransparency = 0.05, BorderSizePixel = 0 }, bottom)
	corner(inv, 4)
	neon(inv, 2)
	label(bottom, { Position = UDim2.fromScale(0.42, 0), Size = UDim2.new(0.58, 0, 0, HEAD), Font = Enum.Font.GothamBlack, TextSize = 15, Text = "YOUR ITEMS (FROM SHOP)" })
	-- details strip
	local detail = new("Frame", { Name = "Detail", Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 64), BackgroundColor3 = C.Slot, BorderSizePixel = 0 }, inv)
	corner(detail)
	local dName = label(detail, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.62, -12, 0, 20), Font = Enum.Font.GothamBlack, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Text = "SELECT AN ITEM" })
	local dDesc = label(detail, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(0.62, -12, 0, 32), Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "Click a card to equip it, click a slot on the left to empty it." })
	local pointsLabel = label(detail, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0.38, -12, 0, 40), Font = Enum.Font.GothamBlack, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	-- tabs
	local tabs = {}
	local currentTab = "Unit"
	local tabRow = new("Frame", { Name = "Tabs", Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1 }, inv)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, tabRow)
	local grid = new("ScrollingFrame", { Name = "Cards", Position = UDim2.fromOffset(12, 120), Size = UDim2.new(1, -24, 1, -130), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, inv)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(118, 96), CellPadding = UDim2.fromOffset(10, 10) }, grid)

	local function usedPoints()
		local n = 0
		for _, id in ipairs(state.Units) do
			n += (byId[id] and byId[id].Points or 0)
		end
		return n
	end
	local function isEquipped(id)
		for _, list in pairs(listFor) do
			if table.find(list, id) then
				return true
			end
		end
		return false
	end
	local function maxFor(kind)
		return kind == "Unit" and Items.UnitSlots or kind == "Skill" and Items.SkillSlots or Items.DefenseSlots
	end
	local flashToken = 0
	local function flash(text)
		flashToken += 1
		local my = flashToken
		dDesc.Text = text
		dDesc.TextColor3 = C.NeonSoft
		task.delay(2, function()
			if my == flashToken then
				dDesc.TextColor3 = C.Muted
				refreshAll()
			end
		end)
	end

	local function toggle(item)
		selectedItem = item
		local list = listFor[item.Kind]
		local at = table.find(list, item.Id)
		if at then
			table.remove(list, at)
		elseif not item.Owned then
			refreshAll()
			flash("Not owned yet - buy it in the SHOP (coming soon).")
			return
		elseif #list >= maxFor(item.Kind) then
			refreshAll()
			flash("All " .. string.lower(item.Kind) .. " slots are full. Click a slot to empty it.")
			return
		elseif item.Kind == "Unit" and usedPoints() + (item.Points or 0) > Items.LoadoutPoints then
			refreshAll()
			flash("Not enough loadout points (" .. usedPoints() .. "/" .. Items.LoadoutPoints .. ").")
			return
		else
			table.insert(list, item.Id)
		end
		refreshAll()
	end

	local function buildCards()
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, item in ipairs(Items.Items) do
			if item.Kind == currentTab then
				local equipped = isEquipped(item.Id)
				local card = new("TextButton", { Name = item.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = equipped and C.SteelHi or C.Slot, BorderSizePixel = 0 }, grid)
				corner(card)
				new("UIStroke", { Color = (selectedItem == item) and C.Neon or (equipped and C.NeonSoft or Color3.fromRGB(70, 75, 72)), Thickness = (selectedItem == item) and 2 or 1 }, card)
				new("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = KIND_COLOR[item.Kind], BorderSizePixel = 0 }, card)
				label(card, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = item.Owned and C.Text or C.Muted, Text = item.Short })
				label(card, { Position = UDim2.fromOffset(4, 52), Size = UDim2.new(1, -8, 0, 16), TextSize = 11, TextColor3 = item.Owned and C.Text or C.Muted, TextTruncate = Enum.TextTruncate.AtEnd, Text = item.Name })
				local status = not item.Owned and "SHOP" or (equipped and "EQUIPPED" or (item.Points and (item.Points .. " PTS") or ""))
				label(card, { Position = UDim2.new(0, 4, 1, -22), Size = UDim2.new(1, -8, 0, 16), TextSize = 10, TextColor3 = not item.Owned and C.Muted or (equipped and C.Ok or C.Muted), Text = status })
				card.Activated:Connect(function()
					toggle(item)
				end)
			end
		end
	end

	for order, t in ipairs({ { "Unit", "UNITS" }, { "Skill", "SKILLS" }, { "Defense", "DEFENSE" } }) do
		local b = new("TextButton", { Name = t[1], LayoutOrder = order, Size = UDim2.fromOffset(120, 30), BackgroundColor3 = C.Slot, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = C.Text, Text = t[2], AutoButtonColor = false }, tabRow)
		corner(b)
		tabs[t[1]] = { Button = b, Stroke = new("UIStroke", { Color = C.Neon, Thickness = 1 }, b) }
		b.Activated:Connect(function()
			currentTab = t[1]
			refreshAll()
		end)
	end

	function refreshAll()
		for kind, frames in pairs(slotFrames) do
			local list = listFor[kind]
			for i, f in pairs(frames) do
				local item = list[i] and byId[list[i]]
				f.Name.Text = item and item.Short or "+"
				f.Name.TextColor3 = item and C.Text or C.Muted
				f.Button.BackgroundColor3 = item and C.SlotFull or C.SlotBox
				f.Extra.Text = (item and item.Points) and (item.Points .. " PTS") or ""
				f.Stroke.Color = item and KIND_COLOR[kind] or C.NeonSoft
				f.Stroke.Transparency = item and 0 or 0.15
			end
		end
		for id, t in pairs(tabs) do
			local on = id == currentTab
			t.Button.BackgroundColor3 = on and C.SteelHi or C.Slot
			t.Button.TextColor3 = on and C.NeonSoft or C.Text
			t.Stroke.Transparency = on and 0 or 0.7
		end
		local used = usedPoints()
		pointsLabel.Text = "LOADOUT " .. used .. "/" .. Items.LoadoutPoints
		pointsLabel.TextColor3 = used >= Items.LoadoutPoints and C.NeonSoft or C.Text
		if selectedItem and dDesc.TextColor3 ~= C.NeonSoft then
			dName.Text = selectedItem.Name .. (selectedItem.Points and ("  -  " .. selectedItem.Points .. " PTS") or "")
			dDesc.Text = selectedItem.Desc or ""
		end
		startHint.Text = (#state.Units == 0) and "ADD AT LEAST 1 UNIT" or "COMING SOON"
		buildCards()
	end

	-- default loadout
	for _, id in ipairs(Items.Default.Units) do
		table.insert(state.Units, id)
	end
	for _, id in ipairs(Items.Default.Skills) do
		table.insert(state.Skills, id)
	end
	for _, id in ipairs(Items.Default.Defense) do
		table.insert(state.Defense, id)
	end
	refreshDifficulty()
	refreshAll()

	local screen = {}
	function screen.Open(location)
		state.Location = location
		locLabel.Text = location and string.upper(location.Name) or ""
		root.Visible = true
		refreshAll()
	end
	function screen.Close()
		root.Visible = false
	end
	function screen.State()
		return state
	end
	return screen
end

return SquadScreen
