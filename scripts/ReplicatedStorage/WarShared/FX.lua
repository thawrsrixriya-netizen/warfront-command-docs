-- ReplicatedStorage.WarShared.FX  (ModuleScript)
-- FX (client): explosions, debris, smoke, tracers, ground rings.
-- All parts: anchored, CanCollide/CanTouch/CanQuery = false, parented to Workspace.ClientFX.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FX = {}

local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"

local function folder()
	local f = workspace:FindFirstChild("ClientFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ClientFX"
		f.Parent = workspace
	end
	return f
end
FX.folder = folder

function FX.part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "ClassName" then
			p[k] = v
		end
	end
	p.Parent = parent or folder()
	return p
end

local function tween(inst, time, goal, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
FX.tween = tween

---------------------------------------------------------------- moving debris (one shared loop)
local active = {}
local gravity = Vector3.new(0, -workspace.Gravity * 0.6, 0)
RunService.RenderStepped:Connect(function(dt)
	for i = #active, 1, -1 do
		local d = active[i]
		d.Age += dt
		if d.Age >= d.Life or not d.Part.Parent then
			if d.Part.Parent then
				d.Part:Destroy()
			end
			table.remove(active, i)
		else
			if not d.Landed then
				d.Vel += gravity * dt
				local pos = d.Pos + d.Vel * dt
				if pos.Y <= d.GroundY then
					pos = Vector3.new(pos.X, d.GroundY, pos.Z)
					d.Landed = true
				end
				d.Pos = pos
				d.Rot = d.Rot * CFrame.Angles(d.Spin.X * dt, d.Spin.Y * dt, d.Spin.Z * dt)
			end
			d.Part.CFrame = CFrame.new(d.Pos) * d.Rot
			local fade = math.clamp((d.Age - d.Life * 0.6) / (d.Life * 0.4), 0, 1)
			d.Part.Transparency = fade
		end
	end
end)

function FX.debris(pos, count, speed, size, colors, life, material)
	for _ = 1, count do
		local s = size * (0.5 + math.random())
		local part = FX.part({
			Size = Vector3.new(s, s * (0.5 + math.random() * 0.5), s),
			Color = colors[math.random(1, #colors)],
			Material = material or Enum.Material.Ground,
			CFrame = CFrame.new(pos),
		})
		local a = math.random() * math.pi * 2
		local up = 0.6 + math.random() * 0.9
		local v = Vector3.new(math.cos(a), up, math.sin(a)).Unit * speed * (0.4 + math.random() * 0.8)
		table.insert(active, {
			Part = part,
			Pos = pos + Vector3.new(0, 0.3, 0),
			Vel = v,
			Rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Spin = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5),
			GroundY = pos.Y,
			Age = 0,
			Life = life * (0.7 + math.random() * 0.6),
		})
	end
end

function FX.particles(pos, opts)
	local holder = FX.part({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos) })
	local att = Instance.new("Attachment")
	att.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.Texture or SMOKE_TEX
	e.Color = ColorSequence.new(opts.Color or Color3.fromRGB(90, 85, 80))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.Size * 0.4),
		NumberSequenceKeypoint.new(1, opts.Size),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.StartAlpha or 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(opts.Life * 0.7, opts.Life)
	e.Speed = NumberRange.new(opts.Speed * 0.5, opts.Speed)
	e.SpreadAngle = Vector2.new(opts.Spread or 180, opts.Spread or 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Acceleration = Vector3.new(0, opts.Rise or 2, 0)
	e.Drag = opts.Drag or 1.5
	e.LightEmission = opts.Light or 0
	e.LightInfluence = opts.Light and 0 or 1
	e.ZOffset = opts.ZOffset or 0
	e.Enabled = false
	e.Parent = att
	e:Emit(opts.Count)
	Debris:AddItem(holder, opts.Life + 0.5)
end

function FX.flash(pos, size, color, duration)
	local ball = FX.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size * 0.3, size * 0.3, size * 0.3),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.05,
		CFrame = CFrame.new(pos),
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 6
	light.Range = math.min(size * 2.5, 60)
	light.Parent = ball
	tween(ball, duration, { Size = Vector3.new(size, size, size), Transparency = 1 })
	tween(light, duration, { Brightness = 0 })
	Debris:AddItem(ball, duration + 0.1)
end

-- expanding flat ring on the ground
function FX.blastRing(pos, diameter, color, duration)
	local disc = FX.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, diameter * 0.2, diameter * 0.2),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	tween(disc, duration, { Size = Vector3.new(0.15, diameter, diameter), Transparency = 1 })
	Debris:AddItem(disc, duration + 0.1)
