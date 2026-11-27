# Centre base capture (owner) — `ServerScriptService.CaptureServer`, `ReplicatedStorage.CaptureConfig`, `StarterPlayerScripts.CaptureZoneClient`

- Zone = `Workspace.MatchPoints.CenterBase` (the friend's red box; X/Z footprint only). Do not rename or move it out
  of MatchPoints. Hidden in game; the client draws a faint red dashed outline on `GroundAndTrenches` + a very faint fill.
- **Strength inside the zone** (draft = loadout point values, `CaptureConfig`):
  - ours: each infantry soldier 2/6 (a squad of 6 = 2), each `CommandTanks` model 3 (`UnitType` attribute picks
    `MBT` = 5, `Tank` = 3, `SpecialForces` = 3; missing = BMP 3);
  - enemies: by the enemy model's `UnitType`: Soldier 2/6, BMP 3, Tank 3, MBT 5, Boss 5 (missing = Soldier).
  - **Set `UnitType` on every bot.**
- **One control bar** from -1 (full RED = enemy holds) to +1 (full BLUE = we hold). A side pushes it when its
  strength > the other side's × 1.2 (more strength = up to 1.5× faster). It first drains the other colour 2× faster;
  at 0 the centre becomes NEUTRAL (owner `None`); then it fills its own colour in 15 s and captures. Both sides
  inside and nobody strong enough = contested, the bar holds. Nobody inside: the bar slowly returns to its holder.
- **State** (read it from ReplicatedStorage on clients — the zone part may not be streamed in):
  `CenterOwner` (`Enemy`|`Player`|`None`), `CenterControl` (-1..1), `CenterBy` (who is pushing), `CenterPlayerStrength`,
  `CenterEnemyStrength`, `CenterContested`, `CenterZoneCFrame`, `CenterZoneSize`, `CenterCapturedOnce`.
  The server also writes `CaptureOwner` / `CaptureControl` / ... on the CenterBase part.
- The first player capture sets `MatchWave = 1`, `MatchPhase = "Wave"` (WaveServer starts the waves).
- Server scripts can listen: `ServerScriptService.CaptureServer.Changed:Connect(function(newOwner, oldOwner) end)`.
- Planned (not built): the loser's defences are destroyed when the centre changes hands; the captured centre gives
  bunkers/buildings for cover.
