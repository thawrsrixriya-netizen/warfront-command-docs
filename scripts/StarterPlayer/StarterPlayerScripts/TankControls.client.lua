-- StarterPlayer.StarterPlayerScripts.TankControls  (LocalScript)
-- TankControls: bottom rotating tank icon (placement), slot buttons 1/2/3, Move/Fire/Close menu,
-- mouse previews and chassis-centre number labels. UI clicks never issue world commands.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage:WaitForChild("WarConfig")).Tank
local Shared = ReplicatedStorage:WaitForChild("WarShared")
local Client = ReplicatedStorage:WaitForChild("WarClient")
local U = require(Shared:WaitForChild("WarUtil"))
local FX = require(Shared:WaitForChild("FX"))
local InputMode = require(Client:WaitForChild("InputMode"))
local Aim = require(Client:WaitForChild("Aim"))
local Selection = require(Client:WaitForChild("UnitSelection"))
local Watch=require(Client:WaitForChild("UnitWatchPreview"))
local watchPreview
local TankCommand = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TankCommand")
local InfantryTransport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InfantryTransport")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local tanksFolder = U.folder("CommandTanks")

local PLACE, CONTROL = "TankPlace", "TankControl"

---------------------------------------------------------------- my tanks
local function myTanks()
	local list = {}
	for _, m in ipairs(tanksFolder:GetChildren()) do
		if m:GetAttribute("OwnerUserId") == player.UserId then
			local slot = m:GetAttribute("TankSlot")
			if slot then
				list[slot] = m
			end
		end
	end
	return list
end

local function countTanks()
	local n = 0
	for _ in pairs(myTanks()) do
		n += 1
	end
	return n
end

local function chassisCenter(model)
	local hull = model:FindFirstChild("Hull")
	local cf = (hull or model):GetBoundingBox()
	return cf.Position
end

---------------------------------------------------------------- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "TankUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
end

local function button(text, parent, size)
	local b = Instance.new("TextButton")
	b.Size = size or UDim2.fromOffset(44, 36)
	b.BackgroundColor3 = Color3.fromRGB(35, 38, 34)
	b.BackgroundTransparency = 0.15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = text
	b.Name = text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 6)
	return b
end

local bottom = Instance.new("Frame")
bottom.Name = "Bottom"
bottom.AnchorPoint = Vector2.new(0.5, 1)
-- MatchHUD: summoning moved to the hotbar (slot 1 / key 1). The old icon and 1/2/3 buttons are
-- hidden; this frame is shifted so the command menu sits centred just above the hotbar.
bottom.Position = UDim2.new(0.5, -56, 1, -100)
bottom.Size = UDim2.fromOffset(420, 120)
bottom.BackgroundTransparency = 1
bottom.Parent = gui

-- rotating tank icon
local iconFrame = Instance.new("Frame")
iconFrame.Name = "TankIcon"
iconFrame.Size = UDim2.fromOffset(104, 104)
iconFrame.Position = UDim2.fromOffset(0, 0)
iconFrame.BackgroundColor3 = Color3.fromRGB(28, 31, 27)
iconFrame.BackgroundTransparency = 0.2
iconFrame.Parent = bottom
corner(iconFrame, 10)
local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundTransparency = 1
viewport.Parent = iconFrame
local vpCam = Instance.new("Camera")
vpCam.FieldOfView = 40
vpCam.Parent = viewport
viewport.CurrentCamera = vpCam
local iconButton = Instance.new("TextButton")
iconButton.Name = "PlaceButton"
iconButton.Size = UDim2.fromScale(1, 1)
iconButton.BackgroundTransparency = 1
iconButton.Text = ""
iconButton.Parent = iconFrame
local countLabel = Instance.new("TextLabel")
countLabel.Name = "Count"
countLabel.AnchorPoint = Vector2.new(0.5, 1)
countLabel.Position = UDim2.new(0.5, 0, 1, -2)
countLabel.Size = UDim2.new(1, 0, 0, 18)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamBold
countLabel.TextSize = 14
countLabel.TextColor3 = Color3.new(1, 1, 1)
countLabel.TextStrokeTransparency = 0.4
countLabel.Text = "0/" .. C.MaxPerPlayer
countLabel.Parent = iconFrame

