# Lobby (2D, owner) — `StarterPlayerScripts.LobbyUI`

The lobby is now a **2D screen inside the game place** (no separate 3D lobby place for now). It is the first thing a
player sees on join, drawn over the match.

## Look (owner's sketch, 2026-11-28)
- Military-base wall: dark steel background, faint grid, red/black hazard bands top and bottom, vignette.
- Every panel has a **red neon edge** (a sharp `UIStroke` + a wider soft glow stroke).
- **Left column:** `PLAY`, `UNIT`, `SHOP`, `TRADE` (greyed, tag `SOON`). Under it two small square buttons:
  **Settings** (gear icon) and **Leaderboard** (players icon).
- **Centre:** a grey "monitor" screen with scanlines and red corner brackets; status text
  `WARFRONT COMMAND // MONITOR 01 // STANDBY`. Content will be designed by the owner later.

## PLAY screen (battlefield map) — `LobbyUI.PlayScreen` (child module) + `ReplicatedStorage.LobbyMapConfig`
- PLAY opens a full-screen **country map** of the fictional country **Velmoria** (placeholder names): dark
  topographic style — land, islands, mountain relief, rivers, dashed roads, coordinate grid, sea name.
- **Markers** (diamond + underlined name) = battlefields. Today only **Dolvin Village** (the current match map) is
  playable; the other 5 show `LOCKED`.
- Click a marker → it turns red, a red line runs to the **right panel**: name, status (AVAILABLE / LOCKED),
  picture placeholder (`Image` in the config, empty for now), short info, and a **4-slot weather forecast**
  (RAIN, FOG, DAY, NIGHT; possible weather lit, the rest dimmed). Forecast only — players cannot pick weather.
  Planned: weather buffs/nerfs units (e.g. night = shorter sight, day = longer sight).
- **NEXT** (bottom right) turns red for a playable place; it does nothing yet. **BACK** (top right) returns to the menu.
- Edit names, positions, coastline, mountains, rivers, roads and weather in `LobbyMapConfig` (owner's file).

## SQUAD screen (after NEXT) — `LobbyUI.SquadScreen` + `ReplicatedStorage.LobbyItemsConfig`
- Top: the player's avatar (tall box), a "+" box for PLAYER 2 (invite — soon), **START** (red, does nothing yet)
  and **BACK** (returns to the map). The chosen place is shown under the SQUAD title.
- Bottom, left to right: **difficulty** EASY 20 / NORMAL 30 / HARD 35 / **NIGHTMARE 40** waves (new difficulty;
  `WaveConfig.TotalWaves.Nightmare = 40`), **UNIT** slots 1–6, **SKILL** slots 1–3 + **DEFENSE** slots 1–4, and the
  **items box** (things bought in the shop): tabs UNITS / SKILLS / DEFENSE, item cards, a details strip and
  **LOADOUT used/10** (units cost loadout points: infantry 2, BMP 3, special forces 3, MBT 5).
- Click a card to equip/unequip it; click a filled slot to empty it. Not-owned items show `SHOP`.
- **Placeholder:** everything is local to the screen — nothing is saved, the shop does not exist, "Owned" is fixed in
  `LobbyItemsConfig`. The chosen difficulty and loadout do not reach the match yet.

## Behaviour today
- PLAY → map → NEXT → SQUAD works; **START, UNIT, SHOP, TRADE, Settings, Leaderboard and PLAYER 2 do nothing yet**
  (hover only). The owner designs each screen next.
- While open it covers the match and swallows game keys (1–6, M, WASD, arrows, Space, Q, E, Z, F, T, C, G, X), so
  nothing happens in the match behind it. Player attribute `InLobby` = true while open.
- Admins (`EconomyConfig.Admins`) get a **CLOSE LOBBY (TEST)** button (top right) to go into the match for testing,
  and a small **LOBBY** button (top right) to reopen it. Other players cannot leave the lobby yet.

## For the friend / ChatGPT
- Don't build another lobby UI; the friend's earlier 3D lobby plan is replaced by this 2D screen.
- Lobby systems (unit shop, LOADOUT, levels, Gem currency, saving) belong to the owner; propose ideas via your user.
- If your scripts show UI on join, check `player:GetAttribute("InLobby")` and stay hidden while it is true.
