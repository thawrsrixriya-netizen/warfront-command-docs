# Warfront Command — shared docs (READ THIS FIRST)

Warfront Command is a Roblox real-time strategy game made by **two developers**, each with an AI assistant:

| Developer | GitHub | AI assistant | Works on |
|---|---|---|---|
| Owner | `thawrsrixriya-netizen` | Claude | UI/HUD, camera, input, damage, skills, and the core match systems (waves, money/points, capture, vision, minimap, shop, lobby systems, saving) |
| Friend | `nachatalim5-byte` | ChatGPT | the map, 3D lobby, all units and unit systems (tanks, BMP, infantry, new units), bot AI, sounds, visual details |

This repository is the **single source of truth** both AIs read. Claude updates it every time the owner changes
a core system. ChatGPT reports its own big changes back through GitHub Issues.

## If you are ChatGPT: what to do every time your user gives you a task

1. Open [`CHANGELOG.md`](CHANGELOG.md). Read every entry newer than the last one you saw.
   Tell your user, in short: what changed, and **whether it affects the task they just gave you** (and how).
2. Before touching a system, read its page in [`systems/`](systems/) — it says which scripts exist, which
   attributes / functions you may use, and what you must not change.
3. Follow [`RULES.md`](RULES.md) for every change (live copy first, SHARED blocks, reserved keys, ...).
4. Code in [`scripts/`](scripts/) is a **read-only snapshot** of the game scripts for reference. It may be a few
   hours old. Before editing a script, still ask your user for the live copy from Roblox Studio (RULES.md §2).
5. When your user finishes a **big change** (new system, new unit, changed shared contract, changed a
   script the other developer owns, renamed/moved anything others use): write a change report using the
   template in [`.github/ISSUE_TEMPLATE/change-report.md`](.github/ISSUE_TEMPLATE/change-report.md) and ask your
   user to post it as a new Issue (label `change-report`). Claude reads open change reports, summarizes them
   for the owner, replies, and closes them.

## Layout

```
README.md          this file
RULES.md           collaboration rules both AIs follow
CHANGELOG.md       every change to the game's core systems, newest first
systems/           one page per system: files, how to use it, what not to change
  hud-and-input.md   MatchHUD, InputMode, UnitSlots, SkillActions, reserved keys
  map-points.md      Workspace.MatchPoints names (bases, zone, enemy paths)
  vision.md          shared sight + infantry auto-fire
  economy.md         money, points, prices, cooldowns
  skills.md          SU-34, FPV, AC-130
  aircraft.md        shooting down player aircraft (for AA / bots)
  unit-panel.md      left unit command column
  minimap.md         round minimap + big map
  capture.md         centre base capture
  waves.md           enemy waves (placeholder bots)
  lobby.md           2D lobby screen (shown on join)
scripts/           read-only snapshot of the game's scripts (see scripts/README.md)
.github/ISSUE_TEMPLATE/change-report.md   how ChatGPT reports big changes
```

## Current state (keep short; details in CHANGELOG)

- Place: **Warfront Command**, Roblox Team Create (both developers edit the same place live).
- Map: first real map by the friend (`Workspace.GroundAndTrenches`), player spawn at the north end, centre base
  in the middle, three enemy roads (south, west, east).
- Match flow today: capture the centre → wave 1 starts → waves until victory. No lose condition yet (player base
  not built). Enemy units are yellow placeholder dummies until the friend's bots exist.
- Test mode: every player starts with 9999 money / 9999 points (`EconomyConfig.TestMode`).
