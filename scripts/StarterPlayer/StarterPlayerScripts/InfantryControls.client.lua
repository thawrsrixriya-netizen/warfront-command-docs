-- StarterPlayer.StarterPlayerScripts.InfantryControls  (LocalScript)
-- Infantry UI shares InputMode/Aim with tank controls.
local Players=game:GetService("Players")
local RS=game.ReplicatedStorage
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local C=require(RS:WaitForChild("InfantryConfig"))
local TankLabels=require(RS:WaitForChild("WarConfig")).Tank
local InputMode=require(RS.WarClient.InputMode)
local Aim=require(RS.WarClient.Aim)
local Selection=require(RS.WarClient.UnitSelection)
local Watch=require(RS.WarClient.UnitWatchPreview)
local watchPreview
-- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
local EnemyRegistry=require(RS.WarShared.EnemyRegistry)
local function enemyFromHit(result)
 local v=result and result.Instance
 while v and v~=workspace do
  if v:IsA("Model") and EnemyRegistry.isEnemyModel(v) then return v end
  v=v.Parent
 end
end
-- Fire click that missed the enemy model slightly: snap to the nearest enemy within 12 studs of the click
local function enemyNear(p)
 if not p then return nil end
 local best,bd=nil,12
 for _,e in EnemyRegistry.all(false) do
  local d=(Vector3.new(e.Position.X,0,e.Position.Z)-Vector3.new(p.X,0,p.Z)).Magnitude
  if d<bd then best,bd=e.Model,d end
 end
 return best
end
-- [SHARED:Vision] END
local Remote=RS.Remotes:WaitForChild("InfantryCommand")
local Transport=RS.Remotes:WaitForChild("InfantryTransport")
local folder=workspace:WaitForChild("CommandInfantry")
local template=RS:WaitForChild("InfantryPlacementVisual")
local PLACE,CONTROL="InfantryPlace","InfantryControl"
local selected={} local action local preview local yaw=0
local formation="Dispersed"
local refreshFormation
local gui=Instance.new("ScreenGui") gui.Name="InfantryUI" gui.ResetOnSpawn=false gui.Parent=player:WaitForChild("PlayerGui")
local function round(p,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 6) c.Parent=p end
local function button(text,p,size)
 local b=Instance.new("TextButton") b.Name=text b.Text=text b.Size=size or UDim2.fromOffset(44,36)
 b.BackgroundColor3=Color3.fromRGB(35,38,34) b.BackgroundTransparency=0.15 b.TextColor3=Color3.new(1,1,1)
 b.Font=Enum.Font.GothamBold b.TextSize=16 b.Parent=p round(b) return b
end
local bottom=Instance.new("Frame") bottom.Name="Bottom" bottom.AnchorPoint=Vector2.new(0.5,1)
-- MatchHUD: summoning moved to the hotbar (slot 2 / key 2); the old icon and I1-I3 buttons are hidden
-- and this frame is shifted so the command menu sits centred just above the hotbar.
bottom.Position=UDim2.new(0.5,-56,1,-100) bottom.Size=UDim2.fromOffset(420,120) bottom.BackgroundTransparency=1 bottom.Parent=gui
local icon=Instance.new("Frame") icon.Name="InfantryIcon" icon.Size=UDim2.fromOffset(104,104)
icon.BackgroundColor3=Color3.fromRGB(28,31,27) icon.BackgroundTransparency=0.2 icon.Parent=bottom round(icon,10)
icon.Visible=false
local viewport=Instance.new("ViewportFrame") viewport.Size=UDim2.fromScale(1,1) viewport.BackgroundTransparency=1 viewport.Parent=icon
viewport.Ambient=Color3.fromRGB(180,180,180) viewport.LightColor=Color3.new(1,1,1)
local camera=Instance.new("Camera") camera.FieldOfView=40 camera.Parent=viewport viewport.CurrentCamera=camera
local world=Instance.new("WorldModel") world.Parent=viewport
local figure=template:Clone()
local IconAnimation=require(RS:WaitForChild("InfantryAnimation"))
local IconRifle=require(RS:WaitForChild("InfantryRiflePose"))
local iconState=IconAnimation.bind(figure)
local iconMotors,iconWelds={},{}
for _,v in figure:GetDescendants() do
 if v:IsA("Motor6D") then table.insert(iconMotors,v)
 elseif v:IsA("WeldConstraint") and v.Part0 and v.Part1 then
  table.insert(iconWelds,{Joint=v,Relative=v.Part0.CFrame:ToObjectSpace(v.Part1.CFrame)})
 end
