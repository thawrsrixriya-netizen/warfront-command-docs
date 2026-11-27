-- ReplicatedStorage.WarClient.CameraJump  (ModuleScript)
-- CameraJump (client): ask the camera to look at a world point (used by the minimap).
-- TopViewCamera listens: from PERSON it switches to TOP first; TOP/FREE keep their height.
local CameraJump = {}
local event = Instance.new("BindableEvent")
CameraJump.Requested = event.Event

function CameraJump.lookAt(worldPosition)
	event:Fire(worldPosition)
end

return CameraJump