end

local SOIL = { Color3.fromRGB(92, 70, 48), Color3.fromRGB(110, 86, 60), Color3.fromRGB(70, 55, 40), Color3.fromRGB(125, 105, 78) }
local DUST = { Color3.fromRGB(150, 135, 110), Color3.fromRGB(120, 108, 90) }
local FIRE = Color3.fromRGB(255, 170, 40)
local YELLOW = Color3.fromRGB(255, 225, 90)

FX.Colors = {
	Red = Color3.fromRGB(255, 60, 40),
	Orange = Color3.fromRGB(255, 140, 30),
	Yellow = YELLOW,
	Fire = FIRE,
}

local STYLES = {
	Heavy = function(pos)
		FX.flash(pos + Vector3.new(0, 3, 0), 26, FIRE, 0.45)
		FX.flash(pos + Vector3.new(0, 2, 0), 14, YELLOW, 0.25)
		FX.blastRing(pos, 50, Color3.fromRGB(255, 120, 30), 0.5)
		FX.debris(pos, 30, 55, 1.1, SOIL, 1.6)
		FX.particles(pos, { Count = 22, Size = 16, Life = 3.2, Speed = 14, Rise = 3, Color = Color3.fromRGB(70, 64, 58), StartAlpha = 0.2 })
		FX.particles(pos, { Count = 10, Size = 10, Life = 0.6, Speed = 18, Texture = FIRE_TEX, Color = FIRE, Light = 1, Rise = 6 })
	end,
	Secondary = function(pos)
		FX.flash(pos + Vector3.new(0, 1.5, 0), 12, FIRE, 0.3)
		FX.blastRing(pos, 30, Color3.fromRGB(255, 190, 70), 0.35)
		FX.debris(pos, 16, 32, 0.55, SOIL, 1.2)
		FX.particles(pos, { Count = 14, Size = 8, Life = 2.2, Speed = 10, Rise = 2, Color = Color3.fromRGB(165, 150, 125), StartAlpha = 0.3 })
	end,
	MG = function(pos)
		FX.flash(pos + Vector3.new(0, 0.5, 0), 2.5, YELLOW, 0.12)
		FX.debris(pos, 5, 18, 0.3, SOIL, 0.8)
		FX.particles(pos, { Count = 3, Size = 2.5, Life = 0.9, Speed = 4, Color = Color3.fromRGB(150, 135, 110), StartAlpha = 0.4 })
	end,
	Bomb = function(pos)
		FX.flash(pos + Vector3.new(0, 2.5, 0), 18, FIRE, 0.4)
		FX.flash(pos + Vector3.new(0, 1.5, 0), 9, YELLOW, 0.22)
		FX.blastRing(pos, require(game.ReplicatedStorage.WarConfig).Bomber.DamageRadius * 2, Color3.fromRGB(255, 140, 40), 0.4) -- ring = SU-34 damage diameter
		FX.debris(pos, 20, 42, 0.8, SOIL, 1.4)
		FX.particles(pos, { Count = 14, Size = 11, Life = 2.8, Speed = 11, Rise = 3, Color = Color3.fromRGB(75, 70, 62), StartAlpha = 0.2 })
	end,
	FPV = function(pos)
		FX.flash(pos + Vector3.new(0, 1.5, 0), 12, FIRE, 0.35)
		FX.flash(pos + Vector3.new(0, 1, 0), 6, YELLOW, 0.2)
		FX.blastRing(pos, 20, Color3.fromRGB(255, 150, 50), 0.4)
		FX.debris(pos, 14, 30, 0.6, SOIL, 1.2)
		FX.particles(pos, { Count = 10, Size = 8, Life = 2.4, Speed = 8, Rise = 2.5, Color = Color3.fromRGB(80, 74, 66), StartAlpha = 0.25 })
	end,
	-- tank round: small AOE blast; the ring shows the 10-stud damage diameter
	TankShell = function(pos)
		FX.flash(pos + Vector3.new(0, 1, 0), 6, FIRE, 0.22)
		FX.flash(pos + Vector3.new(0, 0.8, 0), 3, YELLOW, 0.12)
		FX.blastRing(pos, 10, Color3.fromRGB(255, 150, 50), 0.3)
		FX.debris(pos, 8, 24, 0.4, SOIL, 1)
		FX.particles(pos, { Count = 6, Size = 5, Life = 1.6, Speed = 6, Rise = 2, Color = Color3.fromRGB(95, 88, 78), StartAlpha = 0.3 })
	end,
	TankHit = function(pos)
		FX.flash(pos + Vector3.new(0, 0.6, 0), 3.5, YELLOW, 0.15)
		FX.debris(pos, 6, 20, 0.35, SOIL, 0.9)
		FX.particles(pos, { Count = 4, Size = 3, Life = 1, Speed = 5, Color = Color3.fromRGB(140, 125, 100), StartAlpha = 0.35 })
	end,
}

