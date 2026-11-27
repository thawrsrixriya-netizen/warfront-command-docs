# Economy: money, points, prices, cooldowns (owner)

Files: `ReplicatedStorage.EconomyConfig` (all numbers), `ServerScriptService.WarServer.Economy` (API),
`ServerScriptService.EconomyServer` (setup, kill rewards, admin chat commands).

- **Money** = summon units (and later buy defences). **Points** = skills. Both are player attributes
  (`Money`, `Points`, `Kills`) written by the server only.
- Test mode (`EconomyConfig.TestMode = true`): every player starts with 9999 money and 9999 points.
- Kill money: by the enemy's `UnitType` (`KillReward` table) × `MoneyMultiplier`, paid to the Player passed as the 4th
  argument of `Damage.apply`. Without an attacker every player is paid. 1 point every `KillsPerPoint` kills.
- Cooldowns: player attribute `Cooldown_<key>` = server time when ready. SU-34 and FPV start their cooldown when
  called; AC-130 when it has left. Shot-down aircraft: cooldown × `ShotDownCooldownMultiplier` (1.75), whole seconds.
- Admin chat commands (admins in `EconomyConfig.Admins`): `/money`, `/points`, `/cooldowns`.

## Units: check and charge (server, in the unit's spawn code)
```lua
local Economy = require(game.ServerScriptService.WarServer.Economy)
if not Economy.canSummon(player, "BMP") then return end   -- tells the player why
-- ... create the unit ...
Economy.chargeSummon(player, "BMP")                         -- only after it was really placed
```
Key = `EconomyConfig.Units[key]` (`Cost`, `Cooldown`, `Label`) and the `Economy` field of the hotbar slot.
New unit → ask the owner to add its entry; never hard-code prices.

## Skills (owner's skill scripts)
`Economy.trySkill(player, id)` (pays points, checks cooldown) → `Economy.skillEnded(player, id)` starts the cooldown →
`Economy.skillShotDown(player, id, calledAt)` for a shot-down aircraft.

Current draft prices: Infantry squad 100, BMP 250, MBT 500 (cooldown 5 s each); FPV 1 point / 30 s,
SU-34 2 points / 60 s, AC-130 3 points / 120 s.
