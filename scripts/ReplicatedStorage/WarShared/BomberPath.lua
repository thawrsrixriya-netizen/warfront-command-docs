-- ReplicatedStorage.WarShared.BomberPath  (ModuleScript)
local C=require(game.ReplicatedStorage.WarConfig).Bomber
local P={}
function P.duration(pass)
 return ((pass.StartDistance or C.StartDistance)+C.RectLength+C.FlyoutDistance)/(pass.FlightSpeed or C.FlightSpeed)
end
function P.releaseTime(pass,along,index)
 local speed=pass.FlightSpeed or C.FlightSpeed
 local start=pass.StartDistance or C.StartDistance
 if index then return start/speed-C.BombFirstFallDuration+(index-1)*C.BombMinInterval end
 return (start+along)/speed-C.FallDuration
end
function P.position(pass,t)
 local speed=pass.FlightSpeed or C.FlightSpeed
 local start=pass.StartDistance or C.StartDistance
 return Vector3.new(pass.Anchor.X,pass.Altitude,pass.Anchor.Z)+pass.Dir*(math.max(t,0)*speed-start)
end
return P