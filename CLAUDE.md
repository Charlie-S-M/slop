# CLAUDE.md

Pew Incremental, a Roblox incremental shooter kept in Git and synced into Studio by Rojo. Each place
in the experience is a folder under `places/`, holding its Rojo project (`default.project.json`)
and its code (`src/`); the game is `places/main`. pesde installs packages from `pesde.toml` into
`roblox_packages/` (`ReplicatedStorage.Packages`) and Jest from `test_packages/pesde.toml` into
`ServerScriptService.Tests.Packages`. `README.md` describes the game loop and where each system
lives.

## Module layout

- `ReplicatedStorage/Shared` holds plain modules both sides require directly: game data, formulas,
  builders, and `Net` (the one list of remotes, created by the server). Every progression number
  lives in `Balance.luau`.
- The Module Loader runs systems with `Init` then `Start`. Each `Start` script passes its folder to
  `ModuleLoader.Start` directly: `ServerScriptService/Modules/Server` on the server,
  `StarterPlayerScripts/Controllers` on the client. Tag discovery stays off, because it would also
  find the template copy of `Controllers` left in `StarterPlayerScripts` and load every controller
  twice. A new system is a ModuleScript in one of those folders.
- The loader reads `LoaderPriority` from an attribute, so set it in a sibling `<Module>.meta.json`
  (`{ "attributes": { "LoaderPriority": 100 } }`). A `LoaderPriority` field on the module table
  does nothing. Modules other systems need during `Init` (`PlayerData`, `ClientState`, `Menus`,
  `WorldSetup`) carry one.
- The world is built from code out of studded bricks (`Modules/Server/World`). The lobby is baked
  into the place file as `Workspace.Lobby`; `WorldSetup` builds it at server start when it's
  missing, and sets lighting and sky from code.

The `roblox-dev` plugin's skills hold this project's conventions: Luau style, comments,
architecture, Rojo, testing, performance, and UI. Load the matching skill before the first edit.

## Commands

Run everything from the repo root.

- `rokit install` after `rokit.toml` changes, and `pesde install` after either `pesde.toml` changes.
- `rojo serve places/main/default.project.json` syncs a place into Studio. Connect from the Rojo
  plugin in your own dev place for it.
- Specs run in Studio against the dev place, once Rojo has synced the files.

A change is done when these all pass, for each place it touches (shown for `main`; use the place's
folder name instead):

```
rojo build places/main/default.project.json -o game.rbxl
rojo sourcemap places/main/default.project.json -o sourcemap.json --absolute
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions:@roblox=globalTypes.None.d.luau --ignore="**/roblox_packages/**" places/main/src
selene places tools
stylua --check places tools
```

Run each one as its own command, with nothing chained before or after it (no `; echo $?`). The
project's settings let these five run without asking only in exactly this form. The sourcemap
needs `--absolute`: Rojo writes paths relative to the place folder, and luau-lsp reads them
relative to the repo root.

`luau-lsp analyze` reads Roblox's types from `globalTypes.None.d.luau`. Download it once, and again
to pick up new engine APIs:
`curl -L -o globalTypes.None.d.luau https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau`

## Places

`places.json` maps each place folder to its place in each experience: the CI, staging, and
production universe ids, and each place's id in each of them. CI tests and publishes every place
listed there, so the three experiences need the same places. `null` means not set up yet, and the
jobs for that experience skip. Staging publishes only after the specs pass, so it also waits for
the CI experience. A place has a different id in each experience; ids are in the Creator
Dashboard URL, `.../experiences/<universe id>/places/<place id>/...`.

To add a place:

1. The person creates the place in each experience (Creator Dashboard, the experience's
   **Places** tab) and gives you its three place ids. Don't guess them.
2. Copy `places/main` to `places/<name>`, using a lowercase name with letters, digits, `_`, or
   `-`. Change the project's `name`, then remove the code and specs that belong only to `main`.
   Keep the `Start` scripts, the `Tests/Packages` project, and `Tests/Specs/jest.config.luau`.
   Keep or write at least one spec: CI fails a place whose `Tests/Specs` is missing or empty.
3. Add `"<name>": { "ci": <id>, "staging": <id>, "production": <id> }` under `places` in
   `places.json`.
4. Run the checks above for the new place. `lune run tools/ci/build` builds every place and fails
   when `places.json` and the folders disagree, or a set-up experience lacks a place's id.

Code two places share goes in a folder outside `places/` (for example `shared/`), mounted into
each place's project with a relative `$path` (`"../../shared/..."`). Add that folder to the
`selene` and `stylua --check` commands.

VS Code's luau-lsp types one place at a time, set by `luau-lsp.sourcemap.generatorCommand` in
`.vscode/settings.json`. Change its place folder to work on another place.

## CI

`.github/workflows` runs the checks above for every place and every place's specs (through Open
Cloud, in the CI experience) on each pull request. **Merging to `main` publishes every place to
the staging experience**, and publishing a GitHub release publishes them to production.
`tools/ci/README.md` covers the setup and what each failure means.

## Project specifics

- Rojo is pinned in `rokit.toml` (7.7.1) and in the `rojo` dev dependency in `pesde.toml` (7.7.0,
  the newest on pesde's registry). Change both together.
- Rojo 7.7.x can crash `rojo serve` when a folder is deleted or a folder module becomes a file
  module. Check that `rojo serve` is still running after those changes, and restart it if not.
- Write `IconTint` in a `.meta.json` with its type, `"IconTint": { "Color3": [1, 0, 0] }`. Every
  Rojo version accepts that form; 7.6.1 rejects the short one.
- `Workspace` sets `$ignoreUnknownInstances` and syncs no files, so Rojo leaves the baked lobby
  and anything else built in Studio alone. Those stay out of Git; the builders are the source of
  truth for the world.
- Each place's `src/ServerScriptService/Tests/Packages/default.project.json` mounts
  `test_packages/roblox_packages` at `Tests.Packages`. Keep it in place.
