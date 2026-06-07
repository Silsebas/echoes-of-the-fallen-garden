# Agent Instructions for echoes-of-the-fallen-garden

This repository is a Roblox project managed by Rojo and Aftman.

## Key project facts
- Root `README.md` documents the `rojo build`/`rojo serve` workflow.
- `aftman.toml` pins the Rojo tool version (`rojo-rbx/rojo@7.7.0-rc.1`).
- `default.project.json` is the Rojo project mapping for the Roblox place.
- Source code lives under `src/`:
  - `src/client/` → `StarterPlayerScripts/Client`
  - `src/server/` → `ServerScriptService/Server`
  - `src/shared/` → `ReplicatedStorage/Shared`

## Recommended workflow
- Do not edit Roblox binary/place files directly in source control.
- Make changes in `src/`, then run the Rojo build and serve workflow from `README.md`.
- When possible, use the pinned Rojo version via Aftman:
  - `aftman install`
  - `aftman run rojo build -o "echoes-of-the-fallen-garden.rbxlx"`
  - `aftman run rojo serve`

## What agents should do first
- Identify whether code belongs on the client, server, or shared layer.
- Preserve the existing Rojo tree mapping in `default.project.json` if new source files are added.
- Keep changes minimal and Roblox-friendly: use `ModuleScript`-style shared code under `src/shared`, and leave service placement intact.

## What agents should avoid
- Avoid restructuring the repository without good reason.
- Avoid editing or generating `.rbxlx` files directly in version control.
- Avoid assuming a standard web or node app layout; this is a Roblox source tree.

## Useful links
- [README.md](README.md)
- [Aftman](https://github.com/LPGhatguy/aftman)
- [Rojo docs](https://rojo.space/docs)