function FX.explosion(pos, style)
	local f = STYLES[style] or STYLES.Bomb
	f(pos)
end

-- short glowing bolt flying from a to b
function FX.tracer(from, to, color, width, speed, length)
	local dir = to - from
	local dist = dir.Magnitude
	if dist < 0.1 then
		return 0
	end
	dir = dir / dist
	length = math.min(length or 6, dist)
	local bolt = FX.part({
		Size = Vector3.new(width or 0.25, width or 0.25, length),
		Color = color,
		Material = Enum.Material.Neon,
		CFrame = CFrame.lookAlong(from + dir * length / 2, dir),
	})
	local travel = dist / (speed or 600)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / travel, 0, 1)
		local head = from + dir * (length / 2 + (dist - length) * a)
		bolt.CFrame = CFrame.lookAlong(head, dir)
		if a >= 1 then
			conn:Disconnect()
			bolt:Destroy()
		end
	end)
	return travel
end

function FX.muzzleFlash(pos, size)
	FX.flash(pos, size or 2, YELLOW, 0.08)
end

-- ground ring outline made of segments; returns the Model
function FX.ring(center, radius, color, transparency, thickness, segments, parent)
	local m = Instance.new("Model")
	m.Name = "Ring"
	segments = segments or math.clamp(math.floor(radius / 3), 24, 72)
	local segLen = 2 * math.pi * radius / segments * 1.04
	for i = 1, segments do
		local a = (i - 0.5) / segments * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0.2, math.sin(a) * radius)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		FX.part({
			Size = Vector3.new(thickness or 0.4, 0.12, segLen),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = transparency or 0.3,
			CFrame = CFrame.lookAlong(p, tangent),
		}, m)
	end
	m.Parent = parent or folder()
	return m
end

-- flat arrow lying on the ground; model pivot at its centre, tip toward -Z.
-- Place with arrow:PivotTo(CFrame.lookAlong(pos, dir)).
function FX.arrow(length, color, parent)
	local m = Instance.new("Model")
	m.Name = "Arrow"
	local props = { Color = color, Material = Enum.Material.Neon, Transparency = 0.1 }
	local function bar(cf, len)
		local p = FX.part(props, m)
		p.Size = Vector3.new(0.45, 0.15, len)
		p.CFrame = cf
	end
	bar(CFrame.new(0, 0, 0), length)
	local tip = Vector3.new(0, 0, -length / 2)
	local head = length * 0.4
	for _, s in ipairs({ -1, 1 }) do
		local d = Vector3.new(math.sin(math.rad(35)) * s, 0, math.cos(math.rad(35)))
		bar(CFrame.lookAlong(tip + d * head / 2, d), head)
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent or folder()
	return m
end

function FX.moveRing(ring, center)
	ring:PivotTo(CFrame.new(center))
end

return FX
