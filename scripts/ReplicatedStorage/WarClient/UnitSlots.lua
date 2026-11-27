-- ReplicatedStorage.WarClient.UnitSlots  (ModuleScript)
-- UnitSlots (client): registry that links the hotbar slots (1-6) to the scripts that summon units.
-- A summon script registers its slot: { Name, Mode, Call, Count?, BuildIcon? }
--   Mode      = InputMode name while placing (the slot lights up meanwhile)
--   Call      = start placing / summoning (hotbar click or number key)
--   Count     = optional function -> (current, max), shown on the slot
--   BuildIcon = optional function(viewportFrame) that puts a static model in the slot
local UnitSlots = {}

local defs = {}
local changed = Instance.new("BindableEvent")
UnitSlots.Changed = changed.Event

function UnitSlots.register(slot, def)
	defs[slot] = def
	changed:Fire(slot)
end

function UnitSlots.get(slot)
	return defs[slot]
end

return UnitSlots