-- slot buttons + command menu
local right = Instance.new("Frame")
right.Position = UDim2.fromOffset(116, 8)
right.Size = UDim2.fromOffset(300, 96)
right.BackgroundTransparency = 1
right.Parent = bottom
local slotButtons = {}
for i = 1, C.MaxPerPlayer do
	local b = button(tostring(i), right)
	b.Name = "Slot" .. i
	b.Position = UDim2.fromOffset((i - 1) * 50, 0)
	slotButtons[i] = b
end
local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.Position = UDim2.fromOffset(0, 46)
menu.Size = UDim2.fromOffset(300, 40)
menu.BackgroundTransparency = 1
menu.Visible = false
menu.Parent = right
local moveBtn = button("Move", menu, UDim2.fromOffset(68, 36))
local fireBtn = button("Fire", menu, UDim2.fromOffset(68, 36))
fireBtn.Position = UDim2.fromOffset(74, 0)
local stopBtn = button("Stop", menu, UDim2.fromOffset(68, 36))
stopBtn.Position = UDim2.fromOffset(148, 0)
for i,b in ipairs({moveBtn,fireBtn,stopBtn}) do b.Size=UDim2.fromOffset(69,36) b.Position=UDim2.fromOffset((i-1)*75,0) b.TextSize=12 end
moveBtn.Text="Z  Move" fireBtn.Text="F  Fire" stopBtn.Text="X  Stop"
local unloadBtn=button("Disembark",menu,UDim2.fromOffset(142,24))
unloadBtn.Text="G  Disembark" unloadBtn.Name="Disembark" unloadBtn.Position=UDim2.fromOffset(192,40) unloadBtn.Size=UDim2.fromOffset(102,24) unloadBtn.TextSize=12 unloadBtn.TextSize=14 unloadBtn.Visible=false

local msg = Instance.new("TextLabel")
msg.Name = "Message"
msg.AnchorPoint = Vector2.new(0.5, 1)
msg.Position = UDim2.new(0.5, 0, 1, -196)
iconFrame.Visible = false
msg.Size = UDim2.fromOffset(460, 28)
msg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
msg.BackgroundTransparency = 0.3
msg.Font = Enum.Font.GothamBold
msg.TextSize = 16
msg.TextColor3 = Color3.fromRGB(255, 200, 120)
msg.Visible = false
msg.Parent = gui
corner(msg, 6)
local msgToken = 0
local function showMessage(text)
	msgToken += 1
	local token = msgToken
	msg.Text = text
	msg.Visible = true
	task.delay(3, function()
		if token == msgToken then
			msg.Visible = false
		end
	end)
end

-- number labels
local labelGui = Instance.new("ScreenGui")
labelGui.Name = "TankLabels"
labelGui.IgnoreGuiInset = true
labelGui.ResetOnSpawn = false
labelGui.Parent = playerGui
local labels = {}
local passengerLabels = {}
local reloadIndicators = {}
local function createReloadIndicator(slot)
 local root=Instance.new("CanvasGroup")
 root.Name="TankOverheat"..slot
 root.AnchorPoint=Vector2.new(0.5,0)
 root.Size=UDim2.fromOffset(48,48)
 root.BackgroundTransparency=1
 root.GroupTransparency=1
 root.Visible=false
 root.Parent=labelGui
 local image=Instance.new("ImageLabel")
 image.Name="OverheatIcon"
 image.BackgroundTransparency=1
 image.Size=UDim2.fromScale(1,1)
 image.Image="rbxassetid://96726984620991"
 image.ScaleType=Enum.ScaleType.Fit
 image.Parent=root
 local indicator={Root=root,Opacity=0}
 reloadIndicators[slot]=indicator
 return indicator
end