end
local function solveIconMotors()
 for pass=1,3 do for _,j in iconMotors do if j.Part0 and j.Part1 then j.Part1.CFrame=j.Part0.CFrame*j.C0*j.C1:Inverse() end end end
end
local function poseIcon(dt)
 IconAnimation.step(iconState,dt,false,false,0)
 solveIconMotors()
 IconRifle.apply(figure,iconState,dt)
 solveIconMotors()
 for pass=1,3 do for _,w in iconWelds do local j=w.Joint j.Part1.CFrame=j.Part0.CFrame*w.Relative end end
end
for _,d in figure:GetDescendants() do if d:IsA("BasePart") then d.Anchored=true d.CanCollide=false end end
figure.Parent=world
poseIcon(0.1)
local bb,size=figure:GetBoundingBox()
local offset=figure:GetPivot():ToObjectSpace(bb).Position
local radius=math.max(size.X,size.Y,size.Z)
camera.CFrame=CFrame.lookAt(Vector3.new(0,radius*0.2,radius*1.65),Vector3.zero)
local placeButton=button("",icon,UDim2.fromScale(1,1)) placeButton.Name="PlaceButton" placeButton.BackgroundTransparency=1
local count=Instance.new("TextLabel") count.Name="Count" count.AnchorPoint=Vector2.new(0.5,1)
count.Position=UDim2.new(0.5,0,1,-2) count.Size=UDim2.new(1,0,0,18) count.BackgroundTransparency=1
count.Font=Enum.Font.GothamBold count.TextSize=14 count.TextColor3=Color3.new(1,1,1) count.TextStrokeTransparency=0.4 count.Parent=icon
local title=Instance.new("TextLabel") title.Text="INFANTRY x6" title.Font=Enum.Font.GothamBold title.TextSize=11
title.TextColor3=Color3.fromRGB(220,230,210) title.BackgroundTransparency=1 title.Size=UDim2.new(1,0,0,16) title.Parent=icon
local right=Instance.new("Frame") right.Position=UDim2.fromOffset(116,8) right.Size=UDim2.fromOffset(300,96) right.BackgroundTransparency=1 right.Parent=bottom
local slots={}
for i=1,C.MaxPerPlayer do local b=button("I"..i,right) b.Name="Slot"..i b.Visible=false b.Position=UDim2.fromOffset((i-1)*50,0) slots[i]=b end
local menu=Instance.new("Frame") menu.Name="Menu" menu.Position=UDim2.fromOffset(0,46)
menu.Size=UDim2.fromOffset(300,40) menu.BackgroundTransparency=1 menu.Visible=false menu.Parent=right
local move=button("Move",menu,UDim2.fromOffset(54,36))
local fire=button("Fire",menu,UDim2.fromOffset(54,36)) fire.Position=UDim2.fromOffset(60,0)
local prone=button("Prone",menu,UDim2.fromOffset(54,36)) prone.Position=UDim2.fromOffset(120,0)
local stop=button("Stop",menu,UDim2.fromOffset(54,36)) stop.Position=UDim2.fromOffset(180,0)
for i,b in ipairs({move,fire,prone,stop}) do b.TextSize=12 b.Size=UDim2.fromOffset(69,36) b.Position=UDim2.fromOffset((i-1)*75,0) end
move.Text="Z  Move" fire.Text="F  Fire" prone.Text="T  Crouch" stop.Text="X  Stop"
local ammo=Instance.new("TextLabel") ammo.Name="Ammo" ammo.Position=UDim2.fromOffset(154,0) ammo.Size=UDim2.fromOffset(142,36) ammo.BackgroundTransparency=1 ammo.TextColor3=Color3.fromRGB(230,220,170) ammo.Font=Enum.Font.GothamBold ammo.TextSize=13 ammo.Text="" ammo.Parent=right
local hint=Instance.new("TextLabel") hint.Name="Hint" hint.AnchorPoint=Vector2.new(0.5,1)
hint.Position=UDim2.new(0.5,0,1,-402) hint.Size=UDim2.fromOffset(520,28) hint.BackgroundColor3=Color3.fromRGB(20,20,20)
hint.BackgroundTransparency=0.3 hint.Font=Enum.Font.GothamBold hint.TextSize=14 hint.TextColor3=Color3.fromRGB(255,210,140)
hint.Visible=false hint.Parent=gui round(hint)
local messageToken=0
local function message(text,seconds)
 messageToken+=1 local token=messageToken hint.Text=text hint.Visible=InputMode.get()~=PLACE
 if seconds then task.delay(seconds,function() if messageToken==token then hint.Visible=false end end) end
