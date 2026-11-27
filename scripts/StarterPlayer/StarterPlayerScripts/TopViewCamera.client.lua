-- StarterPlayer.StarterPlayerScripts.TopViewCamera  (LocalScript)
-- TopViewCamera: M cycles three views:  PERSON -> TOP -> FREE -> PERSON ...
--   TOP : fixed overhead view. WASD pans relative to the screen, mouse wheel = height only,
--         orientation never changes.
--   FREE: fly anywhere. WASD = move where the camera looks, Space / Ctrl = up / down,
--         Shift = faster, hold RIGHT mouse to look around, wheel = move forward / back.
-- In TOP and FREE the character does not walk (movement keys are sunk).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WarConfig")).Camera
local player = Players.LocalPlayer

local LOOK = Config.LookDirection.Unit
local RENDER_NAME = "TopViewCameraStep"
local WHEEL_ACTION = "TopViewWheel"
local MOVE_BLOCK_ACTION = "TopViewBlockMove"
local PRIORITY = Enum.ContextActionPriority.High.Value + 50
-- Sinking these above the default controls stops the character walking / jumping;
-- CAS also sends Cancel to the lower movement actions so held keys release.
local MOVE_KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Space,
}
local FREE_FAST = 3
local FREE_LOOK_SENS = 0.25 -- degrees per pixel
local FREE_START_PITCH = -50

local function sink()
	return Enum.ContextActionResult.Sink
end

local mode = "Person" -- "Person" | "Top" | "Free"
local saved = nil
local refY = 0
local pos = Vector3.zero
local yaw, pitch = 0, 0 -- FREE view, degrees
local looking = false -- right mouse held in FREE view

local function viewCFrame(p)
	return CFrame.lookAt(p, p + LOOK, Vector3.yAxis)
end

local function freeCFrame()
	return CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
end

local function referencePosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	return workspace.CurrentCamera.Focus.Position
end

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-4 and v.Unit or Vector3.zero
end

local function keyDown(k)
	return UserInputService:IsKeyDown(k)
end

local function step(dt)
	-- Runs after the default controls each frame: cancels any walk input
	-- (covers keys that were already held when the mode was entered).
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero, false)
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local typing = UserInputService:GetFocusedTextBox() ~= nil

	if mode == "Top" then
		local cf = viewCFrame(pos)
		if not typing then
			local up, right = flat(cf.UpVector), flat(cf.RightVector)
			local move = Vector3.zero
			if keyDown(Enum.KeyCode.W) then move += up end
			if keyDown(Enum.KeyCode.S) then move -= up end
			if keyDown(Enum.KeyCode.D) then move += right end
			if keyDown(Enum.KeyCode.A) then move -= right end
			if move.Magnitude > 0 then
				pos += move.Unit * Config.PanSpeed * dt
				cf = viewCFrame(pos)
			end
		end
		camera.CFrame = cf
		local height = pos.Y - refY
		camera.Focus = CFrame.new(pos + LOOK * (height / math.max(-LOOK.Y, 0.1)))
	else -- Free
		local cf = freeCFrame()
		if not typing then
			local move = Vector3.zero
			if keyDown(Enum.KeyCode.W) or keyDown(Enum.KeyCode.Up) then move += cf.LookVector end
			if keyDown(Enum.KeyCode.S) or keyDown(Enum.KeyCode.Down) then move -= cf.LookVector end
			if keyDown(Enum.KeyCode.D) or keyDown(Enum.KeyCode.Right) then move += cf.RightVector end
			if keyDown(Enum.KeyCode.A) or keyDown(Enum.KeyCode.Left) then move -= cf.RightVector end
			if keyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
			if keyDown(Enum.KeyCode.LeftControl) or keyDown(Enum.KeyCode.RightControl) then move -= Vector3.yAxis end
			if move.Magnitude > 0 then
				local speed = Config.PanSpeed * ((keyDown(Enum.KeyCode.LeftShift) or keyDown(Enum.KeyCode.RightShift)) and FREE_FAST or 1)
				pos += move.Unit * speed * dt
				cf = freeCFrame()
			end
		end
		camera.CFrame = cf
		camera.Focus = CFrame.new(pos + cf.LookVector * 40)
	end
end

