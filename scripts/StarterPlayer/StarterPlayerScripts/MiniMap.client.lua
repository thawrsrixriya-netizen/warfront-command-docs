-- StarterPlayer.StarterPlayerScripts.MiniMap  (LocalScript)
-- MiniMap (client): round map at the top-left, north (-Z) up, does not rotate.
-- Shows: your units (blue: tank/BMP = square turned to its heading, infantry squad = dot),
-- other players' units (green), enemies the vision system has Spotted (red), bases from
-- Workspace.MatchPoints.
-- Click the small map -> a big map opens in the middle of the screen: hold the left mouse button and
-- drag to move around, mouse wheel to zoom; click outside the big map or press X to close it.
-- Settings: ReplicatedStorage.MiniMapConfig.
-- TO SHOW SOMETHING NEW (ChatGPT): add a collector to MiniMap.Collectors (see below) that appends
-- { Position = Vector3, Color = Color3, Shape = "Dot"|"Square"|"Diamond", Size = px, Heading = degrees? }.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MiniMapConfig"))
local EnemyRegistry = require(ReplicatedStorage:WaitForChild("WarShared"):WaitForChild("EnemyRegistry"))
local player = Players.LocalPlayer
local COL = Config.Colors

---------------------------------------------------------------- world area
-- measured on the server (ServerScriptService.MiniMapServer): a client may not have the whole map streamed in
local function worldArea()
	if Config.Center and Config.Size then
		return Config.Center, Config.Size
	end
	local t0 = os.clock()
	while workspace:GetAttribute("MiniMapSize") == nil and os.clock() - t0 < 10 do
		task.wait(0.1)
	end
	local c, s = workspace:GetAttribute("MiniMapCenter"), workspace:GetAttribute("MiniMapSize")
	if typeof(c) == "Vector3" and typeof(s) == "Vector3" and s.X > 1 and s.Z > 1 then
		return Vector2.new(c.X, c.Z), Vector2.new(s.X, s.Z)
	end
	return Vector2.zero, Vector2.new(1000, 1000)
end
local areaCenter, areaSize = worldArea()
local function fitScale(diameter)
	return math.min(diameter / areaSize.X, diameter / areaSize.Y)
end

---------------------------------------------------------------- a round map view
local function newView(parent, diameter, markerScale)
	-- round background; the ground is drawn as thin horizontal strips cut to the circle (UI cannot
	-- reliably clip to a circle: CanvasGroup falls back to no clipping on some graphics settings)
	local canvas = Instance.new("Frame")
	canvas.Name = "MapView"
	canvas.Size = UDim2.fromOffset(diameter, diameter)
	canvas.BackgroundColor3 = COL.Background
	canvas.BackgroundTransparency = 0.1
	canvas.BorderSizePixel = 0
	canvas.Parent = parent
	Instance.new("UICorner", canvas).CornerRadius = UDim.new(0.5, 0)
	local ground = Instance.new("Frame")
	ground.Name = "Ground"
	ground.BackgroundTransparency = 1
	ground.Size = UDim2.fromScale(1, 1)
	ground.Parent = canvas
	local strip = diameter > 300 and 3 or 2
	local strips = {}
	for y = 0, diameter - 1, strip do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = COL.Ground
		f.BorderSizePixel = 0
		f.Visible = false
		f.Parent = ground
		table.insert(strips, { Frame = f, Y = y, H = math.min(strip, diameter - y) })
	end
	local layer = Instance.new("Frame")
	layer.Name = "Markers"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 2
	layer.Parent = canvas
	-- outline ring (outside the CanvasGroup so it is not clipped)
	local ring = Instance.new("Frame")
	ring.Name = "Outline"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromOffset(diameter, diameter)
	ring.Parent = parent
	Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COL.Outline
	stroke.Thickness = 2
	stroke.Parent = ring
	return {
		Canvas = canvas,
		Ring = ring,
		Ground = ground,
		Layer = layer,
		D = diameter,
		Scale = fitScale(diameter) * Config.Fill,
		Pan = Vector2.zero,
		MarkerScale = markerScale or 1,
		Pool = {},
		Strips = strips,
	}
end

local function toLocal(view, p)
	return view.D / 2 + (p.X - areaCenter.X) * view.Scale + view.Pan.X, view.D / 2 + (p.Z - areaCenter.Y) * view.Scale + view.Pan.Y
end