end
local function own()
 local out={}
 for _,m in folder:GetChildren() do if m:GetAttribute("OwnerUserId")==player.UserId then
 local h=m:FindFirstChildOfClass("Humanoid") local slot=m:GetAttribute("InfantrySlot")
 if h and h.Health>0 and slot and (not out[slot] or (m:GetAttribute("SquadIndex") or 1)<(out[slot]:GetAttribute("SquadIndex") or 1)) then out[slot]=m end end end
 return out
end
local boardOutline=Instance.new("Highlight")
boardOutline.Name="BoardHoverOutline" boardOutline.FillTransparency=1
boardOutline.OutlineColor=Color3.new(1,1,1) boardOutline.OutlineTransparency=0
boardOutline.DepthMode=Enum.HighlightDepthMode.Occluded boardOutline.Enabled=false
boardOutline.Parent=workspace.CurrentCamera
local trenchPreview
local TrenchRoutes=require(RS.WarShared.TrenchRoutes)
local insideCacheTime,insideCacheKey,insideCacheValue=0,nil,false
local function selectedInTrench()
 local key=player:GetAttribute("InfantrySelectedSlots")
 if os.clock()<insideCacheTime and key==insideCacheKey then return insideCacheValue end
 insideCacheTime=os.clock()+.15 insideCacheKey=key insideCacheValue=false
 local slots={}
 for _,m in selected do if m.Parent then slots[m:GetAttribute("InfantrySlot")]=true end end
 for _,m in folder:GetChildren() do if m:GetAttribute("OwnerUserId")==player.UserId and slots[m:GetAttribute("InfantrySlot")] and not m:GetAttribute("Embarked") then
  local root=m:FindFirstChild("HumanoidRootPart")
  if m:GetAttribute("InTrenchCover") or m:GetAttribute("TrenchPhase")=="Inside" or root and TrenchRoutes.bodyInside(root.Position) then insideCacheValue=true break end
 end end
 return insideCacheValue
end
local function clearPreview()
 trenchPreview=nil
 watchPreview=nil
 if preview then preview:Destroy() preview=nil end
 boardOutline.Enabled=false boardOutline.Adornee=nil
end
local function cleanup()
 clearPreview() selected={} action=nil menu.Visible=false hint.Visible=false
 player:SetAttribute("InfantryControlActive",false)
 -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 player:SetAttribute("InfantrySelectedSlots",nil)
 -- [SHARED:Vision] END
end
local function selectUnits(list)
 local squads=own() local normalized={} local seen={}
 for _,m in list do local slot=m:GetAttribute("InfantrySlot") if slot and squads[slot] and not seen[slot] then seen[slot]=true table.insert(normalized,squads[slot]) end end
 list=normalized
 if list[1] then formation=list[1]:GetAttribute("SquadFormation") or "Dispersed" if refreshFormation then refreshFormation() end end
 InputMode.enter(CONTROL,cleanup) clearPreview() selected=list action=nil menu.Visible=true
 player:SetAttribute("InfantryControlActive",true)
 -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 local slots={} for _,m in list do table.insert(slots,tostring(m:GetAttribute("InfantrySlot"))) end
 player:SetAttribute("InfantrySelectedSlots",table.concat(slots,","))
 -- [SHARED:Vision] END
end
local function fromHit(result)
 local v=result and result.Instance
 while v and v~=workspace do
  if v:GetAttribute("CommandInfantry") then return v:GetAttribute("OwnerUserId")==player.UserId and v or nil end
  v=v.Parent
 end
end
local function makeMarker(placement)
 clearPreview()
 if placement then preview=require(RS.WarClient.UnitPlacementVisual).new("InfantryPreview",Vector3.new(C.SquadSpreadRadius*2+1.8,.08,C.SquadSpreadRadius*2+1.5),workspace.CurrentCamera) return end
 local p=Instance.new("Part") p.Name="InfantryPreview" p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
 p.Size=Vector3.new(placement and (C.SquadSpreadRadius*2+1.8) or 1.2,0.08,placement and (C.SquadSpreadRadius*2+1.5) or 1.2)
 p.Material=Enum.Material.Neon p.Color=placement and Color3.fromRGB(120,255,120) or Color3.fromRGB(90,200,255)
 p.Transparency=0.5 p.Parent=workspace.CurrentCamera preview=p
