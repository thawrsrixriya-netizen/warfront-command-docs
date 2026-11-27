-- StarterPlayer.StarterPlayerScripts.CombatFXClient  (LocalScript)
-- CombatFXClient: renders server-broadcast combat effects locally on every client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FX = require(ReplicatedStorage:WaitForChild("WarShared"):WaitForChild("FX"))
local CombatFX = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFX")
local TankConfig = require(ReplicatedStorage:WaitForChild("WarConfig")).Tank

local TRACER_COLORS = { FX.Colors.Red, FX.Colors.Yellow, FX.Colors.Orange }

CombatFX.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Explosion" then
		FX.explosion(a, b)
	elseif kind == "Shell" then
		-- a = from, b = to, c = travel time, d = style
		local color = TRACER_COLORS[math.random(1, #TRACER_COLORS)]
		local width = (d == "Heavy" and 0.9) or (d == "Secondary" and 0.6) or 0.3
		local length = (d == "MG") and 8 or 14
		FX.tracer(a, b, color, width, (b - a).Magnitude / math.max(c, 0.01), length)
		FX.muzzleFlash(a, d == "Heavy" and 4 or 2)
	elseif kind == "TankShot" then
		-- Visuals must not depend on audio settings or sound loading.
		-- a = muzzle, b = impact
		FX.muzzleFlash(a, 2.2)
		local travel = FX.tracer(a, b, FX.Colors.Yellow, 0.22, TankConfig.ShellSpeed, 5)
		task.delay(travel, function()
			FX.explosion(b, "TankShell")
		end)
		-- Emit selected smoke at the actual gun attachment; particles drift after the shot.
		if typeof(c)=="Instance" and c:IsDescendantOf(workspace) then
			local muzzle=c:FindFirstChild("CommandMuzzle",true)
			local smoke=muzzle and muzzle:FindFirstChild("BMPMuzzleSmoke")
			if smoke and smoke:IsA("ParticleEmitter") then smoke:Emit(8) end
		end
		local audioOk, audioError = pcall(function()
		-- Sound and projectile start in the same TankShot event, once per fired round.
		local emitter = FX.part({Name="BMPMainGunAudio", Size=Vector3.new(0.1,0.1,0.1), Transparency=1, CFrame=CFrame.new(a)})
		local sound = Instance.new("Sound")
		sound.Name = "BMPMainGun"
		sound.SoundId = TankConfig.MainGunSoundId
		sound.Volume = 0.03
		sound.RollOffMinDistance = 30
		sound.RollOffMaxDistance = 650
		sound.PlaybackRegion = NumberRange.new(TankConfig.MainGunClipStart, TankConfig.MainGunClipEnd)
		sound.PlaybackRegionsEnabled = true
		sound.Parent = emitter
		sound.Ended:Once(function() emitter:Destroy() end)
		sound.TimePosition = TankConfig.MainGunClipStart
		sound:Play()
		game:GetService("Debris"):AddItem(emitter, 12)
		end)
		if not audioOk then warn("[BMP shot audio]", audioError) end
	end
end)
