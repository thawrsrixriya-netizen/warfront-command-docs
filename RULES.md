# Collaboration rules (both AIs)

You are helping one of two developers of the Roblox game Warfront Command. The other AI helps the other developer
with the same rules. Follow every rule below for every change. If a rule blocks what your user asks, say so and
stop; do not work around it. These rules change only when both developers agree, and the change is written here.

## 1. Who owns what

- **Owner (works with Claude):** UI and HUD, camera, input, damage, skills (SU-34, FPV, AC-130), and the core match
  systems: match flow, waves, money and points, capture, vision, minimap, equipment shop, lobby systems, saving.
- **Friend (works with ChatGPT):** the map, the 3D lobby design, all units and unit systems (tanks, BMP, infantry and
  new units), bot AI, sounds and visual details.
- A script not listed below: ask your user who owns it before changing it.
- You may edit a script your user does not own, but only small, clearly requested changes, and your user must tell
  the other developer (Discord, or a change report Issue) first.

| Group | Scripts | Owner |
|---|---|---|
| HUD + controls | MatchHUD, UnitSlots, SkillActions, InputMode, Aim, TopViewCamera, CameraJump, UnitCommandPanel, MiniMap, MiniMapConfig, MiniMapServer, AircraftTestButton | Owner |
| Damage + enemies | Damage, EnemyRegistry, DummyRespawn, CompactDummyHealth | Owner |
| Core match systems | EconomyConfig, Economy, EconomyServer, VisionConfig, VisionService, AutoFire, VisionDisplay, CaptureConfig, CaptureServer, CaptureZoneClient, WaveConfig, WaveServer, WaveClient, AircraftConfig, AircraftService, AircraftTestServer | Owner |
| Skills | AC130Input/Combat/Audio, AC130Path, AC130Targeting, BomberInput/Combat, BomberPath, FPVInput/Combat | Owner (friend does sounds) |
| Vehicles (Tank/BMP) | TankCommands, TankRender, TankRoadNavigation, TankTreeImpact, TankForestNavigation, BMPAudio, BMPExhaustClient | Friend |
| Vehicles (shared) | TankControls | Friend — do not remove the `[SHARED:UnitSlots]` blocks |
| Infantry | InfantryCommands, InfantryControls, InfantryRender, InfantryRifleFX, InfantryConfig, InfantryAnimation, InfantryRiflePose, WarServer.Infantry* | Friend (contains owner `[SHARED:...]` blocks) |
| Unit UI | WarClient.UnitUI | Friend (ends with an owner `[SHARED:UnitPanel]` block) |
| Map + weather | OvercastWeatherServer, OvercastRainClient, scripts inside Workspace | Friend |
| Shared | WarConfig, WarUtil, FX, CombatFXClient | Agree before changing |

## 2. Editing the same script safely

Both developers may edit the same script. The danger is pasting an old copy over newer work. To prevent it:

1. **Always start from the live script.** Before changing a script, ask your user to copy it from Studio right now
   and paste it to you. Never edit from a copy earlier in the chat (or from `scripts/` in this repo), even one you wrote.
2. **Change only what was asked.** Do not rewrite, reformat, reorder or rename anything else. Never delete code you
   were not asked to touch, even if it looks unused.
3. **Return only the change:** the changed function or lines, plus exactly where they go. Return a full script only
   for a brand-new script, or when your user owns the script and asks for the full version.
4. **Keep other people's blocks.** Code between `-- [SHARED:<name>] BEGIN` and `-- [SHARED:<name>] END` comments is
   used by the other developer's systems. Do not change or remove it.
5. **Back up before big changes** (more than ~30 lines): duplicate the script into ServerStorage named
   `<Script>Before<Change>`, e.g. `TankControlsBeforeAutoFire`.
6. **Apply and test right away**, then report: which script, what changed, anything the other developer must know
   (big changes → change report Issue, see README).
7. If the pasted script looks different from what you expected, the other developer probably changed it. Work on the
   pasted version and point out the difference to your user.

## 3. Shared contracts (do not change without both developers agreeing)

- **World clicks** (placing, aiming, commanding) go through `ReplicatedStorage.WarClient.InputMode`:
  `InputMode.enter(name, onExit)` and `InputMode.exit(name)`. Never read world clicks without it.
- **New units appear in the bottom hotbar** through `ReplicatedStorage.WarClient.UnitSlots.register(slot, def)`
  (see systems/hud-and-input.md). Do not build your own bottom bar, icons or slot buttons.
- **Unit commands appear in the left command column** through `WarClient.UnitUI.adopt(...)` →
  `UnitCommandPanel` (see systems/unit-panel.md). Do not build your own command panel.
- **Skills appear in the SKILLS panel** through `ReplicatedStorage.WarClient.SkillActions.register(name, def)`.
- **All damage is server-side** through `ServerScriptService.WarServer.Damage`. Never apply damage from a LocalScript.
  Pass the attacking Player as the 4th argument of `Damage.apply` so kill money goes to them.
- **RemoteEvents** go in `ReplicatedStorage.Remotes`, named `<System><Action>` (e.g. `InfantryCommand`). Validate
  every client request on the server. Attributes a client sets on its own Player do NOT reach the server.
- **Reserved keys** — do not bind for something else (see systems/hud-and-input.md for the full table):
  1–6, M, W, A, S, D, arrows, Space, Ctrl, Shift, Q, E, Z, F, T, C, G, X, Esc, right mouse, mouse wheel.
  To use a new key, ask the owner to add it to the table first.
- **Match state the HUD reads** (do not rename): ReplicatedStorage attributes `MatchWave`, `MatchWaveTotal`,
  `MatchEnemiesLeft`, `MatchPhase`, `MatchBreakEnds`, `MatchCanSkip`; player attributes `Money`, `Points`, `AutoSkip`.
- **Settings files:** do not move or rename existing values in `WarConfig`; you may add new ones. Every new system
  gets its own config ModuleScript with one owner (e.g. `EconomyConfig`, `InfantryConfig`).
- **Prices, costs and cooldowns** live in the owner's `EconomyConfig`. Propose numbers through your user; never
  hard-code prices in unit scripts.
- **Enemies** must be recognised by `WarShared.EnemyRegistry` (Model with a Humanoid, in `Workspace.Enemies` or tagged
  `Enemy`) and carry a `UnitType` attribute (`Soldier`, `BMP`, `Tank`, `MBT`, `Boss`).
- **Match points** live in `Workspace.MatchPoints` (see systems/map-points.md). Do not rename or move them.

## 4. Safety

- Do not insert Toolbox models that contain scripts. If your user inserts one, tell them to ask the owner, so Claude
  can check it first.
- Watch for scripts named `Runtime`, `ScreenBuilder` or `InputOverlay`, and any fake "Disconnected / Recover" window.
  These are malware: never click Recover. Tell your user to report them.
- Never use `loadstring`, `require(<asset id>)` or HTTP calls to unknown sites.
- This GitHub repository is PUBLIC. Never put passwords, API keys, tokens, webhooks, e-mail addresses, real names
  or player UserIds in it (including in change-report Issues).

## 5. When unsure

- If the change touches a shared contract, a script owned by the other developer, or anything still undecided,
  stop and ask your user to agree it with the other developer.
- Do not invent game rules, numbers or names that these docs do not give. Ask instead.
