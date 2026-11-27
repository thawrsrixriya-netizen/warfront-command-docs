-- ReplicatedStorage.WarClient.UnitCommandPanel  (ModuleScript)
-- UnitCommandPanel (client): the command column on the LEFT side of the screen, under the minimap.
-- It is shown only while one of its menus is visible (= while units are selected).
--
-- HOW A UNIT SCRIPT USES IT (TankControls, InfantryControls, any new unit):
--   local UnitCommandPanel = require(ReplicatedStorage.WarClient.UnitCommandPanel)
--   UnitCommandPanel.adopt(menuFrame, { Title = "INFANTRY" })
-- menuFrame is the Frame that holds the unit's command buttons; the script keeps toggling
-- menuFrame.Visible as before. Every button/label inside it becomes one full-width row, top to
-- bottom in the order they were laid out (Y, then X). Hidden children are skipped.
--
-- TO ADD A NEW COMMAND (e.g. for a new unit or system):
--   local b = UnitCommandPanel.addButton(menuFrame, "K  Smoke", function() ... end, 50)
--   (or create any TextButton inside menuFrame and set its LayoutOrder; it is styled automatically)
--   Set b.Visible = false to hide a command that does not apply right now.
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Panel = {}

local STYLE = {
	Panel = Color3.fromRGB(18, 21, 26),
	Button = Color3.fromRGB(30, 34, 42),
	Line = Color3.fromRGB(70, 78, 92),
	Text = Color3.fromRGB(236, 239, 244),
	Title = Color3.fromRGB(150, 160, 175),
	Width = 200,
	RowHeight = 32,
	Top = 16 + 150 + 12, -- under the minimap (MiniMapConfig: Position 16, Diameter 150)
}
Panel.Style = STYLE

local gui = Instance.new("ScreenGui")
gui.Name = "UnitCommandPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local column = Instance.new("Frame")
column.Name = "Column"
column.Position = UDim2.fromOffset(16, STYLE.Top)
column.Size = UDim2.fromOffset(STYLE.Width, 0)
column.AutomaticSize = Enum.AutomaticSize.Y
column.BackgroundColor3 = STYLE.Panel
column.BackgroundTransparency = 0.1
column.Visible = false
column.Parent = gui
Instance.new("UICorner", column).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke")
stroke.Color = STYLE.Line
stroke.Parent = column
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
pad.Parent = column
local colList = Instance.new("UIListLayout")
colList.SortOrder = Enum.SortOrder.LayoutOrder
colList.Padding = UDim.new(0, 8)
colList.Parent = column

local sections = {} -- [menu] = section frame

local function refresh()
	local any = false
	for menu, section in pairs(sections) do
		local on = menu.Parent ~= nil and menu.Visible
		section.Visible = on
		any = any or on
	end
	column.Visible = any
end

local function styleRow(child)
	if not child:IsA("GuiObject") or child:IsA("UIComponent") then
		return
	end
	child.Size = UDim2.new(1, 0, 0, STYLE.RowHeight)
	child.AutomaticSize = Enum.AutomaticSize.None
	if child:IsA("GuiButton") then
		child.BackgroundColor3 = STYLE.Button
		child.BackgroundTransparency = 0
		if not child:FindFirstChildOfClass("UIStroke") then
			local s = Instance.new("UIStroke")
			s.Color = STYLE.Line
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Parent = child
		end
	end
	if child:IsA("TextButton") or child:IsA("TextLabel") then
		child.TextSize = 14
		child.TextXAlignment = Enum.TextXAlignment.Left
		child.TextTruncate = Enum.TextTruncate.AtEnd
		if not child:FindFirstChild("RowPadding") then
			local p = Instance.new("UIPadding")
			p.Name = "RowPadding"
			p.PaddingLeft = UDim.new(0, 10)
			p.Parent = child
		end
	end
end

function Panel.adopt(menu, opts)
	opts = opts or {}
	if sections[menu] then
		return sections[menu]
	end
	local section = Instance.new("Frame")
	section.Name = (opts.Title or menu.Name) .. "Section"
	section.LayoutOrder = opts.Order or 0
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundTransparency = 1
	section.Parent = column
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = section
	if opts.Title then
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.LayoutOrder = -1000
		title.Size = UDim2.new(1, 0, 0, 18)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 13
		title.TextColor3 = STYLE.Title
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = opts.Title
		title.Parent = section
	end
	-- order rows by their old layout (row by row, left to right) unless LayoutOrder is already set
	local kids = {}
	for _, c in ipairs(menu:GetChildren()) do
		if c:IsA("GuiObject") then
			table.insert(kids, c)
		end
	end
	table.sort(kids, function(a, b)
		local ay, by = a.Position.Y.Offset, b.Position.Y.Offset
		if ay ~= by then
			return ay < by
		end
		return a.Position.X.Offset < b.Position.X.Offset
	end)
	for i, c in ipairs(kids) do
		if c.LayoutOrder == 0 then
			c.LayoutOrder = i * 10
		end
		styleRow(c)
	end
	local rows = Instance.new("UIListLayout")
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Padding = UDim.new(0, 4)
	rows.Parent = menu
	menu.AnchorPoint = Vector2.zero
	menu.BackgroundTransparency = 1
	local oldCorner = menu:FindFirstChildOfClass("UICorner")
	if oldCorner then
		oldCorner:Destroy()
	end
	menu.Position = UDim2.new()
	menu.Size = UDim2.new(1, 0, 0, 0)
	menu.AutomaticSize = Enum.AutomaticSize.Y
	menu.LayoutOrder = 0
	menu.Parent = section
	menu.ChildAdded:Connect(function(c)
		task.defer(function()
			if c.Parent == menu and c:IsA("GuiObject") then
				if c.LayoutOrder == 0 then
					c.LayoutOrder = (#menu:GetChildren() + 1) * 10
				end
				styleRow(c)
			end
		end)
	end)
	sections[menu] = section
	menu:GetPropertyChangedSignal("Visible"):Connect(refresh)
	menu.AncestryChanged:Connect(refresh)
	refresh()
	return section
end

function Panel.addButton(menu, text, callback, layoutOrder)
	local b = Instance.new("TextButton")
	b.Name = text
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = STYLE.Text
	b.AutoButtonColor = true
	b.LayoutOrder = layoutOrder or 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.Parent = menu
	styleRow(b)
	if callback then
		b.Activated:Connect(callback)
	end
	return b
end

Panel.Gui = gui
return Panel
