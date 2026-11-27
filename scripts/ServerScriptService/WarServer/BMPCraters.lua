-- ServerScriptService.WarServer.BMPCraters  (ModuleScript)
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local U = require(game.ReplicatedStorage.WarShared.WarUtil)
local templates = ServerStorage:WaitForChild("BMPCraterTemplates"):GetChildren()
local M = {}
local entries = {}
local lifetime, fadeTime, maxMarks = 180, 10, 120
function M.create(point)
 local folder=U.folder("BMPImpactCraters",U.folder("WarFX"))
 local hit=workspace:Raycast(point+Vector3.new(0,2,0),Vector3.new(0,-5,0),U.groundParams())
 if not hit or hit.Normal.Y < 0.55 or (hit.Position-point).Magnitude>3 then return end
 for i=#entries,1,-1 do if not entries[i].Parent then table.remove(entries,i) elseif (entries[i].Position-hit.Position).Magnitude<1 then return entries[i] end end
 while #entries>=maxMarks do table.remove(entries,1):Destroy() end
 local mark=templates[math.random(1,#templates)]:Clone()
 mark.Name="BMPShellCrater"
 local n=hit.Normal
 local tangent=math.abs(n:Dot(Vector3.xAxis))<.9 and n:Cross(Vector3.xAxis).Unit or n:Cross(Vector3.zAxis).Unit
 -- Both chosen decals face Bottom: point local -Y out of the surface.
 local up=-n
 mark.CFrame=CFrame.fromMatrix(hit.Position+n*.025,tangent,up,tangent:Cross(up))*CFrame.Angles(0,math.random()*math.pi*2,0)
 local tint=hit.Instance:IsA("Terrain") and workspace.Terrain:GetMaterialColor(hit.Material) or hit.Instance.Color
 mark.Color=tint
 for _,d in ipairs(mark:GetDescendants()) do if d:IsA("Decal") or d:IsA("Texture") then d.Color3=tint; d.Transparency=0 end end
 mark.Parent=folder
 table.insert(entries,mark)
 task.delay(lifetime-fadeTime,function()
  if not mark.Parent then return end
  for _,d in ipairs(mark:GetDescendants()) do if d:IsA("Decal") or d:IsA("Texture") then TweenService:Create(d,TweenInfo.new(fadeTime),{Transparency=1}):Play() end end
 end)
 task.delay(lifetime,function() mark:Destroy() end)
 return mark
end
return M