end
local formationButton=button("Q  Formation: Dispersed",gui,UDim2.fromOffset(260,26))
formationButton.Name="FormationButton" formationButton.AnchorPoint=Vector2.new(.5,1)
formationButton.Parent=right
formationButton.AnchorPoint=Vector2.new(0,0)
formationButton.Parent=menu
formationButton.Position=UDim2.fromOffset(96,40) formationButton.Size=UDim2.fromOffset(90,24) formationButton.TextSize=13
local boardButton=button("Board",menu,UDim2.fromOffset(102,24)) boardButton.Text="G  Enter" boardButton.Name="Board" boardButton.Position=UDim2.fromOffset(192,40) boardButton.TextSize=13
local function beginBoard()
 InputMode.blockClicks(.25)
 if action=="Board" then action=nil clearPreview() hint.Visible=false return end
 clearPreview() action="Board"
 trenchPreview=require(RS.WarClient.TrenchCoverPreview).new() preview=trenchPreview.Model
 message(selectedInTrench() and "Click ground outside the trench to leave | BMP to board | G / X cancel" or "Click your BMP to board, or a white trench route to take cover | G / X cancel")
end
boardButton.Activated:Connect(beginBoard)
local escortButton=Instance.new("TextButton")
escortButton.Name="Escort" escortButton.Text="Escort BMP" escortButton.LayoutOrder=80 escortButton.Parent=menu
escortButton.Activated:Connect(function()
 InputMode.blockClicks(.25)
 clearPreview()
 if action=="Escort" then action=nil hint.Visible=false return end
 action="Escort" message("Click your BMP to escort | X cancel")
end)

local formationPanel=Instance.new("Frame") formationPanel.Name="FormationPanel"
formationPanel.AnchorPoint=Vector2.new(.5,1) formationPanel.Position=UDim2.new(.5,0,1,-298)
formationPanel.Size=UDim2.fromOffset(420,94) formationPanel.BackgroundColor3=Color3.fromRGB(28,31,27)
formationPanel.Visible=false formationPanel.Parent=gui round(formationPanel,8)
local choices={}
for index,kind in {"Line","Dispersed"} do
 local b=button(index==1 and "1   LINE" or "2   DISPERSED",formationPanel,UDim2.fromOffset(198,82))
 b.Name=kind b.Position=UDim2.fromOffset(8+(index-1)*206,6) b.TextYAlignment=Enum.TextYAlignment.Bottom b.TextSize=14
 choices[kind]=b
 local points=kind=="Line" and {{.15,.30},{.29,.36},{.43,.27},{.57,.35},{.71,.29},{.85,.34}}
  or {{.18,.17},{.52,.12},{.83,.27},{.32,.48},{.65,.42},{.87,.53}}
 for _,p in points do
  local dot=Instance.new("Frame") dot.Size=UDim2.fromOffset(7,7) dot.AnchorPoint=Vector2.new(.5,.5)
  dot.Position=UDim2.fromScale(p[1],p[2]) dot.BackgroundColor3=Color3.fromRGB(200,220,180) dot.BorderSizePixel=0 dot.Parent=b round(dot,4)
 end
end
local function resizeFormationPreview()
 if preview and (InputMode.get()==PLACE or (InputMode.get()==CONTROL and action=="Formation")) then
  local size=formation=="Line" and Vector3.new((C.SquadSize-1)*C.LineSpacing+2.4,.08,3.9)
   or Vector3.new(C.SquadSpreadRadius*2+1.8,.08,C.SquadSpreadRadius*2+1.5)
  if preview:IsA("Model") then require(RS.WarClient.UnitPlacementVisual).resize(preview,size) else preview.Size=size end
 end
end
refreshFormation=function()
 formationButton.Text="Q  "..(formation=="Line" and "1 - Line" or "2 - Dispersed")
 for kind,b in choices do b.BackgroundColor3=kind==formation and Color3.fromRGB(105,112,65) or Color3.fromRGB(35,38,34) end
end
local function chooseFormation(kind)
 formation=kind formationPanel.Visible=false InputMode.blockClicks(.25)
 if InputMode.get()==CONTROL then
  action=nil clearPreview()
  for _,m in selected do if m.Parent then
   local center=Vector3.zero local count=0
   for _,unit in folder:GetChildren() do
    if unit:GetAttribute("OwnerUserId")==player.UserId and unit:GetAttribute("InfantrySlot")==m:GetAttribute("InfantrySlot") then
     local h=unit:FindFirstChildOfClass("Humanoid") local root=unit:FindFirstChild("HumanoidRootPart")
     if h and h.Health>0 and root then center+=root.Position count+=1 end
    end
   end
   if count>0 then Remote:FireServer(kind=="Line" and "FormationLine" or "FormationDispersed",center/count,nil,m) end
  end end
 end
 refreshFormation() resizeFormationPreview()
