-- ReplicatedStorage.WarClient.GroundLineProjection  (ModuleScript)
-- Visual-only floor sampling cache. X/Z geometry is evaluated every rendered frame.
local P={}; P.__index=P
function P.new(cast,offset)
 return setmetatable({Cast=cast,Offset=offset,Points={},Index=0,Now=0,Alpha=1,Casts=0},P)
end
function P:BeginFrame(dt)
 self.Index=0; self.Now=os.clock(); self.Alpha=1-math.exp(-math.min(dt,.1)*25)
end
function P:Project(point)
 self.Index+=1
 local entry=self.Points[self.Index]
 local moved=entry and Vector2.new(point.X-entry.Point.X,point.Z-entry.Point.Z).Magnitude or math.huge
 local reset=not entry or moved>8 or math.abs(point.Y-entry.InputY)>8
 local stale=entry and self.Now>=entry.NextCheck and (moved>.08 or self.Now-entry.At>=1)
 if reset or stale then
  local hit=self.Cast(point); self.Casts+=1
  local height=hit and hit.Position.Y or point.Y
  if reset then entry={Y=height}; self.Points[self.Index]=entry end
  entry.Point=hit and hit.Position or point
  entry.Normal=hit and hit.Normal or Vector3.yAxis
  entry.InputY=point.Y; entry.At=self.Now
  entry.NextCheck=self.Now+.12+(self.Index%7)*.01
 end
 local normal=entry.Normal
 local height=entry.Point.Y
 if math.abs(normal.Y)>.2 then
  height-=((point.X-entry.Point.X)*normal.X+(point.Z-entry.Point.Z)*normal.Z)/normal.Y
 end
 entry.Y+=(height-entry.Y)*self.Alpha
 return Vector3.new(point.X,entry.Y+self.Offset,point.Z)
end
return P
