-- ServerScriptService.WarServer.InfantryPosture  (ModuleScript)
local P={}
local Routes=require(game.ReplicatedStorage.WarShared.TrenchRoutes)
function P.inTrench(st)
 if st.TrenchCover and (st.TrenchCover.Phase=="Inside" or st.TrenchCover.Phase=="Settled" or st.TrenchCover.Phase=="Roam" or st.TrenchCover.Phase=="RoamPaused") then return true end
 local pos=st.Pos or st.Root and st.Root.Position
 if not pos then return false end
 local old=st.TrenchPostureCache
 if old and os.clock()<old.Until and (pos-old.Pos).Magnitude<.6 then return old.Inside end
 local inside=Routes.bodyInside(pos)
 st.TrenchPostureCache={Until=os.clock()+.15,Pos=pos,Inside=inside}
 return inside
end
function P.name(st) return st.Prone and "Prone" or st.Crouched and "Crouch" or "Standing" end
function P.next(st)
 if P.inTrench(st) then return st.Crouched and "Standing" or st.Prone and "Standing" or "Crouch" end
 return st.Prone and "Standing" or st.Crouched and "Prone" or "Crouch"
end
function P.set(st,name,manual)
 st.Prone=name=="Prone" st.Crouched=name=="Crouch"
 if not st.CeilingProne then st.RequestedPosture=name end
 st.Model:SetAttribute("Prone",st.Prone) st.Model:SetAttribute("Crouched",st.Crouched) st.Model:SetAttribute("Posture",name)
 if manual~=nil then
  st.AutoPosture=not manual st.Model:SetAttribute("AutoPosture",not manual)
  if manual then st.RequestedPosture=name if st.CeilingProne then st.CeilingResume=name end end
 end
end
function P.clearance(st)
 local inside=P.inTrench(st)
 local pos=st.Pos
 local low=false
 if inside then
  local cache=st.CeilingCache
  if cache and os.clock()<cache.Until and (pos-cache.Pos).Magnitude<.6 then low=cache.Low
  else
   local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.RespectCanCollide=true
   local skip={workspace.CommandInfantry}
   for _,p in game.Players:GetPlayers() do if p.Character then table.insert(skip,p.Character) end end
   local fx=workspace:FindFirstChild("ClientFX") if fx then table.insert(skip,fx) end
   rp.FilterDescendantsInstances=skip
   local origin=pos-Vector3.new(0,st.Offset,0)+Vector3.new(0,.3,0)
   local height=6*st.Model:GetScale()+.1
   local hit=workspace:Blockcast(CFrame.new(origin),Vector3.new(.45,.05,.45),Vector3.new(0,math.max(.1,height-.3),0),rp)
   low=hit~=nil and hit.Normal.Y<-.25
   st.CeilingCache={Until=os.clock()+.15,Pos=pos,Low=low}
  end
 end
 st.Model:SetAttribute("LowCeiling",low)
 if low then
  if not st.CeilingProne then st.CeilingResume=st.Crouched and "Crouch" or "Standing" end
  st.CeilingProne=true P.set(st,"Prone")
 elseif st.CeilingProne then
  st.CeilingProne=nil P.set(st,st.CeilingResume or "Standing") st.CeilingResume=nil
 elseif inside and st.Prone then P.set(st,"Standing") end
end
function P.sync(st)
 if st.Prone then st.Crouched=false end
 local name=P.name(st)
 if st.Model:GetAttribute("Posture")~=name or st.Model:GetAttribute("Crouched")~=(st.Crouched==true) then P.set(st,name) end
end
return P