end
for _,b in choices do b.Active=false b.AutoButtonColor=false end
local formationDisplayToken=0
local function toggleFormation()
 local mode=InputMode.get()
 if mode~=nil and mode~=PLACE and mode~=CONTROL then return end
 chooseFormation(formation=="Line" and "Dispersed" or "Line")
 hint.Visible=false formationPanel.Visible=false
end
formationButton.Activated:Connect(toggleFormation)
refreshFormation()

local function startPlacement()
 InputMode.blockClicks(0.25)
 if InputMode.get()==PLACE then InputMode.exit(PLACE) return end
 local n=0 for _ in own() do n+=1 end
 if n>=C.MaxPerPlayer then message("Squad limit reached (3/3)",3) return end
 InputMode.enter(PLACE,cleanup) player:SetAttribute("InfantryControlActive",true)
 selected={} menu.Visible=false action=nil
 local look=workspace.CurrentCamera.CFrame.LookVector yaw=math.atan2(-look.X,-look.Z)
 makeMarker(true) resizeFormationPreview() message("Click to deploy 6 soldiers  |  Q formations / E rotate  |  X cancel")
end
placeButton.Activated:Connect(startPlacement)
-- [SHARED:UnitSlots] BEGIN  (owner's hotbar bridge, see doc "To ChatGPT" rule 2.4; do not change or remove)
require(RS.WarClient:WaitForChild("UnitSlots")).register(2,{
 Name="INFANTRY",
 Economy="Infantry", -- EconomyConfig.Units key (cost / cooldown)
 Mode=PLACE,
 Call=startPlacement,
 Count=function() local n=0 for _ in own() do n+=1 end return n,C.MaxPerPlayer end,
 BuildIcon=function(vp) -- still copy of the posed icon soldier
  local cam=Instance.new("Camera") cam.FieldOfView=40 cam.Parent=vp vp.CurrentCamera=cam
  local wm=Instance.new("WorldModel") wm.Parent=vp
  local f=figure:Clone() f:PivotTo(CFrame.Angles(0,math.rad(-25),0)*CFrame.new(-offset)) f.Parent=wm
  cam.CFrame=CFrame.lookAt(Vector3.new(0,radius*0.15,radius*1.45),Vector3.zero)
  return true
 end,
})
-- [SHARED:UnitSlots] END
for i,b in slots do b.Activated:Connect(function() InputMode.blockClicks(0.25) local m=own()[i] if m then selectUnits({m}) end end) end
local watchButton=button("C  Watch",menu,UDim2.fromOffset(102,24))
watchButton.Name="Watch" watchButton.Position=UDim2.fromOffset(0,40) watchButton.Size=UDim2.fromOffset(90,24) watchButton.TextSize=13
local function toggleWatch()
 InputMode.blockClicks(.25)
 if action=="Watch" or Watch.active(selected) then
  Watch.cancel(selected,"Infantry") action=nil clearPreview() hint.Visible=false return
 end
 clearPreview() action="Watch"
 watchPreview=Watch.new(selected,"Infantry") preview=watchPreview.Model
 message("Point toward the direction to watch | Click confirm | C cancel")
end
watchButton.Activated:Connect(toggleWatch)
local function beginMove()
 InputMode.blockClicks(.25) action="Move" makeMarker(false) message("Click destination  |  X cancel")
end
local function beginFire()
 InputMode.blockClicks(.25) action="Fire" makeMarker(false) preview.Color=Color3.fromRGB(255,110,65)
 message("Click an enemy or ground to fire  |  X cancel")
end
local function toggleProne()
 InputMode.blockClicks(.25)
 for _,m in selected do if m.Parent then Remote:FireServer("Prone",Vector3.zero,nil,m) end end
end
local function stopUnits()
 InputMode.blockClicks(.25)
 for _,m in selected do if m.Parent then Remote:FireServer("Stop",Vector3.zero,nil,m) end end
 action=nil clearPreview() hint.Visible=false
end
move.Activated:Connect(beginMove)
fire.Activated:Connect(beginFire)
prone.Activated:Connect(toggleProne)
stop.Activated:Connect(stopUnits)
-- Selection-only virtual hit boxes; they never block bullets, sight or movement.
local function selectionHit(result)
 local direct=fromHit(result)
 if direct then return direct end
 local ray=Aim.mouseRay()
 local best,bestT=nil,math.huge
 local surfaceT=result and (result.Position-ray.Origin).Magnitude or 5000
 for _,m in ipairs(folder:GetChildren()) do
  local root=m:FindFirstChild("HumanoidRootPart")
  local h=m:FindFirstChildOfClass("Humanoid")
  if root and h and h.Health>0 and m:GetAttribute("OwnerUserId")==player.UserId and not m:GetAttribute("Embarked") then
   local cf=CFrame.new(root.Position)
   local origin=cf:PointToObjectSpace(ray.Origin)
   local direction=cf:VectorToObjectSpace(ray.Direction)
   local near,far=0,5000
   local valid=true
   for _,axis in ipairs({"X","Y","Z"}) do
    local half=axis=="Y" and 2.5 or 2.5
    local o,d=origin[axis],direction[axis]
    if math.abs(d)<1e-7 then
     if math.abs(o)>half then valid=false break end
    else
     local t1,t2=(-half-o)/d,(half-o)/d
     if t1>t2 then t1,t2=t2,t1 end
     near=math.max(near,t1) far=math.min(far,t2)
     if near>far then valid=false break end
    end
   end
   if valid and near<=surfaceT+.05 and near<bestT then best,bestT=m,near end
  end
 end
 return best
end
Selection.register("Infantry",{
 Mode=CONTROL,Action=function() return action end,Select=selectUnits,
 Close=function() InputMode.exit(CONTROL) end,
 Units=function()
  local list={}
  for _,m in ipairs(folder:GetChildren()) do
   local h=m:FindFirstChildOfClass("Humanoid")
   if h and h.Health>0 and m:GetAttribute("OwnerUserId")==player.UserId and not m:GetAttribute("Embarked") then table.insert(list,m) end
  end
  return list
 end,
 Key=function(m) return m:GetAttribute("InfantrySlot") end,
 Position=function(m) return m.HumanoidRootPart.Position end,
 Hit=selectionHit,
 OtherClick=function(result)
  local enemy=enemyFromHit(result)
  if not enemy then return false end
  for _,m in ipairs(selected) do if m.Parent then Remote:FireServer("FireUnit",enemy,nil,m) end end
  message("Attack: "..enemy.Name,2)
  return true
 end,
})
local infantrySlot=require(RS.WarClient.UnitSlots).get(2)
infantrySlot.Hint=nil
infantrySlot.CancelKey="X"

UIS.InputBegan:Connect(function(input,processed)
 if InputMode.isTyping() or (processed and input.KeyCode~=Enum.KeyCode.Escape) then return end
 local mode=InputMode.get()
 if mode==PLACE and input.KeyCode==Enum.KeyCode.X then InputMode.blockClicks(.25) InputMode.exit(PLACE) return end
 if mode==CONTROL and selected[1] then
  if input.KeyCode==Enum.KeyCode.C then toggleWatch() return
  elseif input.KeyCode==Enum.KeyCode.Z then beginMove() return
  elseif input.KeyCode==Enum.KeyCode.F then beginFire() return
  elseif input.KeyCode==Enum.KeyCode.T then toggleProne() return
  elseif input.KeyCode==Enum.KeyCode.X then stopUnits() return
  elseif input.KeyCode==Enum.KeyCode.G and boardButton.Visible then beginBoard() return end
 end
 if input.KeyCode==Enum.KeyCode.Q then toggleFormation() return end
 if input.KeyCode==Enum.KeyCode.Escape and (mode==PLACE or mode==CONTROL) then
  InputMode.blockClicks(0.25)
  if action then action=nil clearPreview() hint.Visible=false else InputMode.exit(mode) end return
 end
 if input.UserInputType~=Enum.UserInputType.MouseButton1 or InputMode.clicksBlocked() then return end
 if mode and mode~=PLACE and mode~=CONTROL then return end
 if mode~=PLACE and action==nil then return end -- shared drag/click selection decides on release
 local hit,result=Aim.groundHit()
 if mode==PLACE then
  InputMode.blockClicks(0.3)
  if hit then Remote:FireServer("Spawn",hit,yaw,formation) InputMode.exit(PLACE) end
 elseif mode==CONTROL and action=="Watch" and watchPreview then
  InputMode.blockClicks(.3) watchPreview:Confirm() action=nil clearPreview() hint.Visible=false
 elseif mode==CONTROL and (action=="Board" or action=="Escort") then
  InputMode.blockClicks(.3)
  local tank=result and result.Instance
  while tank and tank~=workspace and not tank:GetAttribute("CommandTank") do tank=tank.Parent end
  if tank and tank~=workspace and tank:GetAttribute("OwnerUserId")==player.UserId then
   for _,m in selected do if m.Parent then Transport:FireServer(action=="Escort" and "Escort" or "Board",m,tank) end end
   action=nil clearPreview() hint.Visible=false
  else
   if action=="Escort" then message("Choose your own BMP",2) return end
   if trenchPreview then trenchPreview:Update(hit) end
   if hit and selectedInTrench() and not TrenchRoutes.groundInside(hit) then
    for _,m in selected do if m.Parent then Remote:FireServer("ExitTrench",hit,nil,m) end end
    insideCacheTime=0 action=nil clearPreview() hint.Visible=false
   elseif trenchPreview and trenchPreview.Point then
    for _,m in selected do if m.Parent then Remote:FireServer("Trench",trenchPreview.Point,nil,m) end end
    action=nil clearPreview() hint.Visible=false
   else message("Choose your BMP or point at a trench until its white route appears",2) end
  end
 elseif mode==CONTROL and action=="Formation" and hit then
  InputMode.blockClicks(.3)
  for _,m in selected do if m.Parent then Remote:FireServer(formation=="Line" and "FormationLine" or "FormationDispersed",hit,yaw,m) end end
  action=nil clearPreview() hint.Visible=false
 -- [SHARED:Vision] BEGIN  (owner's vision/auto-fire system, see doc "To ChatGPT" rule 2.4; do not change or remove)
 elseif mode==CONTROL and selected[1] and ((action==nil or action=="Move") and enemyFromHit(result) or action=="Fire" and (enemyFromHit(result) or enemyNear(hit))) then
  -- clicking an enemy = attack that enemy (soldiers keep moving and shoot when it is seen);
  -- when it dies they go back to automatic fire
  InputMode.blockClicks(0.3)
  local enemy=enemyFromHit(result) or enemyNear(hit)
  for _,m in selected do if m.Parent then Remote:FireServer("FireUnit",enemy,nil,m) end end
  message("Attack: "..enemy.Name,2)
  if action then action=nil clearPreview() hint.Visible=false end
 -- [SHARED:Vision] END
 elseif mode==CONTROL and action=="Fire" and hit then
  InputMode.blockClicks(0.3)
  for _,m in selected do if m.Parent then Remote:FireServer("Fire",hit,nil,m) end end
  action=nil clearPreview() hint.Visible=false
 elseif mode==CONTROL and action=="Move" and hit then
  InputMode.blockClicks(0.3)
  local center=Vector3.zero local n=0
  for _,m in selected do if m.Parent then center+=m:GetPivot().Position n+=1 end end
  if n>0 then center/=n end
  for _,m in selected do if m.Parent then
   local offset=m:GetPivot().Position-center
   Remote:FireServer("Move",hit+Vector3.new(offset.X,0,offset.Z),nil,m)
  end end
  action=nil clearPreview() hint.Visible=false
 else
  local m=selectionHit(result)
  if m then InputMode.blockClicks(.3) selectUnits({m})
  elseif mode==CONTROL then InputMode.blockClicks(.2) InputMode.exit(CONTROL) end
 end
end)
Remote.OnClientEvent:Connect(function(kind,a) if kind=="Message" then message(a,3) end end)
local labels={} local spin=0 local elapsed=0
local labelGui=Instance.new("ScreenGui") labelGui.Name="InfantryLabels" labelGui.ResetOnSpawn=false labelGui.IgnoreGuiInset=true labelGui.Parent=player.PlayerGui
local function squadCenter(slot,fallback)
 local center=Vector3.zero local n=0
 for _,m in folder:GetChildren() do
  if m:GetAttribute("OwnerUserId")==player.UserId and m:GetAttribute("InfantrySlot")==slot then
   local h=m:FindFirstChildOfClass("Humanoid") local root=m:FindFirstChild("HumanoidRootPart")
   if h and h.Health>0 and root then center+=root.Position n+=1 end
  end
 end
 return n>0 and center/n or fallback:GetPivot().Position
end
local function updateLabels()
 local cam=workspace.CurrentCamera
 local projection=cam.ViewportSize.Y/(2*math.tan(math.rad(cam.FieldOfView)/2))
 local owned=own() local alive={}
 for slot,model in owned do
  alive[model]=true
  local label=labels[model]
  if not label then
   label=Instance.new("TextLabel") label.Name="InfantryLabel"..slot
   label.AnchorPoint=Vector2.new(.5,.5) label.BackgroundTransparency=.25
   label.Font=Enum.Font.GothamBlack label.Text="I"..slot label.Parent=labelGui round(label,4)
   labels[model]=label
  end
  local root=model:FindFirstChild("HumanoidRootPart")
  local sp,onScreen=cam:WorldToViewportPoint(squadCenter(slot,model)+Vector3.new(0,TankLabels.LabelOffsetY,0))
  label.Visible=onScreen and sp.Z>0 and sp.Z<=TankLabels.LabelMaxDistance and not model:GetAttribute("Embarked")
  if label.Visible then
   local px=math.min(TankLabels.LabelMaxPixels,TankLabels.LabelStuds*projection/sp.Z)
   label.Position=UDim2.fromOffset(sp.X,sp.Y)
   label.Size=UDim2.fromOffset(px,px)
   label.TextSize=math.min(TankLabels.LabelMaxTextSize,px*.72)
   local selectedNow=table.find(selected,model)~=nil
   label.BackgroundColor3=selectedNow and Color3.fromRGB(255,200,40) or Color3.fromRGB(20,22,20)
   label.TextColor3=selectedNow and Color3.new(0,0,0) or Color3.new(1,1,1)
  end
 end
 for model,label in labels do if not alive[model] then label:Destroy() labels[model]=nil end end
end
RunService.RenderStepped:Connect(function(dt)
 elapsed+=dt
 updateLabels()
 local hoveredTank
 if InputMode.get()==CONTROL and (action=="Board" or action=="Escort") then
  local _,result=Aim.groundHit()
  local target=result and result.Instance
  while target and target~=workspace do
   if target:IsA("Model") and target:GetAttribute("CommandTank") then
    if target:GetAttribute("OwnerUserId")==player.UserId then hoveredTank=target end
    break
   end
   target=target.Parent
  end
 end
 boardOutline.Adornee=hoveredTank boardOutline.Enabled=hoveredTank~=nil
 if (InputMode.get()==PLACE or (InputMode.get()==CONTROL and action=="Formation")) and not InputMode.isTyping() then
  local turn=(UIS:IsKeyDown(Enum.KeyCode.E) and (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 1) or 0)
  yaw+=turn*math.rad(60)*1.3*dt
 end
 if trenchPreview then
  local point=Aim.groundHit()
  if hoveredTank or point and selectedInTrench() and not TrenchRoutes.groundInside(point) then trenchPreview:Update(nil) else trenchPreview:Update(point) end
 elseif watchPreview then watchPreview:Update(Aim.groundHit()) elseif preview then local hit=Aim.groundHit() if hit then local cf=CFrame.new(hit+Vector3.new(0,0.06,0))*CFrame.Angles(0,yaw,0) if preview:IsA("Model") then require(RS.WarClient.UnitPlacementVisual).move(preview,cf) else preview.CFrame=cf end end end
 if elapsed<0.1 then return end elapsed=0
 if icon.Visible then spin+=math.rad(15)*0.1 figure:PivotTo(CFrame.Angles(0,spin,0)*CFrame.new(-offset)) poseIcon(0.1) end
 local owned=own() local n=0 for _ in owned do n+=1 end count.Text=n.."/"..C.MaxPerPlayer
 for i,b in slots do
  local m=owned[i] b.Visible=false local isSelected=m and table.find(selected,m)
  b.BackgroundColor3=isSelected and Color3.fromRGB(180,140,30) or Color3.fromRGB(35,38,34)
  b.TextTransparency=m and 0 or 0.6
 end
 if selected[1] and selected[1].Parent then
  local soldier=selected[1]
  local hasBMP=false
  local vehicles=workspace:FindFirstChild("CommandTanks")
  if vehicles then for _,tank in vehicles:GetChildren() do if tank:GetAttribute("OwnerUserId")==player.UserId and tank:GetAttribute("CommandTank") then hasBMP=true break end end end
  local routes=workspace:FindFirstChild("InfantryTrenchRoutes")
  local hasTrench=routes and #routes:GetChildren()>0
  boardButton.Visible=(hasBMP or hasTrench) and not soldier:GetAttribute("Embarked")
  prone.Text=soldier:GetAttribute("Prone") and "T  Stand" or soldier:GetAttribute("Crouched") and (selectedInTrench() and "T  Stand" or "T  Prone") or "T  Crouch"
  local reload=(soldier:GetAttribute("RifleReloadUntil") or 0)-workspace:GetServerTimeNow()
  ammo.Text=reload>0 and string.format("Reload %.1fs",reload) or string.format("AK  %d / 30",soldier:GetAttribute("RifleAmmo") or 30)
 elseif InputMode.get()==CONTROL then InputMode.exit(CONTROL) else ammo.Text="" end
end)

require(RS.WarClient.UnitUI).adopt(menu,hint,"Infantry",ammo)
