-- ServerScriptService.OvercastWeatherServer  (Script)
-- Shared overcast weather: dry spells and occasional rain, with soft cloud transitions.
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local rng=Random.new()
local weather=RS:FindFirstChild("MapWeather")
if not weather then weather=Instance.new("Folder");weather.Name="MapWeather";weather.Parent=RS end
local clouds=workspace.Terrain:FindFirstChildOfClass("Clouds")
local function phase(raining,duration)
 weather:SetAttribute("Raining",raining)
 weather:SetAttribute("PhaseEndsAt",workspace:GetServerTimeNow()+duration)
 if clouds then TweenService:Create(clouds,TweenInfo.new(8),{
  Cover=raining and 0.94 or 0.82,
  Density=raining and 0.72 or 0.6,
  Color=raining and Color3.fromRGB(153,160,170) or Color3.fromRGB(177,183,191)}):Play() end
 task.wait(duration)
end
while true do
 phase(false,rng:NextNumber(70,150))
 phase(true,rng:NextNumber(40,85))
end
