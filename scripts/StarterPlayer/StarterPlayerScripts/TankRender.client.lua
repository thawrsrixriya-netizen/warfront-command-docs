-- StarterPlayer.StarterPlayerScripts.TankRender  (LocalScript)
-- TankRender: draws every command tank locally from pose snapshots the server publishes
-- (TankPos, TankYaw, TankPitch, TurretYaw, TankT at ~20 Hz). Snapshot interpolation: render
-- slightly in the past (DELAY) and blend between the two snapshots around that time, so motion
-- is even at any frame rate, without replicating every part every frame.
local RunService = game:GetService("RunService")
local VisualState=require(game.ReplicatedStorage.WarClient.TankVisualState)

local tanksFolder = workspace:WaitForChild("CommandTanks")
local DELAY = 0.1 -- seconds behind the server; > 1 publish interval (0.05)
local states = {} -- [Model] = { Snaps = { {T, Pos, Yaw, Pitch, Turret}, ... } }

local function wrap(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function snapshot(model)
	return {
		T = model:GetAttribute("TankT"),
		Pos = model:GetAttribute("TankPos"),
		Yaw = model:GetAttribute("TankYaw") or 0,
		Pitch = model:GetAttribute("TankPitch") or 0,
		Turret = model:GetAttribute("TurretYaw") or 0,
		Gun = model:GetAttribute("GunPitch") or 0,
	}
end

local function track(model)
	if states[model] then
		return
	end
	local st = { Snaps = {} }
	states[model] = st
	local function push()
		local s = snapshot(model)
		if not (s.T and s.Pos) then
			return
		end
		local last = st.Snaps[#st.Snaps]
		if last and s.T <= last.T then
			return
		end
		if last and s.T - last.T > 0.2 then
			-- the tank was idle (server sends nothing then): restart the blend just before this snapshot
			table.insert(st.Snaps, { T = s.T - 0.05, Pos = last.Pos, Yaw = last.Yaw, Pitch = last.Pitch, Turret = last.Turret, Gun = last.Gun })
		end
		table.insert(st.Snaps, s)
		while #st.Snaps > 8 do
			table.remove(st.Snaps, 1)
		end
	end
	st.Conn = model:GetAttributeChangedSignal("TankT"):Connect(push)
	push()
end

local function untrack(model)
	local st = states[model]
	if st then
		st.Conn:Disconnect()
		states[model] = nil
		VisualState.Poses[model]=nil
	end
end

for _, m in ipairs(tanksFolder:GetChildren()) do
	track(m)
end
tanksFolder.ChildAdded:Connect(track)
tanksFolder.ChildRemoved:Connect(untrack)

local function sample(snaps, t)
	local n = #snaps
	if n == 0 then
		return nil
	end
	if t <= snaps[1].T or n == 1 then
		return snaps[1]
	end
	for i = n - 1, 1, -1 do
		local a, b = snaps[i], snaps[i + 1]
		if t >= a.T then
			if t >= b.T then
				return b -- newest snapshot is older than render time: hold it
			end
			local u = (t - a.T) / (b.T - a.T)
			return {
				Pos = a.Pos:Lerp(b.Pos, u),
				Yaw = a.Yaw + wrap(b.Yaw - a.Yaw) * u,
				Pitch = a.Pitch + (b.Pitch - a.Pitch) * u,
				Turret = a.Turret + wrap(b.Turret - a.Turret) * u,
				Gun = (a.Gun or 0) + ((b.Gun or 0)-(a.Gun or 0))*u,
			}
		end
	end
	return snaps[n]
end

RunService:BindToRenderStep("CommandTankRender",Enum.RenderPriority.Camera.Value+10,function()
	local renderT = workspace:GetServerTimeNow() - DELAY
	for model, st in pairs(states) do
		local hullRel = model:GetAttribute("HullRel")
		local turretRel = model:GetAttribute("TurretRel")
		local axis = model:GetAttribute("TurretAxis")
		local centreRel = model:GetAttribute("HullCenterRel")
		local hull = model:FindFirstChild("Hull")
		local turret = model:FindFirstChild("Turret")
		local s = sample(st.Snaps, renderT)
		VisualState.Poses[model]=s
		if s and hullRel and turretRel and axis and centreRel and hull and turret then
			local groundOffset = model:GetAttribute("GroundOffset") or 0
			local base = CFrame.new(s.Pos) * CFrame.Angles(0, s.Yaw, 0)
			local pc = Vector3.new(centreRel.X, -groundOffset, centreRel.Z)
			local visual = base * CFrame.new(pc) * CFrame.Angles(math.rad(s.Pitch), 0, 0) * CFrame.new(-pc)
			local hullCF=visual * hullRel
   hull:PivotTo(hullCF)

			local turretCF = visual * CFrame.new(axis) * CFrame.Angles(0,s.Turret,0) * CFrame.new(-axis) * turretRel
   turret:PivotTo(turretCF)
   local gun=turret:FindFirstChild("Gun")
   local mount=model:GetAttribute("GunMountRel")
   local gunRel=model:GetAttribute("GunPivotRel")
   if gun and mount and gunRel then
    gun:PivotTo(turretCF * mount * CFrame.Angles(s.Gun or 0,0,0) * gunRel)
   end
		end
	end
end)
