-- ServerScriptService.WarServer.TankRoadNavigation  (ModuleScript)
-- TankRoadNavigation (server): routes along parts tagged TankRoad (local Z = length).
-- Graph: segment endpoints (merged within RoadMergeDistance), extra joins between endpoints
-- closer than the road widths, and T-junction splits where an endpoint touches another
-- segment's middle. Dijkstra over the graph.
-- route(from, to) returns:
--   waypoints (array of Vector3)  if `to` lies on a road and the roads connect
--   false, "disconnected"         if `to` is on a road but unreachable from the entry point
--   nil                           if `to` is off-road (caller uses normal movement)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local C = require(ReplicatedStorage:WaitForChild("WarConfig")).Tank

local Roads = {}

local graph -- { Nodes = {Vector2}, Adj = {[i] = {[j] = cost}}, Segs = {...} }
local dirty = true

local function v2(v)
	return Vector2.new(v.X, v.Z)
end

local function markDirty()
	dirty = true
end
CollectionService:GetInstanceAddedSignal(C.RoadTag):Connect(markDirty)
CollectionService:GetInstanceRemovedSignal(C.RoadTag):Connect(markDirty)

local function build()
	local nodes, adj, segs = {}, {}, {}
	local function nodeFor(p, tol)
		for i, n in ipairs(nodes) do
			if (n - p).Magnitude <= tol then
				return i
			end
		end
		table.insert(nodes, p)
		adj[#nodes] = {}
		return #nodes
	end
	local function link(i, j)
		if i ~= j then
			local cost = (nodes[i] - nodes[j]).Magnitude
			adj[i][j] = math.min(adj[i][j] or math.huge, cost)
			adj[j][i] = adj[i][j]
		end
	end
	for _, part in ipairs(CollectionService:GetTagged(C.RoadTag)) do
		if part:IsA("BasePart") then
			local half = part.Size.Z / 2
			local a = v2((part.CFrame * CFrame.new(0, 0, -half)).Position)
			local b = v2((part.CFrame * CFrame.new(0, 0, half)).Position)
			local seg = { A = a, B = b, W = part.Size.X, Part = part }
			seg.NA = nodeFor(a, C.RoadMergeDistance)
			seg.NB = nodeFor(b, C.RoadMergeDistance)
			seg.Splits = { { T = 0, N = seg.NA }, { T = 1, N = seg.NB } }
			table.insert(segs, seg)
		end
	end
	-- endpoint joins that depend on road width
	for i, s1 in ipairs(segs) do
		for j = i + 1, #segs do
			local s2 = segs[j]
			local joinDist = (s1.W + s2.W) / 2
			for _, e1 in ipairs({ s1.NA, s1.NB }) do
				for _, e2 in ipairs({ s2.NA, s2.NB }) do
					if e1 ~= e2 and (nodes[e1] - nodes[e2]).Magnitude <= joinDist then
						link(e1, e2)
					end
				end
			end
		end
	end
	-- T-junctions: endpoint of one segment touching the middle of another
	for _, s1 in ipairs(segs) do
		for _, s2 in ipairs(segs) do
			if s1 ~= s2 then
				local ab = s2.B - s2.A
				local len2 = ab:Dot(ab)
				if len2 > 1e-6 then
					for _, e in ipairs({ s1.NA, s1.NB }) do
						local p = nodes[e]
						local t = (p - s2.A):Dot(ab) / len2
						if t > 0.02 and t < 0.98 then
							local proj = s2.A + ab * t
							if (p - proj).Magnitude <= s2.W / 2 + 0.5 then
								local n = nodeFor(proj, 0.5)
								table.insert(s2.Splits, { T = t, N = n })
								link(e, n)
							end
						end
					end
				end
			end
		end
	end
	for _, s in ipairs(segs) do
		table.sort(s.Splits, function(x, y)
			return x.T < y.T
		end)
		for k = 1, #s.Splits - 1 do
			link(s.Splits[k].N, s.Splits[k + 1].N)
		end
	end
	graph = { Nodes = nodes, Adj = adj, Segs = segs }
	dirty = false
end

local function project(seg, p)
	local ab = seg.B - seg.A
	local len2 = ab:Dot(ab)
	local t = len2 > 1e-6 and math.clamp((p - seg.A):Dot(ab) / len2, 0, 1) or 0
	local q = seg.A + ab * t
	return q, t, (p - q).Magnitude
end

-- neighbours of a temporary point at parameter t on seg: the nearest split nodes on each side
local function bracket(seg, t)
	local lo, hi = seg.Splits[1], seg.Splits[#seg.Splits]
	for _, s in ipairs(seg.Splits) do
		if s.T <= t then
			lo = s
		end
	end
	for k = #seg.Splits, 1, -1 do
		if seg.Splits[k].T >= t then
			hi = seg.Splits[k]
		end
	end
	return lo, hi
end

function Roads.isOnRoad(p3)
	if dirty then
		build()
	end
	local p = v2(p3)
	for _, seg in ipairs(graph.Segs) do
		local _, _, d = project(seg, p)
		if d <= seg.W / 2 then
			return seg
		end
	end
	return nil
end

function Roads.route(from3, to3)
	if dirty then
		build()
	end
	if #graph.Segs == 0 then
		return nil
	end
	local to = v2(to3)
	local from = v2(from3)
	-- destination must be on a road
	local destSeg, destQ, destT
	local bestD = math.huge
	for _, seg in ipairs(graph.Segs) do
		local q, t, d = project(seg, to)
		if d <= seg.W / 2 and d < bestD then
			destSeg, destQ, destT, bestD = seg, q, t, d
		end
	end
	if not destSeg then
		return nil
	end
	-- entry: nearest point on any road to the tank
	local startSeg, startQ, startT
	bestD = math.huge
	for _, seg in ipairs(graph.Segs) do
		local q, t, d = project(seg, from)
		if d < bestD then
			startSeg, startQ, startT, bestD = seg, q, t, d
		end
	end

	local y = to3.Y
	local function w(p)
		return Vector3.new(p.X, y, p.Y)
	end
	if startSeg == destSeg then
		return { w(startQ), w(destQ), to3 }
	end

	-- Dijkstra with two temporary nodes (S = entry, D = destination projection)
	local nodes, adj = graph.Nodes, graph.Adj
	local S, D = "S", "D"
	local pos = { [S] = startQ, [D] = destQ }
	local extra = { [S] = {}, [D] = {} }
	local function tempLinks(tag, seg, t)
		local lo, hi = bracket(seg, t)
		for _, sp in ipairs({ lo, hi }) do
			local cost = (nodes[sp.N] - pos[tag]).Magnitude
			extra[tag][sp.N] = cost
		end
	end
	tempLinks(S, startSeg, startT)
	tempLinks(D, destSeg, destT)
	local function neighbours(n)
		local list = {}
		if n == S or n == D then
			for m, c in pairs(extra[n]) do
				list[m] = c
			end
		else
			for m, c in pairs(adj[n]) do
				list[m] = c
			end
			for tag, links in pairs(extra) do
				if links[n] then
					list[tag] = links[n]
				end
			end
		end
		return list
	end
	local dist, prev, done = { [S] = 0 }, {}, {}
	while true do
		local u, best = nil, math.huge
		for n, d in pairs(dist) do
			if not done[n] and d < best then
				u, best = n, d
			end
		end
		if not u or u == D then
			break
		end
		done[u] = true
		for v, c in pairs(neighbours(u)) do
			local nd = best + c
			if nd < (dist[v] or math.huge) then
				dist[v] = nd
				prev[v] = u
			end
		end
	end
	if not dist[D] then
		return false, "disconnected"
	end
	local chain = {}
	local n = D
	while n do
		table.insert(chain, 1, n)
		n = prev[n]
	end
	local out = {}
	for _, id in ipairs(chain) do
		local p = (id == S or id == D) and pos[id] or nodes[id]
		local last = out[#out]
		if not last or (Vector2.new(last.X, last.Z) - p).Magnitude > 0.5 then
			table.insert(out, w(p))
		end
	end
	table.insert(out, to3)
	return out
end

return Roads