---------------------------------------------------------------- icon viewport
local visualTemplate
local iconModel, iconOffset, iconYaw = nil, nil, 0
local ICON_MAX_PARTS = 8 -- simplified icon model: biggest parts per group (Hull, Turret)
local ICON_UPDATE_INTERVAL = 0.1 -- re-render the rotating icon at 10 Hz, not every frame
local iconLastUpdate = 0
local function setupIcon()
	visualTemplate = ReplicatedStorage:FindFirstChild("TankPlacementVisual")
	if iconModel then
		iconModel:Destroy()
		iconModel = nil
	end
	if not visualTemplate then
		return
	end
	iconModel = visualTemplate:Clone()
	-- Simplify for the ViewportFrame: keep only the biggest parts (they carry the silhouette),
	-- drop small details, surface textures, lights and effects. Re-rendering the full detailed
	-- tank every frame cost ~2/3 of the frame rate.
	-- Keep the biggest parts PER top-level group (Hull, Turret) so the turret is never dropped,
	-- plus the turret's longest part (the barrel).
	local groups = {}
	for _, d in ipairs(iconModel:GetDescendants()) do
		if d:IsA("BasePart") then
			local top = d
			while top.Parent ~= iconModel do
				top = top.Parent
			end
			groups[top] = groups[top] or {}
			table.insert(groups[top], d)
		elseif d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("Light")
			or d:IsA("ParticleEmitter") or d:IsA("Attachment") then
			d:Destroy()
		end
	end
	for _, parts in pairs(groups) do
		local longest, longestLen = nil, 0
		for _, part in ipairs(parts) do
			local l = math.max(part.Size.X, part.Size.Y, part.Size.Z)
			if l > longestLen then
				longest, longestLen = part, l
			end
		end
		table.sort(parts, function(a, b)
			return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
		end)
		for i, part in ipairs(parts) do
			if i > ICON_MAX_PARTS and part ~= longest then
				part:Destroy()
			else
				part.CastShadow = false
			end
		end
	end
	local bbCF, size = iconModel:GetBoundingBox()
	iconOffset = iconModel:GetPivot():ToObjectSpace(bbCF).Position
	iconModel.Parent = viewport
	local r = math.max(size.X, size.Y, size.Z)
	vpCam.CFrame = CFrame.lookAt(Vector3.new(0, r * 0.75, r * 1.55), Vector3.zero)
end
setupIcon()
ReplicatedStorage.ChildAdded:Connect(function(c)
	if c.Name == "TankPlacementVisual" then
		task.defer(setupIcon)
	end
end)

-- [SHARED:UnitSlots] BEGIN  (owner's hotbar bridge, see doc "To ChatGPT" rule 2.4; do not change or remove)
-- still (non-rotating) copy of the simplified icon for the MatchHUD hotbar slot
local function buildSlotIcon(vp)
	if not iconModel then
		return false
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local m = iconModel:Clone()
	m:PivotTo(CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(-iconOffset))
	m.Parent = vp
	local _, size = m:GetBoundingBox()
	local r = math.max(size.X, size.Y, size.Z)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, r * 0.7, r * 1.35), Vector3.zero)
	return true
end
-- [SHARED:UnitSlots] END

---------------------------------------------------------------- selection / modes
-- Selection is a SET of own tanks. Click a tank / slot button = select one.
-- Hold left mouse and drag = box-select every own tank inside the box.
-- Move / Fire then apply to every selected tank, exactly like a single tank.
local selected = {} -- array of Models
local action = nil -- nil | "Move" | "Fire"
local preview = nil -- Model in ClientFX
local placeYaw = 0

local function isSelected(model)
	for _, m in ipairs(selected) do
		if m == model then
			return true
		end
	end
	return false
end

local function clearPreview()
 watchPreview=nil
	if preview then
		preview:Destroy()
		preview = nil
	end
end

local function exitControl()
	clearPreview()
	selected = {}
	player:SetAttribute("BMPVisionSelectedSlots", "")
	action = nil
	menu.Visible = false
	player:SetAttribute("TankControlActive", false)
end

