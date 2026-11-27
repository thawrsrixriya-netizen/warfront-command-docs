-- StarterPlayer.StarterPlayerScripts.FPVInput  (LocalScript)
-- FPVInput: called from the Skill panel -> aim (same flow as the SU-34):
-- 1st left click places the start circle (d = AimCircleDiameter), the mouse turns the Width x Length
-- flight corridor around it, 2nd click launches. Escape cancels. Outlines only (no filled areas).
-- Also spins FPV rotors locally (Motor6D.Transform).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage:WaitForChild("WarConfig")).FPV
local Shared = ReplicatedStorage:WaitForChild("WarShared")
local Client = ReplicatedStorage:WaitForChild("WarClient")
local U = require(Shared:WaitForChild("WarUtil"))
local FX = require(Shared:WaitForChild("FX"))
local InputMode = require(Client:WaitForChild("InputMode"))
local Aim = require(Client:WaitForChild("Aim"))
local FPVCommand = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FPVCommand")
local player = Players.LocalPlayer

local MODE = "FPVAim"
local aim -- { Model, Circle, Rect, EndRing, Ghost, Anchor, AnchorTime, Dir, Conn }

local LINE_WIDTH = 0.6
local AIM_YELLOW, PATH_ORANGE, BLAST_RED = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 80, 50) -- aim ring white; corridor + blast ring keep their colours
local function outlineModel(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.PrimaryPart = FX.part({ Name = "Pivot", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = CFrame.new() }, m)
	m.Parent = parent
	return m
end
local function edge(m, color, length, cf)
	FX.part({ Size = Vector3.new(LINE_WIDTH, 0.12, length), Color = color, Material = Enum.Material.Neon, Transparency = 0.1, CFrame = cf }, m)
end
local function ringOutline(diameter, color, parent)
	local m, r, n = outlineModel("AimRing", parent), diameter / 2, 40
	for i = 1, n do
		local a = (i - 0.5) / n * 2 * math.pi
		edge(m, color, 2 * math.pi * r / n * 1.08, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(0, -a, 0))
	end
	return m
end
local function rectOutline(width, length, color, parent)
	local m = outlineModel("FlightArea", parent)
	edge(m, color, length + LINE_WIDTH, CFrame.new(-width / 2, 0, 0))
	edge(m, color, length + LINE_WIDTH, CFrame.new(width / 2, 0, 0))
	edge(m, color, width + LINE_WIDTH, CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, math.pi / 2, 0))
	edge(m, color, width + LINE_WIDTH, CFrame.new(0, 0, length / 2) * CFrame.Angles(0, math.pi / 2, 0))
	return m
end

local function clearAim()
	if aim then
		if aim.Conn then
			aim.Conn:Disconnect()
		end
		aim.Model:Destroy()
		aim = nil
	end
	player:SetAttribute("FPVAimMode", false)
end

local function makeGhost(parent)
	local ghostSrc = ReplicatedStorage:FindFirstChild("FPVDronePreview")
	if not ghostSrc then
		return nil
	end
	local g = U.makeVisual(ghostSrc:Clone())
	g:ScaleTo(g:GetScale() * C.DroneScale)
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.45)
		end
	end
	g.Parent = parent
	return g
end

local function updateAim()
	local hit = Aim.groundHit()
	if not aim or not hit then
		return
	end
	local lift = Vector3.new(0, 0.15, 0)
	if not aim.Anchor then
		aim.Circle:PivotTo(CFrame.new(hit + lift))
		return
	end
	local d = U.flat(hit - aim.Anchor)
	if d then
		aim.Dir = d
	end
	aim.Rect = aim.Rect or rectOutline(C.Width, C.Length, PATH_ORANGE, aim.Model)
	aim.EndRing = aim.EndRing or ringOutline(C.BlastRadius * 2, BLAST_RED, aim.Model)
	aim.Rect:PivotTo(CFrame.lookAlong(aim.Anchor + aim.Dir * (C.Length / 2) + lift, aim.Dir))
	aim.EndRing:PivotTo(CFrame.new(aim.Anchor + aim.Dir * C.Length + lift))
	if aim.Ghost == nil then
		aim.Ghost = makeGhost(aim.Model) or false
	end
	if aim.Ghost then
		aim.Ghost:PivotTo(CFrame.lookAlong(aim.Anchor + Vector3.new(0, C.Height, 0), aim.Dir))
	end
end

local function enterAim()
	if InputMode.get() == MODE then
		return
	end
	InputMode.enter(MODE, clearAim) -- leaves any other mode first
	player:SetAttribute("FPVAimMode", true)
	local m = Instance.new("Model")
	m.Name = "FPVAimPreview"
	m.Parent = FX.folder()
	aim = { Model = m, Dir = U.flat(workspace.CurrentCamera.CFrame.LookVector) or Vector3.new(0, 0, -1) }
	aim.Circle = ringOutline(C.AimCircleDiameter, AIM_YELLOW, m)
	aim.Conn = RunService.RenderStepped:Connect(updateAim)
	updateAim()
end

-- 1st click = start point, mouse turns the run, 2nd click = launch.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if InputMode.isTyping() or InputMode.get() ~= MODE then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		InputMode.exit(MODE)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		InputMode.blockClicks(C.InputBlockAfterConfirm)
		if aim and not aim.Anchor then
			local hit = Aim.groundHit()
			if hit then
				aim.Anchor = hit
				aim.AnchorTime = os.clock()
				aim.Circle:PivotTo(CFrame.new(hit + Vector3.new(0, 0.15, 0)))
				updateAim()
			end
		elseif aim and aim.Anchor and os.clock() - aim.AnchorTime > 0.2 then
			FPVCommand:FireServer("Launch", aim.Anchor, aim.Dir)
			player:SetAttribute("FPVInputBlockedUntil", os.clock() + C.InputBlockAfterConfirm)
			InputMode.exit(MODE)
		end
	end
end)

require(Client:WaitForChild("SkillActions")).register("FPV", {
	Mode = MODE,
	Call = enterAim,
	Hint = "Click to set the start, move the mouse to aim, click again to launch the drone",
})

---------------------------------------------------------------- rotor spin (local only)
local motors = {}
local flights = U.folder("FPVFlights")
local function consider(d)
	if d:IsA("Motor6D") and d:GetAttribute("FPVRotor") then
		motors[d] = true
	end
end
for _, d in ipairs(flights:GetDescendants()) do
	consider(d)
end
flights.DescendantAdded:Connect(consider)
flights.DescendantRemoving:Connect(function(d)
	motors[d] = nil
end)
RunService.RenderStepped:Connect(function()
	local angle = os.clock() * 70
	for m in pairs(motors) do
		m.Transform = CFrame.Angles(0, angle, 0)
	end
end)
