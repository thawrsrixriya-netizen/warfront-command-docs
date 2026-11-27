# HUD and input (owner)

Scripts: `StarterPlayerScripts.MatchHUD`, `ReplicatedStorage.WarClient.{InputMode, Aim, UnitSlots, SkillActions,
CameraJump, UnitCommandPanel}`, `StarterPlayerScripts.TopViewCamera`.

## Screen layout
- **Top centre:** wave panel (`WAVE n / total`, enemies left, phase), AUTO SKIP toggle, SKIP WAVE button (only while
  `MatchCanSkip`), capture panel (right of AUTO SKIP).
- **Top left:** round minimap (150 px); **left column under it:** unit commands (only while units are selected).
- **Bottom centre:** hotbar slots 1–6 (summon units) + SHOP + SKILLS. **Bottom left:** money / points.
- Right panel opens for SHOP / SKILLS.

## InputMode — every world click goes through it
```lua
local InputMode = require(game.ReplicatedStorage.WarClient.InputMode)
InputMode.enter("SniperPlace", function() --[[cleanup when the mode ends]] end)
InputMode.exit("SniperPlace")
InputMode.get()               -- current mode name or nil
InputMode.blockClicks(0.25)   -- ignore world clicks briefly (after a UI click)
InputMode.isTyping()
```
Entering a mode exits the previous one (its onExit runs). `WarClient.Aim.groundHit()` = mouse ray to the ground,
ignoring characters, `Workspace.ClientFX` and `Workspace.Aircraft`.

## Register a unit in the hotbar
```lua
require(game.ReplicatedStorage.WarClient.UnitSlots).register(3, {
    Name = "SNIPER",              -- slot label
    Mode = "SniperPlace",         -- InputMode name used while placing
    Call = startPlacement,        -- function that starts placing
    Count = function() return current, max end,
    BuildIcon = function(viewportFrame) ... return true end, -- optional still icon
    Hint = "Click to place",      -- optional hint bar text
    Economy = "Sniper",           -- key in EconomyConfig.Units (price/cooldown)
})
```
Keys 1–6 call the slot. X cancels a unit placement mode.

## Register a skill in the SKILLS panel
```lua
require(game.ReplicatedStorage.WarClient.SkillActions).register("Bomber", {
    Mode = "BomberAim", Call = enterAim, Hint = "Click to set the target ...",
    -- optional: Recall = fn, State = fn -> "Ready"|"Active"|"Leaving"
})
```
Esc or X cancels skill aiming (MatchHUD handles X for every registered skill mode).

## Reserved keys
| Key | Use | Script |
|---|---|---|
| 1–6 | summon from hotbar slot | MatchHUD |
| M | cycle camera Person → Top → Free | TopViewCamera |
| W A S D, arrows, Space, Ctrl, Shift, right mouse (hold), mouse wheel | camera control | TopViewCamera |
| Esc | cancel / close panel | all |
| X | stop selected units; cancel placement / skill aim; close the big map | Tank/InfantryControls, MatchHUD, MiniMap |
| Q / E | rotate while placing; Q = infantry formation | TankControls, FPV, InfantryControls |
| Z | move | Tank/InfantryControls |
| F | fire | Tank/InfantryControls |
| T | prone / stand | InfantryControls |
| C | watch (face a direction) | Tank/InfantryControls |
| G | enter / board / disembark | Tank/InfantryControls |
| left click / drag box | select, place, command (through InputMode) | all |

## Match attributes the HUD reads (do not rename)
ReplicatedStorage: `MatchWave`, `MatchWaveTotal`, `MatchEnemiesLeft`, `MatchPhase` (`Waiting|Wave|Break|Victory`),
`MatchBreakEnds` (server time), `MatchCanSkip` (bool). Player: `Money`, `Points`, `AutoSkip`, `Cooldown_<key>`.