local function selectTanks(list)
	if #list == 0 then
		return
	end
	InputMode.enter(CONTROL, exitControl) -- exits other modes first
	selected = list
	local visionSlots = {}
	for _, m in ipairs(list) do table.insert(visionSlots, tostring(m:GetAttribute("TankSlot"))) end
	player:SetAttribute("BMPVisionSelectedSlots", table.concat(visionSlots, ","))
	action = nil
	clearPreview()
	menu.Visible = true
	player:SetAttribute("TankControlActive", true)
end

local function selectTank(model)
	if model then
		selectTanks({ model })
	end
end

-- group centre (keeps formation: every tank keeps its offset from it)
local function groupCentre()
	local sum, n = Vector3.zero, 0
	for _, m in ipairs(selected) do
		if m.Parent then
			sum += chassisCenter(m)
			n += 1
		end
	end
	return n > 0 and sum / n or nil
end

local function setAction(a)
	if #selected == 0 then
		return
	end
	action = a
	clearPreview()
	preview = Instance.new("Model")
	preview.Name = "TankAimPreview"
	preview.Parent = FX.folder()
	for i = 1, #selected do
		local set = Instance.new("Model")
		set.Name = "Tank" .. i
		set.Parent = preview
		if a == "Move" then
			FX.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 6, 6), Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon, Transparency = 0.45, Name = "Dest" }, set)
		else
			FX.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, C.AimBaseDiameter, C.AimBaseDiameter), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Transparency = 0.6, Name = "Base" }, set)
			FX.part({ Size = Vector3.new(C.AimRectWidth, 0.08, C.AimRectLength), Color = Color3.fromRGB(255, 140, 60), Material = Enum.Material.Neon, Transparency = 0.82, Name = "Rect" }, set)
			FX.part({ Size = Vector3.new(C.AimRectWidth, 0.14, 0.4), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon, Transparency = 0.1, Name = "MinLine" }, set)
			FX.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, C.TargetCircleDiameter, C.TargetCircleDiameter), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Transparency = 0.15, Name = "Target" }, set)
		end
	end
end

local function enterPlacement()
	if not visualTemplate then
		showMessage("Tank model is missing")
		return
	end
	if countTanks() >= C.MaxPerPlayer then
		showMessage(string.format("Tank limit reached (%d/%d)", C.MaxPerPlayer, C.MaxPerPlayer))
		return
	end
	InputMode.enter(PLACE, function()
		clearPreview()
		player:SetAttribute("TankControlActive", false)
	end)
	player:SetAttribute("TankControlActive", true)
	selected, action = {}, nil
	menu.Visible = false
	clearPreview()
	placeYaw = U.yawOf(U.flat(workspace.CurrentCamera.CFrame.LookVector) or Vector3.new(0, 0, -1))
	local w = visualTemplate:GetAttribute("Width") or 4.7
	local l = visualTemplate:GetAttribute("Length") or 10.1
	preview = require(Client.UnitPlacementVisual).new("TankPlacementPreview",Vector3.new(w,.1,l),FX.folder())
end

iconButton.Activated:Connect(function()
	if InputMode.get() == PLACE then
		InputMode.exit(PLACE)
	else
		enterPlacement()
	end
end)
for i, b in ipairs(slotButtons) do
	b.Activated:Connect(function()
		local t = myTanks()[i]
		if t then
			selectTank(t)
		end
	end)