local function onWheel(_, state, input)
	if state == Enum.UserInputState.Change then
		if mode == "Top" then
			local height = math.clamp(pos.Y - refY - input.Position.Z * Config.WheelStep, Config.MinHeight, Config.MaxHeight)
			pos = Vector3.new(pos.X, refY + height, pos.Z)
		elseif mode == "Free" then
			pos += freeCFrame().LookVector * input.Position.Z * Config.WheelStep
		end
	end
	return Enum.ContextActionResult.Sink
end

local function bindControls()
	ContextActionService:BindActionAtPriority(MOVE_BLOCK_ACTION, sink, false, PRIORITY, table.unpack(MOVE_KEYS))
	ContextActionService:BindActionAtPriority(WHEEL_ACTION, onWheel, false, PRIORITY, Enum.UserInputType.MouseWheel)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
end

local function stopLooking()
	if looking then
		looking = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function enterTop()
	local camera = workspace.CurrentCamera
	saved = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
	}
	local ref = referencePosition()
	refY = ref.Y
	pos = Vector3.new(ref.X, refY + Config.InitialHeight, ref.Z)
	mode = "Top"
	bindControls()
	player:SetAttribute("OverheadCamera", true)
	player:SetAttribute("CameraMode", "Top")
end

local function enterFree()
	-- start from where the top view is, tilted forward so the horizon is visible
	local look = flat(LOOK)
	if look.Magnitude == 0 then
		look = Vector3.new(0, 0, -1)
	end
	yaw = math.deg(math.atan2(-look.X, -look.Z))
	pitch = FREE_START_PITCH
	pos = pos + Vector3.new(0, -math.min(pos.Y - refY - 40, 60), 0) - look * 60
	mode = "Free"
	player:SetAttribute("CameraMode", "Free")
end

-- restoreView=false is used on respawn: only hand the camera back to the new character.
local function exitToPerson(restoreView)
	if mode == "Person" then
		return
	end
	mode = "Person"
	stopLooking()
	RunService:UnbindFromRenderStep(RENDER_NAME)
	ContextActionService:UnbindAction(WHEEL_ACTION)
	ContextActionService:UnbindAction(MOVE_BLOCK_ACTION)
	local camera = workspace.CurrentCamera
	if restoreView ~= false and saved then
		camera.CameraType = saved.CameraType
		camera.CameraSubject = saved.CameraSubject
		camera.CFrame = saved.CFrame
		camera.Focus = saved.Focus
	else
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	saved = nil
	player:SetAttribute("OverheadCamera", false)
	player:SetAttribute("CameraMode", "Person")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 and mode == "Free" and not gameProcessed then
		looking = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		return
	end
	if gameProcessed then
		return
	end
	if input.KeyCode == Config.ToggleKey then
		if mode == "Person" then
			enterTop()
		elseif mode == "Top" then
			enterFree()
		else
			exitToPerson(true)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		stopLooking()
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if looking and mode == "Free" and input.UserInputType == Enum.UserInputType.MouseMovement then
		yaw -= input.Delta.X * FREE_LOOK_SENS
		pitch = math.clamp(pitch - input.Delta.Y * FREE_LOOK_SENS, -89, 89)
	end
end)

player.CharacterAdded:Connect(function(character)
	if mode ~= "Person" then
		character:WaitForChild("Humanoid", 5)
		exitToPerson(false)
	end
end)

script.Destroying:Connect(function()
	exitToPerson(true)
end)

player:SetAttribute("OverheadCamera", false)
player:SetAttribute("CameraMode", "Person")

-- Minimap click (WarClient.CameraJump): look at that world point. PERSON switches to TOP first;
-- TOP keeps its height and slides so the point is under the screen centre; FREE keeps height + angle.
require(ReplicatedStorage:WaitForChild("WarClient"):WaitForChild("CameraJump")).Requested:Connect(function(target)
	if mode == "Person" then
		enterTop()
	end
	if mode == "Top" then
		local back = LOOK * ((pos.Y - target.Y) / math.max(-LOOK.Y, 0.1))
		pos = Vector3.new(target.X - back.X, pos.Y, target.Z - back.Z)
	else
		local look = freeCFrame().LookVector
		local h = pos.Y - target.Y
		if look.Y < -0.05 and h > 0 then
			local back = look * (h / -look.Y)
			pos = Vector3.new(target.X - back.X, pos.Y, target.Z - back.Z)
		else
			pos = Vector3.new(target.X, pos.Y, target.Z) - flat(look) * 60
		end
	end
end)
