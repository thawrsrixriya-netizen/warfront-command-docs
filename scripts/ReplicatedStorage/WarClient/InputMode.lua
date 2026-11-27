-- ReplicatedStorage.WarClient.InputMode  (ModuleScript)
-- InputMode (client): one exclusive gameplay input mode at a time.
-- Modes: nil (normal), "BomberAim", "TankPlace", "TankControl", "FPVAim".
-- Entering a mode runs the previous mode's cleanup so stale markers/previews are cleared.
local UserInputService = game:GetService("UserInputService")

local InputMode = {}

local current = nil
local cleanup = nil
local blockedUntil = 0
local changed = Instance.new("BindableEvent")
InputMode.Changed = changed.Event

function InputMode.get()
	return current
end

function InputMode.exit(name)
	if current == nil or (name and current ~= name) then
		return
	end
	local fn = cleanup
	current, cleanup = nil, nil
	if fn then
		local ok, err = pcall(fn)
		if not ok then
			warn("[InputMode] cleanup error:", err)
		end
	end
	changed:Fire(nil)
end

function InputMode.enter(name, onExit)
	if current == name then
		return
	end
	InputMode.exit()
	current, cleanup = name, onExit
	changed:Fire(name)
end

-- Consume the rest of the current click so other listeners don't act on it.
function InputMode.blockClicks(seconds)
	blockedUntil = math.max(blockedUntil, os.clock() + seconds)
end

function InputMode.clicksBlocked()
	return os.clock() < blockedUntil
end

function InputMode.isTyping()
	return UserInputService:GetFocusedTextBox() ~= nil
end

-- Default world click (e.g. calling the AC-130) is only allowed in normal mode.
function InputMode.canUseWorldClick()
	return current == nil and not InputMode.clicksBlocked()
end

return InputMode