end
-- [SHARED:UnitSlots] BEGIN  (owner's hotbar bridge, see doc "To ChatGPT" rule 2.4; do not change or remove)
require(ReplicatedStorage:WaitForChild("WarClient"):WaitForChild("UnitSlots")).register(1, {
	Name = "TANK",
	Economy = "BMP", -- EconomyConfig.Units key (cost / cooldown)
	Mode = PLACE,
	Call = enterPlacement,
	Count = function()
		return countTanks(), C.MaxPerPlayer
	end,
	BuildIcon = buildSlotIcon,
	Hint = "Q / E to rotate, click the ground to place the tank",
})
-- [SHARED:UnitSlots] END
moveBtn.Activated:Connect(function()
	setAction("Move")
end)
fireBtn.Activated:Connect(function()
	setAction("Fire")
end)
local function stopSelected()
 InputMode.blockClicks(.25)
	-- cease fire for every selected tank (they otherwise keep firing at the target after reloads)
	for _, m in ipairs(selected) do
		if m.Parent then
			TankCommand:FireServer("Stop", Vector3.zero, nil, m)
		end
	end
	action = nil
	clearPreview()
end
stopBtn.Activated:Connect(stopSelected)
local function unloadSelected()
 InputMode.blockClicks(.25)
 for _,m in selected do if m.Parent then InfantryTransport:FireServer("Unload",m) end end
end
unloadBtn.Activated:Connect(unloadSelected)

local watchBtn=button("C  Watch",menu,UDim2.fromOffset(69,36))
watchBtn.Name="Watch" watchBtn.Position=UDim2.fromOffset(0,40) watchBtn.Size=UDim2.fromOffset(90,24) watchBtn.TextSize=12
local function toggleWatch()
 InputMode.blockClicks(.25)
 if action=="Watch" or Watch.active(selected) then
  Watch.cancel(selected,"BMP") action=nil clearPreview() return
 end
 clearPreview() action="Watch"
 watchPreview=Watch.new(selected,"BMP") preview=watchPreview.Model
 showMessage("Point toward the direction to watch | Click confirm | C cancel")
end
watchBtn.Activated:Connect(toggleWatch)
local function ownTankFromHit(result)
	if not result then
		return nil
	end
	local inst = result.Instance
	while inst and inst ~= tanksFolder do
		if inst:IsA("Model") and inst:GetAttribute("CommandTank") then
			return inst:GetAttribute("OwnerUserId") == player.UserId and inst or nil
		end
		inst = inst.Parent
	end
	return nil
end

local function fireTargetPoint(tankPos, mouse)
	local d = U.flat(mouse - tankPos) or U.dirOf(0)
	local dist = Vector3.new(mouse.X - tankPos.X, 0, mouse.Z - tankPos.Z).Magnitude
	local r = C.TargetCircleDiameter / 2
	local along = math.clamp(dist, C.MinRange + r, C.AimRectLength - r)
	return tankPos + d * along, d
end

-- destination for each selected tank when the group is sent to `hit`
local function moveTargets(hit)
	local out = {}
	local centre = groupCentre()
	for _, m in ipairs(selected) do
		if m.Parent then
			local offset = Vector3.zero
			if centre and #selected > 1 then
				local c = chassisCenter(m)
				offset = Vector3.new(c.X - centre.X, 0, c.Z - centre.Z)
			end
			table.insert(out, { Tank = m, Point = hit + offset })
		end
	end
	return out
end

local function issueCommand(hit)
	if action=="Watch" and watchPreview then
		watchPreview:Confirm()
	elseif action == "Move" then
		for _, t in ipairs(moveTargets(hit)) do
			TankCommand:FireServer("Move", t.Point, nil, t.Tank)
		end
	elseif action == "Fire" then
		for _, m in ipairs(selected) do
			if m.Parent then
				local target = fireTargetPoint(chassisCenter(m), hit)
				TankCommand:FireServer("Fire", Vector3.new(target.X, hit.Y, target.Z), nil, m)
			end
		end
	end
	action = nil
	clearPreview()
end

---------------------------------------------------------------- drag box
local DRAG_THRESHOLD = 6 -- pixels before a press becomes a box drag
local dragBox = Instance.new("Frame")
dragBox.Name = "SelectionBox"
dragBox.BackgroundColor3 = Color3.fromRGB(40, 140, 255)
dragBox.BackgroundTransparency = 0.8
dragBox.BorderSizePixel = 0
dragBox.Visible = false
dragBox.ZIndex = 10
dragBox.Parent = labelGui -- IgnoreGuiInset = true: same coordinates as GetMouseLocation
local dragStroke = Instance.new("UIStroke")
dragStroke.Color = Color3.fromRGB(30, 140, 255)
dragStroke.Thickness = 1.5
dragStroke.Parent = dragBox

local press = nil -- { Start = Vector2, Dragging = bool }

local function boxRect(a, b)
	return Vector2.new(math.min(a.X, b.X), math.min(a.Y, b.Y)), Vector2.new(math.max(a.X, b.X), math.max(a.Y, b.Y))
end

Selection.register("BMP",{
 Mode=CONTROL, Action=function() return action end, Select=selectTanks,
 Close=function() InputMode.exit(CONTROL) end,
 Units=function() local list={} for _,m in pairs(myTanks()) do table.insert(list,m) end return list end,
 Position=chassisCenter, Hit=ownTankFromHit,
})
local tankSlot=require(Client.UnitSlots).get(1)
tankSlot.CancelKey="X"
tankSlot.Hint=nil

local function tanksInBox(lo, hi)
	local cam = workspace.CurrentCamera
	local list = {}
	local owned = myTanks()
	for slot = 1, C.MaxPerPlayer do
		local m = owned[slot]
		if m then
			local sp, onScreen = cam:WorldToViewportPoint(chassisCenter(m))
			if onScreen and sp.Z > 0 and sp.X >= lo.X and sp.X <= hi.X and sp.Y >= lo.Y and sp.Y <= hi.Y then
				table.insert(list, m)
			end
		end
	end
	return list
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if InputMode.isTyping() then
		return
	end
	local mode = InputMode.get()
	-- Escape is often flagged gameProcessed by the Roblox menu; still honour it as cancel
	if gameProcessed and input.KeyCode ~= Enum.KeyCode.Escape then
		return
	end
	if input.KeyCode==Enum.KeyCode.X and mode==PLACE then
		InputMode.blockClicks(.25) InputMode.exit(PLACE) return
	end
	if mode==CONTROL then
		if input.KeyCode==Enum.KeyCode.C then toggleWatch() return
		elseif input.KeyCode==Enum.KeyCode.Z then InputMode.blockClicks(.25) setAction("Move") return
		elseif input.KeyCode==Enum.KeyCode.F then InputMode.blockClicks(.25) setAction("Fire") return
		elseif input.KeyCode==Enum.KeyCode.X then stopSelected() return
		elseif input.KeyCode==Enum.KeyCode.G and unloadBtn.Visible then unloadSelected() return end
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		press = nil
		dragBox.Visible = false
		if mode == PLACE then
			InputMode.exit(PLACE)
		elseif mode == CONTROL then
			if action then
				action = nil
				clearPreview()
			else
				InputMode.exit(CONTROL)
			end
		end
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or InputMode.clicksBlocked() then
		return
	end
	if mode == PLACE then
		local hit = Aim.groundHit()
		InputMode.blockClicks(0.25)
		if hit then
			TankCommand:FireServer("Spawn", hit, placeYaw)
			InputMode.exit(PLACE)
		end
		return
	end
	if mode ~= CONTROL and not Selection.canHandle(mode) then return end
	-- normal mode or tank control: decide on release (click vs. drag box)
	press = { Start = UserInputService:GetMouseLocation(), Dragging = false }
end)

