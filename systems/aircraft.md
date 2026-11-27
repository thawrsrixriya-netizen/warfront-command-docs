# Shooting down player aircraft (owner) — for enemy AA, HMG and bots

Files: `ServerScriptService.WarServer.AircraftService`, `ReplicatedStorage.AircraftConfig`,
admin test: `StarterPlayerScripts.AircraftTestButton` + `ServerScriptService.AircraftTestServer`.

- Every flying skill (AC-130, SU-34, FPV) has an invisible hitbox Part in `Workspace.Aircraft` that follows it:
  tag `PlayerAircraft`, attributes `Skill` (`AC130`/`Bomber`/`FPV`), `OwnerUserId`, `Health`, `MaxHealth`.
  CanQuery/CanTouch on, CanCollide off — raycasts and projectiles can hit it.
- **To damage it (server only):**
```lua
local Air = require(game.ServerScriptService.WarServer.AircraftService)
Air.damage(hitboxPart, 25, "EnemyAA")   -- or lower the hitbox's "Health" attribute
for _, handle in ipairs(Air.all()) do ... handle.Box ... end   -- list the live aircraft
```
- At Health 0 the aircraft is shot down: the wreck falls and explodes, SU-34 bombs not yet released are cancelled,
  an FPV explodes in the air without damage, and the skill's cooldown becomes × 1.75 (whole seconds).
- `AircraftConfig.Health[skill]` sets MaxHealth. **0 = cannot be shot down yet (all are 0 until the owner decides).**
- Player attribute `AircraftFlying` = how many of that player's aircraft are up.
- `Workspace.Aircraft` is excluded from ground raycasts (`WarUtil.groundParams`, `WarClient.Aim`); exclude it from
  your own raycasts that look for ground.
- Admins have a "SHOOT DOWN (TEST)" button (bottom left) that shoots down their own aircraft even at Health 0.
