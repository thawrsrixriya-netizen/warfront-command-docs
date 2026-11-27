-- ReplicatedStorage.WarClient.SkillActions  (ModuleScript)
-- SkillActions (client): registry that links the Skill Shop window to each skill's input script.
-- Each skill script registers { Mode, Call, Hint, Recall?, State? }:
--   Mode   = the InputMode name used while aiming (the shop shows Hint + Cancel during it)
--   Call   = starts aiming (called by the shop's CALL button)
--   Recall = optional, ends an active skill (AC-130)
--   State  = optional function -> "Ready" | "Active" | "Leaving"
local SkillActions = {}

local defs = {}
local changed = Instance.new("BindableEvent")
SkillActions.Changed = changed.Event -- fires (id) when a skill registers or its state changes

function SkillActions.register(id, def)
	defs[id] = def
	changed:Fire(id)
end

function SkillActions.get(id)
	return defs[id]
end

function SkillActions.notify(id)
	changed:Fire(id)
end

function SkillActions.byMode(mode)
	for id, def in pairs(defs) do
		if def.Mode == mode then
			return id, def
		end
	end
	return nil
end

return SkillActions