local function render(view, items)
	local d = view.D
	local x0, y0 = toLocal(view, Vector3.new(areaCenter.X - areaSize.X / 2, 0, areaCenter.Y - areaSize.Y / 2))
	local x1, y1 = x0 + areaSize.X * view.Scale, y0 + areaSize.Y * view.Scale
	local r = d / 2
	for _, st in ipairs(view.Strips) do
		local cy = st.Y + st.H / 2
		local on = false
		if cy >= y0 and cy <= y1 then
			local hw = math.sqrt(math.max(r * r - (cy - r) ^ 2, 0))
			local a, b = math.max(x0, r - hw), math.min(x1, r + hw)
			if b - a >= 1 then
				on = true
				st.Frame.Position = UDim2.fromOffset(math.floor(a), st.Y)
				st.Frame.Size = UDim2.fromOffset(math.ceil(b - a), st.H)
			end
		end
		st.Frame.Visible = on
	end
	local used = 0
	for _, it in ipairs(items) do
		local x, y = toLocal(view, it.Position)
		local dx, dy = x - d / 2, y - d / 2
		if dx * dx + dy * dy <= (d / 2 - 2) ^ 2 then
			used += 1
			local m = view.Pool[used]
			if not m then
				m = Instance.new("Frame")
				m.AnchorPoint = Vector2.new(0.5, 0.5)
				m.BorderSizePixel = 0
				Instance.new("UICorner", m)
				m.Parent = view.Layer
				view.Pool[used] = m
			end
			local size = it.Size * view.MarkerScale
			m.Visible = true
			m.BackgroundColor3 = it.Color
			m.Size = UDim2.fromOffset(size, size)
			m.Position = UDim2.fromOffset(x, y)
			m.UICorner.CornerRadius = it.Shape == "Dot" and UDim.new(0.5, 0) or UDim.new(0, 1)
			m.Rotation = it.Shape == "Diamond" and 45 or (it.Heading or 0)
			m.ZIndex = it.Shape == "Diamond" and 1 or 2
		end
	end
	for i = used + 1, #view.Pool do
		view.Pool[i].Visible = false
	end
end

---------------------------------------------------------------- what is shown
local MiniMap = { Collectors = {} }

local function ownerColor(userId)
	return userId == player.UserId and COL.Mine or COL.Ally
end

-- your / allied tanks and BMPs
table.insert(MiniMap.Collectors, function(out)
	local folder = workspace:FindFirstChild("CommandTanks")
	if not folder then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		local owner = m:GetAttribute("OwnerUserId")
		if m:IsA("Model") and owner then
			local cf = m:GetPivot()
			local lv = cf.LookVector
			table.insert(out, { Position = cf.Position, Color = ownerColor(owner), Shape = "Square", Size = 7, Heading = math.deg(math.atan2(lv.X, -lv.Z)) })
		end
	end
end)
-- infantry squads (one dot per squad)
table.insert(MiniMap.Collectors, function(out)
	local folder = workspace:FindFirstChild("CommandInfantry")
	if not folder then
		return
	end
	local seen = {}
	for _, m in ipairs(folder:GetChildren()) do
		local owner, slot = m:GetAttribute("OwnerUserId"), m:GetAttribute("InfantrySlot")
		local root = m:FindFirstChild("HumanoidRootPart")
		local hum = m:FindFirstChildOfClass("Humanoid")
		local key = tostring(owner) .. ":" .. tostring(slot)
		if owner and root and hum and hum.Health > 0 and not m:GetAttribute("Embarked") and not seen[key] then
			seen[key] = true
			table.insert(out, { Position = root.Position, Color = ownerColor(owner), Shape = "Dot", Size = 5 })
		end
	end
end)
-- enemies the vision system has spotted
table.insert(MiniMap.Collectors, function(out)
	for _, e in ipairs(EnemyRegistry.all(false)) do
		if e.Model and e.Model:GetAttribute("Spotted") then
			table.insert(out, { Position = e.Position, Color = COL.Enemy, Shape = "Dot", Size = 4 })
		end
	end
end)
-- bases (Workspace.MatchPoints)
table.insert(MiniMap.Collectors, function(out)
	local points = workspace:FindFirstChild("MatchPoints")
	if not points then
		return
	end
	-- the centre base comes from CaptureServer's replicated attributes (the part may not be streamed in)
	local centreCF = ReplicatedStorage:GetAttribute("CenterZoneCFrame")
	if typeof(centreCF) == "CFrame" then
		local held = ReplicatedStorage:GetAttribute("CenterOwner")
		table.insert(out, { Position = centreCF.Position, Color = held == "Player" and COL.Mine or held == "Enemy" and COL.Enemy or COL.CenterBase, Shape = "Diamond", Size = 9 })
	end
	for _, name in ipairs(Config.Bases) do
		local p = name ~= "CenterBase" and points:FindFirstChild(name)
		local pos = p and (p:IsA("BasePart") and p.Position or p:IsA("Model") and p:GetPivot().Position)
		if pos then
			local color = COL[name] or COL.Outline
			local held = p:GetAttribute("CaptureOwner") -- set by CaptureServer on the centre base
			if held == "Player" then
				color = COL.Mine
			elseif held == "Enemy" then
				color = COL.Enemy
			end
			table.insert(out, { Position = pos, Color = color, Shape = "Diamond", Size = 9 })
		end
	end
end)

