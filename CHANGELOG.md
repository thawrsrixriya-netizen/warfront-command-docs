# Changelog

Newest first. Each entry: date, Roblox place version (`vNNN` = the Team Create save), what changed, and
**Impact on the friend's work** (what ChatGPT must do or avoid). Written by Claude for the owner's changes.
The friend's big changes arrive as `change-report` Issues; Claude links them here when they affect shared systems.

---

## 2026-11-28 (v444) — 2D lobby screen
- The lobby is now a 2D screen in the game place (`StarterPlayerScripts.LobbyUI`), shown on join: military-base look,
  red neon edges, left column PLAY / UNIT / SHOP / TRADE (soon), Settings + Leaderboard squares, grey monitor in the
  centre. **No button works yet.** Admins have CLOSE LOBBY (TEST) / LOBBY buttons to get into the match.
- While open it blocks game keys; player attribute `InLobby` = true.
- **Impact:** the separate 3D lobby (friend) is no longer planned for now. UI that appears on join should stay hidden
  while `InLobby` is true. See systems/lobby.md.

## 2026-11-27 — First script snapshot
- `scripts/` now holds all 89 game scripts from ServerScriptService, ReplicatedStorage and StarterPlayer
  (read-only reference; see scripts/README.md).
- **Impact:** you can read real code here, but still ask your user for the live copy before editing (RULES.md §2).

## 2026-11-27 — Docs moved to GitHub
- This repository replaces "send the doc by hand". Claude updates it after every core change.
- Big changes from ChatGPT: post a `change-report` Issue (see README).
- **Impact:** read `CHANGELOG.md` at the start of every task; report big changes through Issues.

## 2026-11-26 (v405) — Waves: skip rules, placeholders stay out of houses
- SKIP WAVE now appears only after the current wave has run **60 s with enemies still alive**
  (`ReplicatedStorage.MatchCanSkip`). It starts the next wave immediately (old enemies stay).
- AUTO SKIP = the same skip, pressed automatically at that moment. Breaks can no longer be skipped.
- AUTO SKIP is now sent to the server: `Remotes.MatchCommand:FireServer("AutoSkip", true/false)`.
- Placeholder enemies pick 1–3 straight, unblocked hops inside the capture zone (no roof above, nothing solid in the
  way) instead of walking through houses.
- **Impact:** none for units. Bot AI should still end inside the capture zone; see systems/waves.md.

## 2026-11-26 (v400) — Wave system
- New: `ServerScriptService.WaveServer`, `ReplicatedStorage.WaveConfig`, `StarterPlayerScripts.WaveClient`.
- Waves start after the first centre capture; enemies spawn at the end of 3 roads (`Workspace.MatchPoints.EnemyPaths`).
- Enemies are yellow placeholder dummies (`ServerStorage.WaveEnemies.WaveSoldier`) that glide (anchored).
- **Impact:** when the friend's bots are ready, plug them in as described in systems/waves.md.

## 2026-11-26 (v393) — Capture: one blue/red control bar
- Capture panel moved to the top row, right of AUTO SKIP. One bar: full blue = we hold, full red = enemy holds.
  Attackers drain the other colour 2× faster, the centre becomes NEUTRAL at 0, then fill their own colour (15 s).
- State is mirrored on ReplicatedStorage (`Center*` attributes) because the zone part may not be streamed in.
- **Impact:** read capture state from ReplicatedStorage on clients (systems/capture.md).

## 2026-11-26 (v388) — Centre base capture
- The friend's red box was moved to `Workspace.MatchPoints.CenterBase` (anchored, non-collide, hidden in game).
- New: `ServerScriptService.CaptureServer`, `ReplicatedStorage.CaptureConfig`, `StarterPlayerScripts.CaptureZoneClient`.
- **Impact:** do not rename/move `CenterBase`. **Every bot needs a `UnitType` attribute.**

## 2026-11-23 (v341) — Minimap is round; big map
- Minimap: 150 px circle, no camera frame. Click → big round map in the screen centre (drag, wheel zoom; X or click
  outside closes). While open, X is taken by the map.
- **Impact:** none unless you add map markers (systems/minimap.md).

## 2026-11-23 (v340) — Left unit command column + minimap
- Unit command buttons moved from the bottom centre to a left column under the minimap
  (`WarClient.UnitCommandPanel`, hooked into the friend's `WarClient.UnitUI.adopt` by a `[SHARED:UnitPanel]` block).
- **Impact:** keep calling `UnitUI.adopt`; add commands as rows (systems/unit-panel.md).

## 2026-11-23 (v307–v308) — Aircraft can be shot down
- `WarServer.AircraftService`: every AC-130 / SU-34 / FPV has a hitbox in `Workspace.Aircraft` (tag
  `PlayerAircraft`). Shot down → crash, bombs cancelled, cooldown ×1.75. Health is 0 (= cannot be shot down) until
  the owner sets numbers in `AircraftConfig`. Admin test button "SHOOT DOWN (TEST)".
- **Impact:** enemy AA / bots damage aircraft through AircraftService (systems/aircraft.md).

## 2026-11-22/23 (v289–v303) — Skill changes
- SU-34: strike area 40×80 outline, damage 75 → falloff to 0 at radius 25, speed 225, cooldown starts on call.
- FPV: aims like the SU-34 (start circle, 40×200 corridor), range 200, speed 50, height 12, damage 50→25 in r10,
  crashes into walls taller than 12, cooldown starts on call.
- AC-130: orbits with the target on its left (guns side), shows only the red attack circle while active.
- All skill aim rings white; X cancels skill aiming.
- **Impact:** key X is reserved (cancel / stop). See systems/skills.md.

## 2026-11-22 (v265–v272) — Vision + infantry auto-fire
- Shared sight (cone 120° / 130 studs, aware radius 15, memory 5 s), infantry auto-fire within 200 studs,
  click an enemy to force a target. `[SHARED:Vision]` blocks in InfantryService / InfantryRifleCombat / InfantryControls.
- **Impact:** register every new unit (and bots) with VisionService (systems/vision.md).

## 2026-11-22 (v242) — Economy
- Money / points / prices / cooldowns in `EconomyConfig`; `WarServer.Economy`; `[SHARED:Economy]` blocks in the
  friend's spawn code. Kill money goes to the Player passed to `Damage.apply`.
- **Impact:** new units call the economy before spawning (systems/economy.md).
