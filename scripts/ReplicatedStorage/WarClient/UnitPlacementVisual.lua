-- ReplicatedStorage.WarClient.UnitPlacementVisual  (ModuleScript)
local V={}
local function part(model,name,size,cf,color,transparency)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Anchored=true
 p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false
 p.Material=Enum.Material.Neon p.Color=color p.Transparency=transparency or 0 p.Parent=model
 return p
end
function V.resize(model,size)
 local pivot=model:GetPivot()
 model:ClearAllChildren()
 model.WorldPivot=CFrame.identity
 local w,l=size.X,size.Z
 local white=Color3.new(1,1,1)
 part(model,"Footprint",Vector3.new(w,.08,l),CFrame.identity,Color3.fromRGB(120,255,120),.55)
 local t=.10
 for _,x in {-w/2,w/2} do part(model,"Border",Vector3.new(t,.025,l),CFrame.new(x,.055,0),white) end
 for _,z in {-l/2,l/2} do part(model,"Border",Vector3.new(w,.025,t),CFrame.new(0,.055,z),white) end
 local length=math.min(l*.65,math.max(3,w*1.6))
 local width=math.clamp(w*.075,.12,.35)
 local function line(a,b)
  part(model,"Forward",Vector3.new(width,.025,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),white)
 end
 local tip=Vector3.new(0,.075,-length/2)
 line(Vector3.new(0,.075,length/2),tip)
 local wing=math.min(w*.3,length*.3)
 line(tip,tip+Vector3.new(-wing,0,wing))
 line(tip,tip+Vector3.new(wing,0,wing))
 model:PivotTo(pivot)
end
function V.new(name,size,parent)
 local m=Instance.new("Model") m.Name=name V.resize(m,size) m.Parent=parent return m
end
function V.move(model,cf) model:PivotTo(cf) end
return V
