# Vision + auto-fire (owner)

Files: `ReplicatedStorage.VisionConfig` (numbers), `ServerScriptService.WarServer.VisionService` (shared sight),
`ServerScriptService.WarServer.AutoFire` (infantry target picking), `StarterPlayerScripts.VisionDisplay` (cones/rings).
Never edit or remove `[SHARED:Vision]` blocks in the friend's infantry scripts.

## Rules of the game
- A unit SEES an enemy if the enemy is inside its sight cone (`VisionRange` studs, `VisionAngle` degrees, centred on
  the unit's facing) or inside `AwareRadius` (all directions), AND a raycast from the unit's eye to the enemy is not
  blocked. Parts with Transparency ≥ 0.9 do not block sight. Buildings/walls block sight and bullets; trees and bushes
  block sight only.
- Whatever any unit sees, every unit of every player sees. An enemy stays visible 5 s (`MemorySeconds`) after the last
  unit loses sight. Seen enemies get the attribute `Spotted = true`.
- A unit may only shoot SEEN enemies within its `WeaponRange`. Default target = nearest seen enemy; clicking an enemy
  forces that target; when it dies the unit goes back to auto-fire. Units can move and shoot at the same time.
- When a unit is shot it turns toward the shooter for `AlertSeconds`, so its cone can see the shooter. A squad turns
  together.
- Infantry profile today: cone 120° / 130 studs, aware 15, weapon 200. A 6-soldier squad is ONE viewer (one cone at
  the squad centre, average facing).

## When you make a NEW unit type (tank, BMP, special forces, MBT, enemy bot...)
1. Ask the owner for its numbers, then add a profile in `VisionConfig.Profiles` (only add; never change other entries):
   `Sniper = { VisionRange = 150, VisionAngle = 60, AwareRadius = 10, WeaponRange = 300, EyeHeight = 1.5 },`
2. On the SERVER, right after the unit is created:
```lua
local Vision = require(game.ServerScriptService.WarServer.VisionService)
Vision.register(model, {
    Team = "Player",            -- player units; enemy bots use "Enemy"
    Profile = "Sniper",         -- key in VisionConfig.Profiles
    GetYaw = function() return currentYaw end,  -- radians; facing = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
    GetEye = function() return root.Position + Vector3.new(0, 1.5, 0) end, -- nil when it cannot see (inside a vehicle)
    OnAttacked = function(fromPos) --[[turn the unit toward fromPos]] end,
    Group = "<ownerUserId>:<squadSlot>", -- OPTIONAL: same Group = ONE viewer (squad)
})
```
   Units that die or are destroyed are removed automatically.
3. To shoot, each server tick: `Vision.nearestVisible(position, profile.WeaponRange, "Player")`;
   `Vision.isVisible(model, "Player")` checks one enemy. Pass the owner Player as the 4th argument of
   `Damage.apply(model, amount, source, player)`. Infantry-like units can reuse `WarServer.AutoFire.update(st, rifleModule, "Profile")`.
4. Enemy weapons that hit a player unit must report it so the unit turns: `Vision.notifyAttacked(victimModel, shooterPosition)`
   (or `victimModel:SetAttribute("AttackedFrom", shooterPosition)`).
5. Enemy bots: register with `Team = "Enemy"`; they see player units with the same rules
   (`Vision.nearestVisible(position, range, "Enemy")`).
6. On screen: a unit shows its cone/ring when it has `VisionProfile` + `OwnerUserId` (set by register). Squads use the
   player attribute `InfantrySelectedSlots`; for other unit types ask the owner before changing VisionDisplay.
7. Bullets ignore trees and bushes (tags `TankReactiveTree`, `TankPassThroughVegetation`); sight does not.

Not built yet: fog of war (hiding enemies nobody sees).
