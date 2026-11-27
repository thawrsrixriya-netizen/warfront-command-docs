# Minimap (owner) — `StarterPlayerScripts.MiniMap`, `ReplicatedStorage.MiniMapConfig`, `ServerScriptService.MiniMapServer`

- Round, 150 px, top-left, north (-Z) up, does not rotate. Click → big round map in the screen centre: drag to move,
  wheel to zoom, click outside or press X to close (X belongs to the map while it is open).
- World area = bounding box of `Workspace.GroundAndTrenches`, measured on the SERVER (`MiniMapServer` →
  Workspace attributes `MiniMapCenter` / `MiniMapSize`), because a client may not have the whole map streamed in.
  New map: set `MiniMapConfig.GroundModel` (or `Center` / `Size` by hand).
- Shown:
  - Your units (blue) and other players' units (green): Models in `Workspace.CommandTanks` (square turned to its
    heading) and `Workspace.CommandInfantry` (one dot per `OwnerUserId` + `InfantrySlot`), using attribute `OwnerUserId`.
  - Enemies only when their model has `Spotted = true` (vision system).
  - Bases from `Workspace.MatchPoints` (`PlayerBase`, `CenterBase`, `EnemyBase`); the centre marker is blue/red by owner.
- To show something new, add a collector to `MiniMap.Collectors` (inside the MiniMap script) that appends
  `{ Position = Vector3, Color = Color3, Shape = "Dot"|"Square"|"Diamond", Size = px, Heading = degrees? }`.
- Roblox UI cannot reliably clip to a circle (CanvasGroup falls back), so the ground is drawn as thin strips.
- `WarClient.CameraJump.lookAt(worldPosition)` moves the camera there (not used by the map now).