---------------------------------------------------------------- small map
local gui = Instance.new("ScreenGui")
gui.Name = "MiniMap"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local small = Instance.new("Frame")
small.Name = "Small"
small.BackgroundTransparency = 1
small.Position = Config.Position
small.Size = UDim2.fromOffset(Config.Diameter, Config.Diameter)
small.Parent = gui
local smallView = newView(small, Config.Diameter, 1)
local smallButton = Instance.new("TextButton") -- click = open the big map
smallButton.Name = "Open"
smallButton.Text = ""
smallButton.BackgroundTransparency = 1
smallButton.Size = UDim2.fromScale(1, 1)
smallButton.ZIndex = 5
smallButton.Parent = small
Instance.new("UICorner", smallButton).CornerRadius = UDim.new(0.5, 0)

---------------------------------------------------------------- big map
local bigGui = Instance.new("ScreenGui")
bigGui.Name = "MiniMapExpanded"
bigGui.ResetOnSpawn = false
bigGui.IgnoreGuiInset = true
bigGui.DisplayOrder = 30
bigGui.Enabled = false
bigGui.Parent = player.PlayerGui

local backdrop = Instance.new("TextButton") -- click outside the map = close
backdrop.Name = "Backdrop"
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Parent = bigGui

local holder = Instance.new("Frame")
holder.Name = "Map"
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.fromScale(0.5, 0.5)
holder.BackgroundTransparency = 1
holder.Parent = bigGui
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 14
hint.TextColor3 = Color3.fromRGB(236, 239, 244)
hint.TextStrokeTransparency = 0.5
hint.Text = "Drag to move  |  Wheel to zoom  |  Click outside or X to close"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Size = UDim2.fromOffset(500, 22)
hint.Parent = bigGui

local bigView
local zoomMin, zoom = 1, 1
local isOpen = false
local dragging, dragStart, panStart = false, nil, nil

local function clampPan()
	local maxX = math.max(areaSize.X * bigView.Scale / 2, 0)
	local maxY = math.max(areaSize.Y * bigView.Scale / 2, 0)
	bigView.Pan = Vector2.new(math.clamp(bigView.Pan.X, -maxX, maxX), math.clamp(bigView.Pan.Y, -maxY, maxY))
end

local function buildBig()
	local vp = workspace.CurrentCamera.ViewportSize
	local d = math.floor(math.min(vp.X, vp.Y) * Config.ExpandedScreenFraction)
	if bigView and bigView.D == d then
		return
	end
	if bigView then
		bigView.Canvas:Destroy()
		bigView.Ring:Destroy()
	end
	holder.Size = UDim2.fromOffset(d, d)
	bigView = newView(holder, d, 1.6)
	zoomMin = fitScale(d)
	zoom = Config.ExpandedZoom
	bigView.Scale = zoomMin * zoom
	hint.Position = UDim2.new(0.5, 0, 0.5, d / 2 + 10)
end

local function mouseInBig()
	local m = UserInputService:GetMouseLocation() -- bigGui ignores the inset
	local c = holder.AbsolutePosition + holder.AbsoluteSize / 2
	return (m - c).Magnitude <= bigView.D / 2, m
end

local closeBig
local function onX(_, state)
	if state == Enum.UserInputState.Begin then
		closeBig()
	end
	return Enum.ContextActionResult.Sink
end

local function openBig()
	if isOpen then
		return
	end
	buildBig()
	bigView.Pan = Vector2.zero
	isOpen = true
	bigGui.Enabled = true
	ContextActionService:BindActionAtPriority("MiniMapClose", onX, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.X)
end

function closeBig()
	if not isOpen then
		return
	end
	isOpen = false
	dragging = false
	bigGui.Enabled = false
	ContextActionService:UnbindAction("MiniMapClose")
end

smallButton.Activated:Connect(openBig)

backdrop.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local inside, m = mouseInBig()
	if inside then
		dragging, dragStart, panStart = true, m, bigView.Pan
	else
		closeBig()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not isOpen then
		return
	end
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		bigView.Pan = panStart + (UserInputService:GetMouseLocation() - dragStart)
		clampPan()
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		local inside, m = mouseInBig()
		if inside then
			-- zoom around the mouse
			local c = holder.AbsolutePosition + holder.AbsoluteSize / 2
			local before = bigView.Scale
			zoom = math.clamp(zoom * (input.Position.Z > 0 and 1.2 or 1 / 1.2), 1, Config.MaxZoom)
			bigView.Scale = zoomMin * zoom
			local rel = m - c
			bigView.Pan = rel - (rel - bigView.Pan) * (bigView.Scale / before)
			clampPan()
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

---------------------------------------------------------------- update
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < Config.UpdateInterval and not dragging then
		return
	end
	acc = 0
	local items = {}
	for _, collect in ipairs(MiniMap.Collectors) do
		local ok, err = pcall(collect, items)
		if not ok then
			warn("MiniMap collector:", err)
		end
	end
	render(smallView, items)
	if isOpen then
		render(bigView, items)
	end
end)
