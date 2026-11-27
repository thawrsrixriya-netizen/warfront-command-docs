-- ReplicatedStorage.WarShared.AC130Path  (ModuleScript)
-- AC130Path (shared): deterministic AC-130 flight path, evaluated from server time.
-- Server uses it for gun origins/timing; every client renders the plane from the same function.
-- params = { Center = Vector3 (Y = flight altitude), GroundY, Theta0, EntryDistance, T0, TDepart? }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("WarConfig")).AC130

local Path = {}

local R = Config.OrbitRadius
local W = Config.OrbitAngularSpeedRad
local VO = R * W -- orbit speed (~39.27)
local VT = Config.TransitSpeed -- entry / departure speed (130)
local LDEC = 300 -- distance used to slow from VT to VO before the orbit
local A = (VT * VT - VO * VO) / (2 * LDEC)
local TDEC = (VT - VO) / A

Path.OrbitSpeed = VO

function Path.entryDuration(p)
	return (p.EntryDistance - LDEC) / VT + TDEC
end

local function entry(p, t)
	local cruiseT = (p.EntryDistance - LDEC) / VT
	if t <= cruiseT then
		return VT * t, VT
	end
	local u = math.min(t - cruiseT, TDEC)
	return (p.EntryDistance - LDEC) + VT * u - 0.5 * A * u * u, VT - A * u
end

local function orbitPoint(p, theta)
	return p.Center + Vector3.new(math.cos(theta), 0, math.sin(theta)) * R
end

-- The AC-130's guns are on its LEFT side, so it orbits with the centre on its left
-- (theta decreases) and banks left-wing-down toward the target, like the real gunship.
local SPIN = -1
local function tangent(theta)
	return Vector3.new(-math.sin(theta), 0, math.cos(theta)) * SPIN
end

-- Returns position, forward (unit, horizontal), bank (0..1, 1 = full inward bank), phase, speed
local function stateNoDepart(p, now)
	local t = now - p.T0
	local tOrbit = Path.entryDuration(p)
	if t < tOrbit then
		local P0 = orbitPoint(p, p.Theta0)
		local T = tangent(p.Theta0)
		local s, v = entry(p, math.max(t, 0))
		local bank = math.clamp((VT - v) / (VT - VO), 0, 1)
		return P0 - T * (p.EntryDistance - s), T, bank, "entry", v
	end
	local theta = p.Theta0 + SPIN * W * (t - tOrbit)
	return orbitPoint(p, theta), tangent(theta), 1, "orbit", VO
end

function Path.state(p, now)
	if not p.TDepart or now < p.TDepart then
		return stateNoDepart(p, now)
	end
	local pos0, dir0, bank0, _, v0 = stateNoDepart(p, p.TDepart)
	local u = now - p.TDepart
	local tAcc = math.max((VT - v0) / A, 0)
	local s
	if u <= tAcc then
		s = v0 * u + 0.5 * A * u * u
	else
		s = v0 * tAcc + 0.5 * A * tAcc * tAcc + VT * (u - tAcc)
	end
	local v = math.min(v0 + A * u, VT)
	local bank = bank0 * math.clamp((VT - v) / math.max(VT - v0, 1e-3), 0, 1)
	return pos0 + dir0 * s, dir0, bank, "depart", v
end

function Path.departDone(p, now)
	if not p.TDepart or now < p.TDepart then
		return false
	end
	local pos = Path.state(p, now)
	local d = pos - p.Center
	return Vector2.new(d.X, d.Z).Magnitude > p.EntryDistance + R
end

-- Model CFrame for the plane. noseFix maps the model's nose to -Z; bank rolls the inner (left) wing
-- down (the orbit centre is always on the plane's left because theta decreases, see SPIN).
function Path.cframe(pos, forward, bank, noseFix)
	local roll = math.rad(Config.BankAngle) * bank
	return CFrame.lookAlong(pos, forward) * CFrame.Angles(0, 0, roll) * noseFix
end

return Path
