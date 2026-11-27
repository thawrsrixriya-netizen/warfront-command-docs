-- StarterPlayer.StarterPlayerScripts.BMPVisionDisplay  (LocalScript)
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS:WaitForChild("VisionConfig"))
local PassengerVision=require(RS.WarShared.BMPPassengerVision)
local U=require(RS.WarShared.WarUtil)
local player=Players.LocalPlayer
local folder=Instance.new("Folder"); folder.Name="BMPVisionDisplay"; folder.Parent=U.folder("ClientFX")
local pool,used={},0
local D=Config.Display
local Behavior=require(RS.BMPBehaviorConfig)
local VisualState=require(RS.WarClient.TankVisualState)
local Projection=require(RS.WarClient.GroundLineProjection)
local params,paramsAt=nil,0
local function castGround(p)
 if not params or os.clock()-paramsAt>1 then params=U.groundParams(); paramsAt=os.clock() end
 local hit=workspace:Raycast(p+Vector3.new(0,15,0),Vector3.new(0,-70,0),params)
 return hit
end
local projection=Projection.new(castGround,.22)
local function ground(p) return projection:Project(p) end
local function line(a,b,color)
 used+=1; local p=pool[used]
 if not p then p=Instance.new("Part"); p.Name="VisionLine"; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Material=Enum.Material.Neon; p.Parent=folder; pool[used]=p end
 local size=Vector3.new(Behavior.LineWidth,.025,math.max((b-a).Magnitude,.01))
 local cf=CFrame.lookAt((a+b)/2,b)
 if (p.Size-size).Magnitude>.0001 then p.Size=size end
 if p.CFrame~=cf then p.CFrame=cf end
 if p.Color~=Color3.new(1,1,1) then p.Color=Color3.new(1,1,1) end
 if p.Transparency~=.35 then p.Transparency=.35 end
end
local function cone(c,yaw,prof)
 local half=math.rad(prof.VisionAngle/2)
 local base=ground(c)
 local left=ground(c+U.dirOf(yaw+half)*prof.VisionRange)
 local right=ground(c+U.dirOf(yaw-half)*prof.VisionRange)
 line(base,left,D.ConeColor); line(base,right,D.ConeColor)
 local prev=left
 for i=1,D.ArcSegments do local p=ground(c+U.dirOf(yaw+half-2*half*i/D.ArcSegments)*prof.VisionRange); line(prev,p,D.ConeColor); prev=p end
end
local tanks=workspace:WaitForChild("CommandTanks")
RunService:BindToRenderStep("BMPVisionDisplay",Enum.RenderPriority.Camera.Value+11,function(dt)
 used=0
 projection:BeginFrame(dt)
 local slots={}
 for n in tostring(player:GetAttribute("BMPVisionSelectedSlots") or ""):gmatch("%d+") do slots[tonumber(n)]=true end
 for _,m in ipairs(tanks:GetChildren()) do
  if m:GetAttribute("OwnerUserId")==player.UserId and slots[m:GetAttribute("TankSlot")] and m:GetAttribute("VisionProfile")=="BMP" then
   local rendered=VisualState.Poses[m]
   local pos=rendered and rendered.Pos or m:GetAttribute("TankPos"); local yaw=rendered and rendered.Yaw or m:GetAttribute("TankYaw") or 0
   local rel=m:GetAttribute("HullCenterRel") or Vector3.zero
   if pos then
    local c=(CFrame.new(pos)*CFrame.Angles(0,yaw,0))*rel
    local prof=Config.Profiles.BMP
    cone(c,yaw,prof)
    for _,side in ipairs(PassengerVision.cones(m,yaw)) do
     cone(c,side.Yaw,{VisionAngle=side.Angle,VisionRange=side.Range})
    end
    cone(c,yaw+(rendered and rendered.Turret or m:GetAttribute("TurretYaw") or 0),prof)
    local prev=ground(c+Vector3.new(prof.WeaponRange,0,0))
    for i=1,D.RingSegments do local a=2*math.pi*i/D.RingSegments; local p=ground(c+Vector3.new(math.cos(a)*prof.WeaponRange,0,math.sin(a)*prof.WeaponRange)); line(prev,p,D.RangeColor); prev=p end
   end
  end
 end
 for i=used+1,#pool do pool[i].Transparency=1 end
end)
