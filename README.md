# TroyHub

Single-game hub for **Humanlife 3: Civilization**. Modular source for development; one inject file at runtime.

This is a game hub, not a general-purpose framework. Future games would add a feature pack later — not more layers now.

## Layout

```
src/core/        runtime: utils, logger, state, scheduler, cleanup, theme, lifecycle, features, hotkeys
src/features/    movement, utility, combat, farming, esp
src/ui/          window, tabs, settings/status pages
src/config/      version/data + optional JSON save/load
src/init.lua     boot
```

Edit `src/`. Run `tools/bundle.ps1`. Inject `TroyHub.lua` (GitHub name: `Humanlife3CivilizationSCRIPT`). Do not hand-edit the bundle.

## What stays simple

- **Features:** `register` + enable/disable/cleanup. No dependency or conflict graph.
- **Lifecycle:** unload, respawn, character added, camera changed.
- **State:** one settings table with clamps. `_` keys are not saved.
- **Config:** optional `TroyHub_config.json`. No profile/persistence framework.
- **Scheduler + cleanup:** kept. They prevent leaks and frame spikes.

## Build

```powershell
powershell -File tools/bundle.ps1
```
