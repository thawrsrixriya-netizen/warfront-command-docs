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

## Behaviour today
- PLAY opens the map screen above; **UNIT, SHOP, TRADE, Settings, Leaderboard do nothing yet** (hover only), and
  NEXT on the map screen does nothing yet. The owner designs each screen next.
- While open it covers the match and swallows game keys (1–6, M, WASD, arrows, Space, Q, E, Z, F, T, C, G, X), so
  nothing happens in the match behind it. Player attribute `InLobby` = true while open.
- Admins (`EconomyConfig.Admins`) get a **CLOSE LOBBY (TEST)** button (top right) to go into the match for testing,
  and a small **LOBBY** button (top right) to reopen it. Other players cannot leave the lobby yet.

## For the friend / ChatGPT
- Don't build another lobby UI; the friend's earlier 3D lobby plan is replaced by this 2D screen.
- Lobby systems (unit shop, LOADOUT, levels, Gem currency, saving) belong to the owner; propose ideas via your user.
- If your scripts show UI on join, check `player:GetAttribute("InLobby")` and stay hidden while it is true.
