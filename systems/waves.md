# Enemy waves (owner; bot AI = friend) — `ServerScriptService.WaveServer`, `ReplicatedStorage.WaveConfig`, `StarterPlayerScripts.WaveClient`

## Flow
- Waves start after the first centre capture. Total: Easy 20 / Normal 30 / Hard 35 (`EconomyConfig.Difficulty`).
- Wave n contains `WaveConfig.composition(n)` (draft): soldiers 6 + 2 per wave (max 40); BMP from wave 5;
  MBT from wave 15; a boss every 10 waves. Health +6% per wave.
- A wave ends when all its enemies are dead → 3 s break (20 s after every 5th wave) → next wave.
- **SKIP WAVE** appears only after the current wave has run 60 s with enemies still alive (`MatchCanSkip`); it starts
  the next wave now (old enemies stay). **AUTO SKIP** presses it automatically. Breaks cannot be skipped.
  Client → server: `Remotes.MatchCommand:FireServer("Skip")` / `("AutoSkip", true|false)`.
- After the last wave: `MatchPhase = "Victory"`. No lose condition yet (player base not built).

## Enemies
- Spawn at waypoint `1` of a random road in `Workspace.MatchPoints.EnemyPaths` (Path1_South / Path2_West /
  Path3_East), walk the waypoints to the centre, then 1–3 straight hops to free spots inside the capture zone
  (no roof, nothing solid in the way) and hold there — so they can take the centre back.
- Models: clones of `ServerStorage.WaveEnemies.<Template>` placed in `Workspace.Enemies`, attributes
  `WaveEnemy = true`, `UnitType` (Soldier/BMP/MBT/Boss), `Wave`. Health from `WaveConfig.Types[x].Health`.
- **Today they are placeholders:** the yellow dummy (`WaveSoldier`), scaled and tinted for BMP/MBT/Boss. They are
  anchored and GLIDE (PivotTo); they do not shoot.

## Putting the friend's real bots in
1. Add the bot models to `ServerStorage.WaveEnemies` and set `WaveConfig.Types[x].Template` to their names
   (ask the owner before changing numbers in WaveConfig).
2. Replace the placeholder movement in WaveServer (the `walkers` table + Heartbeat loop, and `spawnEnemy`'s
   anchoring / PivotTo) with the bot AI. Keep: parent in `Workspace.Enemies`, a `Humanoid` (its `Died` is counted for
   "enemies left"), attributes `WaveEnemy` / `UnitType` / `Wave`, the route idea (road → centre zone).
3. Register bots with VisionService as `Team = "Enemy"` (vision.md); when they hit a player unit call
   `Vision.notifyAttacked`; damage player aircraft only through AircraftService (aircraft.md).
4. Post a `change-report` Issue — this touches an owner script.
