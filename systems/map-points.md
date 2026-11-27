# Map points (`Workspace.MatchPoints`)

Every map has a Folder `Workspace.MatchPoints`. Core systems find things here **by name** — do not rename or move
them. The friend places them on each map; the owner's scripts read them.

| Name | Type | Used by | Notes |
|---|---|---|---|
| `CenterBase` | Part (anchored, CanCollide off) | CaptureServer, MiniMap, WaveServer | the capture zone; only its X/Z footprint matters. Hidden in game. Current map: 141 × 169 studs at (-74, 39). |
| `EnemyPaths` | Folder | WaveServer | one sub-folder per road, e.g. `Path1_South`, `Path2_West`, `Path3_East`. Inside: waypoint Parts named `1`, `2`, `3`… in walking order. `1` = spawn at the map edge, last = centre. Hidden in game. |
| `PlayerBase` | Part or Model | MiniMap (marker) | not placed yet |
| `EnemyBase` | Part or Model | MiniMap (marker) | not placed yet |

Planned names (not used by code yet): `PlayerSpawn`, `EnemySpawn1-3`, `RepairShop`, `Trench`.

Other map facts the code uses:
- Ground model: `Workspace.GroundAndTrenches` (minimap size, capture outline, enemy path heights). For a new map,
  change `MiniMapConfig.GroundModel` and `CaptureConfig.GroundModel`.
- Player spawn (current map): north end of the main road (`SpawnLocation` near (-33, -362)).
- StreamingEnabled is on (radius 1024): clients may not have far parts. Core systems publish what clients need as
  ReplicatedStorage / Workspace attributes.
