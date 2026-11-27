# Left unit command column (owner) — `ReplicatedStorage.WarClient.UnitCommandPanel`

The friend's `WarClient.UnitUI.adopt(menu, message, kind, ammo)` ends with an owner `[SHARED:UnitPanel]` block that
calls `UnitCommandPanel.adopt(menu, {Title = string.upper(kind)})`. Keep calling `UnitUI.adopt` from unit scripts;
do not remove the SHARED block.

- The column sits on the left under the minimap and is visible only while one adopted menu is `Visible`
  (= while units are selected). Keep toggling `menu.Visible` as before.
- Every GuiObject inside `menu` becomes one full-width row. Order = `LayoutOrder`; if 0 it is taken from the row's
  old Position (row by row, left to right). The ammo label (if passed) is the first row.
- **Add a command:**
```lua
local Panel = require(game.ReplicatedStorage.WarClient.UnitCommandPanel)
local b = Panel.addButton(menu, "K  Smoke", function() ... end, 55)  -- text, callback, LayoutOrder
b.Visible = false   -- hide a row that does not apply right now
```
  or create any TextButton inside `menu` (it is styled automatically).
- Do not set Size/Position of rows — the column lays them out. Keys shown in the text must be reserved first
  (hud-and-input.md).
