-- ReplicatedStorage.WarShared.BMPPassengerVision  (ModuleScript)
local Profile=require(game.ReplicatedStorage.VisionConfig).Profiles.BMP
local M={}
function M.cones(model,hullYaw)
 local count=model:GetAttribute("PassengerCount") or 0
 if count<=0 then return {} end
 local capacity=math.max(1,model:GetAttribute("PassengerCapacity") or 6)
 local angle=Profile.PassengerSideAngle*math.clamp(count/capacity,0,1)
 return {
  {Yaw=hullYaw+math.pi/2,Range=Profile.PassengerSideRange,Angle=angle},
  {Yaw=hullYaw-math.pi/2,Range=Profile.PassengerSideRange,Angle=angle},
 }
end
return M
