-- ReplicatedStorage.WarClient.UnitSelection  (ModuleScript)
-- Unit drivers supply their own grouping and control callbacks; drag input stays in TankControls.
local S={}
local drivers={}
function S.register(kind,driver) drivers[kind]=driver end
function S.canHandle(mode)
 if mode==nil then return true end
 for _,d in pairs(drivers) do if d.Mode==mode then return d.Action()==nil end end
 return false
end
function S.clear(mode)
 for _,d in pairs(drivers) do if d.Mode==mode then d.Close() return end end
end
function S.selectBox(lo,hi,mode)
 local camera=workspace.CurrentCamera
 local winner,best,winningList=nil,0,nil
 local kinds={} for kind in pairs(drivers) do table.insert(kinds,kind) end table.sort(kinds)
 for _,kind in ipairs(kinds) do
  local d=drivers[kind]
  local selected,seen={},{}
  for _,m in ipairs(d.Units()) do
   local key=d.Key and d.Key(m) or m
   local pos=d.Position(m)
   local point,on=camera:WorldToViewportPoint(pos)
   if not seen[key] and on and point.Z>0 and point.X>=lo.X and point.X<=hi.X and point.Y>=lo.Y and point.Y<=hi.Y then
    seen[key]=true; table.insert(selected,m)
   end
  end
  if #selected>best or (#selected==best and #selected>0 and d.Mode==mode) then winner=d; best=#selected; winningList=selected end
 end
 if winner then winner.Select(winningList); return true end
 S.clear(mode)
 return false
end
function S.click(result,mode)
 for _,d in pairs(drivers) do
  local m=d.Hit(result)
  if m then d.Select({m}); return true end
 end
 for _,d in pairs(drivers) do if d.Mode==mode and d.OtherClick and d.OtherClick(result) then return true end end
 S.clear(mode)
 return false
end
return S
