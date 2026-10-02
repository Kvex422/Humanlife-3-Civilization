# TroyHub

Roblox hub for **Humanlife 3: Civilization**. Source of truth is this `src/` tree. The inject file is generated.

## Source vs inject

| Path | Role |
|------|------|
| `src/*.lua` | Canonical source. Edit these. |
| `tools/bundle.ps1` | Build. Concatenates modules into one executor script. |
| `TroyHub.lua` | Generated bundle. Do not hand-edit. |
| `Humanlife3CivilizationSCRIPT` (GitHub) | Same generated inject, kept at that name so raw URLs keep working. |
| `tools/generate_app.py` | Leftover one-shot extractor. Not part of the build. |

Never edit the bundled inject by hand. Changes there are overwritten the next time you bundle.

## Build

From this folder:

```powershell
powershell -File tools/bundle.ps1
```

That writes `TroyHub.lua` and copies it to `Desktop\Learning Luau Example.lua.txt`.

Compile check (optional):

```powershell
& "$env:TEMP\luaubin\luau-compile.exe" --binary .\TroyHub.lua > $null
```

## Architecture

- `--!strict` Luau modules, Hub-bag DI (`return function(Hub)`).
- **Registry** (`Hub.Registry.enable/disable/toggle`) is the only feature toggle path. UI, hotkeys, config reload, and Unload all go through it.
- Feature bodies live in `src/features/` (movement, utility, esp, combat, farming).
- **Lifecycle** bus: `ready`, `beforeUnload`, `unload`, `afterUnload`, `respawn`, `pageOpened`, `pageClosed`, `settingsReloaded`, `featureEnabled`, `featureDisabled`.
- `Hub.PageScope` is page-scoped connections/debris. `Hub.State` is persisted settings. `Hub.Runtime` is session handles (debug log, status labels). `Hub.Config` is JSON save/load.

## Version

See `src/data.lua` (`Version.script`).
