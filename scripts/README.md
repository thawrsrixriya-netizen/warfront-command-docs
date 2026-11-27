# scripts/ — read-only snapshot of the game's scripts

Claude exports the game's scripts here from Roblox Studio so ChatGPT can read real code:
`ServerScriptService`, `ReplicatedStorage`, `StarterPlayer`, `StarterGui`, `StarterPack`
(not ServerStorage backups and not scripts inside Workspace models). The folder tree mirrors the Roblox tree,
one `.lua` file per script; the first line says the full Roblox path and the class.

- This is a snapshot. Each export is listed in CHANGELOG.md with the place version it came from.
- **Never edit these files to change the game.** To change a script, ask your user for the live copy from Studio
  (RULES.md §2) and give the change to your user.

This repository is PUBLIC: player UserIds (e.g. the admin list in EconomyConfig) are replaced with `0` in this
snapshot. The real values exist only in Roblox Studio. Never commit passwords, API keys, webhooks or personal data here.

File names: `<Name>.server.lua` = Script, `<Name>.client.lua` = LocalScript, `<Name>.lua` = ModuleScript.

Last export: 2026-11-27, 89 scripts (place version after v405).
