-- ReplicatedStorage.WarClient.UnitUI  (ModuleScript)
local Players=game:GetService("Players")
local InputMode=require(script.Parent.InputMode)
local UI={}
local gui=Instance.new("ScreenGui") gui.Name="UnitCommandUI" gui.ResetOnSpawn=false gui.DisplayOrder=15
gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local function round(p,r) local c=p:FindFirstChildOfClass("UICorner") or Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 7) c.Parent=p end
local hint=Instance.new("Frame") hint.Name="PlacementHint" hint.AnchorPoint=Vector2.new(.5,0)
hint.Position=UDim2.new(.5,0,0,120) hint.Size=UDim2.fromOffset(610,42)
hint.BackgroundColor3=Color3.fromRGB(19,24,30) hint.BackgroundTransparency=.12 hint.Visible=false hint.Parent=gui round(hint)
local text=Instance.new("TextLabel") text.Name="Instructions" text.Position=UDim2.fromOffset(12,0)
text.Size=UDim2.new(1,-124,1,0) text.BackgroundTransparency=1 text.Font=Enum.Font.GothamMedium text.TextSize=13
text.TextColor3=Color3.fromRGB(235,239,242) text.TextXAlignment=Enum.TextXAlignment.Left text.Parent=hint
local cancel=Instance.new("TextButton") cancel.Name="Cancel" cancel.Position=UDim2.new(1,-108,0,7)
cancel.Size=UDim2.fromOffset(100,28) cancel.Text="X  CANCEL" cancel.Font=Enum.Font.GothamBold cancel.TextSize=12
cancel.BackgroundColor3=Color3.fromRGB(190,55,55) cancel.TextColor3=Color3.new(1,1,1) cancel.Parent=hint round(cancel,6)
cancel.Activated:Connect(function() InputMode.blockClicks(.25) InputMode.exit() end)
local function update(mode)
 hint.Visible=mode=="TankPlace" or mode=="InfantryPlace"
 text.Text=mode=="TankPlace" and "Click to deploy BMP  |  Q / E rotate" or "Click to deploy 6 soldiers  |  Q formation / E rotate"
end
InputMode.Changed:Connect(update) update(InputMode.get())
function UI.adopt(menu,message,kind,ammo)
 menu.Parent=gui menu.Name=kind.."Commands" menu.AnchorPoint=Vector2.new(.5,1)
 menu.Position=UDim2.new(.5,0,1,-110) menu.Size=UDim2.fromOffset(454,92)
 menu.BackgroundColor3=Color3.fromRGB(19,24,30) menu.BackgroundTransparency=.12 menu.BorderSizePixel=0 round(menu,9)
 local positions={Move={8,8},Fire={120,8},Prone={232,8},Stop={344,8},Watch={8,50},FormationButton={152,50},Board={296,50},Disembark={296,50},Trench={8,92}}
 for _,b in menu:GetChildren() do if b:IsA("TextButton") then
  local pos=positions[b.Name]
  if pos then b.AnchorPoint=Vector2.zero b.Position=UDim2.fromOffset(pos[1],pos[2])
   b.Size=UDim2.fromOffset(pos[2]==8 and 102 or 140,34)
   b.BackgroundColor3=Color3.fromRGB(37,45,53) b.BackgroundTransparency=.08
   b.TextColor3=Color3.fromRGB(240,243,245) b.Font=Enum.Font.GothamBold b.TextSize=12
   b.BorderSizePixel=0 round(b,6)
  end
 end end
 if message then message.Parent=gui message.AnchorPoint=Vector2.new(.5,1)
  message.Position=UDim2.new(.5,0,1,-210) message.Size=UDim2.fromOffset(540,28)
  message.Font=Enum.Font.GothamMedium message.TextSize=13 message.BackgroundColor3=Color3.fromRGB(19,24,30)
  message.BackgroundTransparency=.12 message.TextColor3=Color3.fromRGB(235,239,242) round(message,6)
 end
 if ammo then ammo.Parent=menu ammo.Position=UDim2.fromOffset(232,-27) ammo.Size=UDim2.fromOffset(214,24) end
 -- [SHARED:UnitPanel] BEGIN  (owner's left command column under the minimap; see doc "To ChatGPT"; do not change or remove)
 -- Moves this unit's command buttons into the left column (one full-width row each, ordered by the
 -- positions above). New commands: put a TextButton in `menu` or use UnitCommandPanel.addButton.
 if ammo then ammo.LayoutOrder=1 end
 require(script.Parent.UnitCommandPanel).adopt(menu,{Title=string.upper(kind)})
 -- [SHARED:UnitPanel] END
end
return UI
