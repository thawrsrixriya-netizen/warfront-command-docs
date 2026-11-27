-- ServerScriptService.WarServer.AC130Targeting  (ModuleScript)
-- AC130Targeting (server): exact maximum-coverage search for one AOE gun on the XZ plane.
-- Candidate centres: support centre, previous aim, enemy positions, pairwise intersections of
-- radius-R disks around enemies, and intersections of those disks with the selection boundary.
-- A candidate is valid only if it lies inside the selection circle AND covers an eligible,
-- unreserved primary enemy that is itself inside the selection circle.
-- Equal coverage breaks toward the previous aim (less jitter).
local Targeting = {}

local EPS = 1e-3
local YIELD_EVERY = 3000

local function intersections(a, ra, b, rb)
	local delta = b - a
	local d = delta.Magnitude
	if d < 1e-6 or d > ra + rb or d < math.abs(ra - rb) then
		return nil
	end
	local x = (d * d + ra * ra - rb * rb) / (2 * d)
	local h = math.sqrt(math.max(ra * ra - x * x, 0))
	local dir = delta / d
	local mid = a + dir * x
	local perp = Vector2.new(-dir.Y, dir.X)
	return mid + perp * h, mid - perp * h
end

-- enemies: array of { Model, Position (Vector3) } within selR + blastR of the centre.
-- reserved: set [Model] = true. prevAim: Vector2 or nil. isCancelled(): bool (checked after yields).
-- Returns aim (Vector2), primary (Model), coveredCount — or nil.
function Targeting.planAOE(enemies, centre3, selR, blastR, reserved, prevAim, isCancelled)
	local centre = Vector2.new(centre3.X, centre3.Z)
	local pts = table.create(#enemies)
	for i, e in ipairs(enemies) do
		pts[i] = Vector2.new(e.Position.X, e.Position.Z)
	end

	-- spatial grid (cell = blast radius)
	local cell = math.max(blastR, 1)
	local grid = {}
	local function key(ix, iz)
		return ix * 73856093 + iz * 19349663
	end
	for i, p in ipairs(pts) do
		local k = key(math.floor(p.X / cell), math.floor(p.Y / cell))
		local bucket = grid[k]
		if not bucket then
			bucket = {}
			grid[k] = bucket
		end
		table.insert(bucket, i)
	end

	local candidates = {}
	local function add(v)
		if v and (v - centre).Magnitude <= selR + EPS then
			table.insert(candidates, v)
		end
	end
	add(centre)
	add(prevAim)
	for _, p in ipairs(pts) do
		add(p)
	end
	local work = 0
	for i = 1, #pts do
		for j = i + 1, #pts do
			local a, b = intersections(pts[i], blastR, pts[j], blastR)
			add(a)
			add(b)
			work += 1
			if work % YIELD_EVERY == 0 then
				task.wait()
				if isCancelled and isCancelled() then
					return nil
				end
			end
		end
		local a, b = intersections(pts[i], blastR, centre, selR)
		add(a)
		add(b)
	end

	local best, bestCount, bestPrimary, bestPrevDist = nil, 0, nil, math.huge
	for n, c in ipairs(candidates) do
		local count = 0
		local primary, primaryDist = nil, math.huge
		local cx, cz = math.floor(c.X / cell), math.floor(c.Y / cell)
		for ix = cx - 1, cx + 1 do
			for iz = cz - 1, cz + 1 do
				local bucket = grid[key(ix, iz)]
				if bucket then
					for _, i in ipairs(bucket) do
						local d = (pts[i] - c).Magnitude
						if d <= blastR + EPS then
							count += 1
							local model = enemies[i].Model
							if not reserved[model] and (pts[i] - centre).Magnitude <= selR + EPS and d < primaryDist then
								primary, primaryDist = model, d
							end
						end
					end
				end
			end
		end
		if primary then
			local prevDist = prevAim and (c - prevAim).Magnitude or 0
			if count > bestCount or (count == bestCount and prevDist < bestPrevDist) then
				best, bestCount, bestPrimary, bestPrevDist = c, count, primary, prevDist
			end
		end
		if n % YIELD_EVERY == 0 then
			task.wait()
			if isCancelled and isCancelled() then
				return nil
			end
		end
	end
	if not best then
		return nil
	end
	return best, bestPrimary, bestCount
end

-- Single-target gun: keep the previous target while valid, otherwise the nearest unreserved enemy.
function Targeting.planSingle(enemiesInSel, centre3, reserved, previous)
	if previous and not reserved[previous] then
		for _, e in ipairs(enemiesInSel) do
			if e.Model == previous then
				return previous
			end
		end
	end
	local best, bestD = nil, math.huge
	for _, e in ipairs(enemiesInSel) do
		if not reserved[e.Model] then
			local d = (Vector2.new(e.Position.X, e.Position.Z) - Vector2.new(centre3.X, centre3.Z)).Magnitude
			if d < bestD then
				best, bestD = e.Model, d
			end
		end
	end
	return best
end

return Targeting
