-- ServerScriptService.WarServer.Damage  (ModuleScript)
-- Damage (server only): every weapon deals damage through here.
-- Only registered, living enemies can be damaged (never players or friendly NPCs).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
assert(RunService:IsServer(), "Damage module is server-only")

local Registry = require(ReplicatedStorage:WaitForChild("WarShared"):WaitForChild("EnemyRegistry"))

local Damage = {}

local dealt = Instance.new("BindableEvent")
-- Fires (model, amount, source) after damage is applied; useful for logs/tests.
Damage.Dealt = dealt.Event
local killed = Instance.new("BindableEvent")
-- Fires (model, source, attacker) when this damage kills an enemy; attacker = Player or nil.
Damage.Killed = killed.Event

function Damage.apply(model, amount, source, attacker)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	if not Registry.isEnemyModel(model) then
		return 0
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return 0
	end
	local before = humanoid.Health
	humanoid:TakeDamage(amount)
	local applied = before - humanoid.Health
	if applied > 0 then
		dealt:Fire(model, applied, source, attacker)
		if humanoid.Health <= 0 then
			killed:Fire(model, source, attacker)
		end
	end
	return applied
end

-- Area damage. opts:
--   Mode   = "XZ" (default) | "3D"
--   Amount = number (flat) OR Falloff = function(distance, radius) -> amount
--   Source = string (e.g. "Bomber", "AC130Heavy")
--   Player = the attacking Player (optional, gets the kill money)
-- Each enemy is damaged at most once per call. Returns array of { Model, Distance, Applied }.
function Damage.radial(center, radius, opts)
	local hits = {}
	for _, e in ipairs(Registry.inRadius(center, radius, opts.Mode or "XZ")) do
		local amount = opts.Falloff and opts.Falloff(e.Distance, radius) or opts.Amount
		local applied = Damage.apply(e.Model, amount, opts.Source, opts.Player)
		table.insert(hits, { Model = e.Model, Distance = e.Distance, Applied = applied })
	end
	return hits
end

-- Linear falloff used by the bomber: max * (1 - d / r), clamped to [0, max].
function Damage.linearFalloff(maxDamage)
	return function(distance, radius)
		return math.clamp(maxDamage * (1 - distance / radius), 0, maxDamage)
	end
end

return Damage