UserInputService.InputChanged:Connect(function(input)
	if not press or input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local now = UserInputService:GetMouseLocation()
	if not press.Dragging and (now - press.Start).Magnitude >= DRAG_THRESHOLD and action == nil then
		press.Dragging = true
	end
	if press.Dragging then
		local lo, hi = boxRect(press.Start, now)
		dragBox.Position = UDim2.fromOffset(lo.X, lo.Y)
		dragBox.Size = UDim2.fromOffset(hi.X - lo.X, hi.Y - lo.Y)
		dragBox.Visible = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not press then
		return
	end
	local p = press
	press = nil
	dragBox.Visible = false
	local mode = InputMode.get()
	if mode ~= CONTROL and not Selection.canHandle(mode) then return end
	if p.Dragging then
		-- box select: never calls the AC-130
		InputMode.blockClicks(0.25)
		local lo, hi = boxRect(p.Start, UserInputService:GetMouseLocation())
		Selection.selectBox(lo,hi,mode)
		return
	end
	-- plain click
	local hit, result = Aim.groundHit()
	if action==nil and Selection.canHandle(mode) then
		InputMode.blockClicks(.25)
		Selection.click(result,mode)
		return
	end
	if mode == CONTROL then
		InputMode.blockClicks(.25)
		if hit and action then issueCommand(hit) end
	end
end)

TankCommand.OnClientEvent:Connect(function(kind, a)
	if kind == "Message" then
		showMessage(a)
	end
end)

---------------------------------------------------------------- per frame
local function updateLabels(cam, owned)
	local vh = cam.ViewportSize.Y
	local k = vh / (2 * math.tan(math.rad(cam.FieldOfView) / 2))
	for slot, label in pairs(labels) do
		if not owned[slot] then
			label:Destroy()
			labels[slot] = nil
   if passengerLabels[slot] then passengerLabels[slot]:Destroy() passengerLabels[slot]=nil end
			if reloadIndicators[slot] then reloadIndicators[slot].Root:Destroy(); reloadIndicators[slot] = nil end
		end
	end
	for slot, model in pairs(owned) do
		local label = labels[slot]
		if not label then
			label = Instance.new("TextLabel")
			label.Name = "TankLabel" .. slot
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.BackgroundColor3 = Color3.fromRGB(20, 22, 20)
			label.BackgroundTransparency = 0.25
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Font = Enum.Font.GothamBlack
			label.Text = tostring(slot)
			label.Parent = labelGui
			corner(label, 4)
			labels[slot] = label
		end
		local world = chassisCenter(model) + Vector3.new(0, C.LabelOffsetY, 0)
		local sp, onScreen = cam:WorldToViewportPoint(world)
		local indicator = reloadIndicators[slot] or createReloadIndicator(slot)
		indicator.Root.Visible = false
		local passenger=passengerLabels[slot]
  if not passenger then
   passenger=Instance.new("TextLabel") passenger.Name="PassengerLabel"..slot passenger.AnchorPoint=Vector2.new(0,.5)
   passenger.BackgroundColor3=Color3.fromRGB(20,22,20) passenger.BackgroundTransparency=.25 passenger.TextColor3=Color3.new(1,1,1)
   passenger.Font=Enum.Font.GothamBlack passenger.Parent=labelGui corner(passenger,4) passengerLabels[slot]=passenger
  end
  passenger.Visible=false
  local depth = sp.Z
		if not onScreen or depth <= 0 or depth > C.LabelMaxDistance then
			label.Visible = false
		else
			local px = math.min(C.LabelMaxPixels, C.LabelStuds * k / depth)
			label.Visible = true
			label.Size = UDim2.fromOffset(px, px)
			label.Position = UDim2.fromOffset(sp.X, sp.Y)
			label.TextSize = math.min(C.LabelMaxTextSize, px * 0.72)
   local carried=model:GetAttribute("PassengerCount") or 0
   passenger.Visible=carried>0
   passenger.Text=tostring(carried).."/"..tostring(model:GetAttribute("PassengerCapacity") or 6)
   passenger.Size=UDim2.fromOffset(px*1.8,px) passenger.Position=UDim2.fromOffset(sp.X+px/2+4,sp.Y) passenger.TextSize=label.TextSize
			local hot = model:GetAttribute("Overheated") == true
			local endsAt = model:GetAttribute("OverheatEndsAt")
			local remaining = endsAt and math.max(0, endsAt - workspace:GetServerTimeNow()) or C.OverheatTime
			-- Fade in across the final 30% of heat; fade out using the authoritative cooldown.
			local heatFraction = math.clamp((model:GetAttribute("Heat") or 0) / C.OverheatShots, 0, 1)
			local opacity = hot and math.clamp(remaining / C.OverheatTime, 0, 1) or math.clamp((heatFraction - 0.7) / 0.3, 0, 1)
			if not hot and not model:GetAttribute("FireActive") then
				-- An idle gun cools fully after OverheatTime in the existing server rules.
				local lastShotAt = model:GetAttribute("LastShotAt")
				if lastShotAt and workspace:GetServerTimeNow() - lastShotAt >= C.OverheatTime then opacity = 0 end
			end
			local now = os.clock()
			local elapsed = math.min(now - (indicator.LastUpdate or now), 0.1)
			indicator.LastUpdate = now
			indicator.Opacity = (indicator.Opacity or 0) + (opacity - (indicator.Opacity or 0)) * math.min(1, elapsed * 12)
			if opacity == 0 and indicator.Opacity < 0.005 then indicator.Opacity = 0 end
			indicator.Root.Visible = indicator.Opacity > 0
			indicator.Root.GroupTransparency = 1 - indicator.Opacity
			indicator.Root.Position = UDim2.fromOffset(sp.X, sp.Y + px / 2 + 6)
			-- Overheat icon fades using the server cooldown deadline.
			local isSel = isSelected(model)
			label.BackgroundColor3 = isSel and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(20, 22, 20)
			label.TextColor3 = isSel and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local owned = myTanks()
	local n = 0
	for _ in pairs(owned) do
		n += 1
	end
	countLabel.Text = string.format("%d/%d", n, C.MaxPerPlayer)
	for i, b in ipairs(slotButtons) do
		local has = owned[i] ~= nil
		b.Visible = false -- selection is click / drag-box now (owner, 2026-11-21)
		local isSel = has and isSelected(owned[i])
		b.BackgroundColor3 = isSel and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(35, 38, 34)
		b.TextColor3 = isSel and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
	end
	-- drop destroyed tanks from the selection
	if #selected > 0 then
		for i = #selected, 1, -1 do
			if not selected[i].Parent then
				table.remove(selected, i)
			end
		end
		if #selected == 0 then
			InputMode.exit(CONTROL)
		end
	end

	-- icon spin (the old icon is hidden: no spin, no re-render)
	if iconModel and iconFrame.Visible then
		iconYaw += math.rad(C.IconSpinSpeed) * dt
		local now = os.clock()
		if now - iconLastUpdate >= ICON_UPDATE_INTERVAL then
			iconLastUpdate = now
			iconModel:PivotTo(CFrame.Angles(0, iconYaw, 0) * CFrame.new(-iconOffset))
		end
	end

	local carrying=false
 for _,m in selected do if m.Parent and (m:GetAttribute("PassengerCount") or 0)>0 then carrying=true end end
 unloadBtn.Visible=carrying
 local mode = InputMode.get()
	if watchPreview then
		watchPreview:Update(Aim.groundHit())
	elseif preview and mode == PLACE then
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			placeYaw += math.rad(C.PlaceRotateSpeed) * 1.3 * dt
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) then
			placeYaw -= math.rad(C.PlaceRotateSpeed) * 1.3 * dt
		end
		local hit = Aim.groundHit()
		if hit then
			local cf = CFrame.new(hit + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, placeYaw, 0)
			require(Client.UnitPlacementVisual).move(preview,cf)
		end
	elseif preview and mode == CONTROL and #selected > 0 then
		local hit = Aim.groundHit()
		if hit then
			if action == "Move" then
				for i, t in ipairs(moveTargets(hit)) do
					local set = preview:FindFirstChild("Tank" .. i)
					if set then
						set.Dest.CFrame = CFrame.new(t.Point + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
					end
				end
			elseif action == "Fire" then
				for i, m in ipairs(selected) do
					local set = preview:FindFirstChild("Tank" .. i)
					if set and m.Parent then
						local tp = chassisCenter(m)
						local base = Vector3.new(tp.X, hit.Y + 0.1, tp.Z)
						local target, d = fireTargetPoint(base, hit)
						set.Base.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.pi / 2)
						set.Rect.CFrame = CFrame.lookAlong(base + d * (C.AimRectLength / 2), d)
						set.MinLine.CFrame = CFrame.lookAlong(base + d * C.MinRange + Vector3.new(0, 0.03, 0), d)
						set.Target.CFrame = CFrame.new(Vector3.new(target.X, base.Y + 0.05, target.Z)) * CFrame.Angles(0, 0, math.pi / 2)
					end
				end
			end
		end
	end
	updateLabels(cam, owned)
end)

require(Client.UnitUI).adopt(menu,msg,"BMP")
