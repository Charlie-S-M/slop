# Handoff for Codex

Pew Incremental (shown in game as "Gun Exponential!") is a Roblox incremental shooter. You
can see it top-down as 2D pixel art: the 3D parts are still there for physics and hits, but
`Controllers/Birdseye.luau` hides them and draws pixel icons over them. The forging cutscene
alone stays 3D. Read `CLAUDE.md` for the layout, Rojo, and the checks every change must pass;
this file covers where things stand and what you need to know that the code doesn't say.

## Where things stand

- Work is on `feat/hotbar-and-armor-models`, 80+ commits ahead of `main`, **not pushed**. Older
  roadmap branches stack under it (`feat/pew-incremental` → … → `feat/upgrade-caps`); this
  branch contains all of them. Commit freely; ask the person before pushing.
- All 123 specs pass in Studio. `docs/HANDOFF.md` has the full history and roadmap.
- The Studio place is the source of truth for things built in Studio (the baked lobby,
  `ReplicatedStorage.ForgeModels` imports). The person saves it; code changes reach it by syncing.

## Your first task: the shop UI

The person asked for the shop UI to be redone by you. Everything behind it works and is tested;
change the look, keep the contract.

- The menu is `Controllers/Menus/Shop.luau`. It opens at the shop stall south of the forge
  (station `Shop`) and has no on-screen button, on purpose.
- The reference the person gave: a shop like other popular Roblox simulators. Colored section
  tabs down the left; a scrolling purple page; big wide cards for Featured items with a
  "LIMITED · ends in" countdown; 3-across cards for passes and packs; a green price button on
  each card; cash and coin art around the frame.
- Data the UI reads (don't change these shapes without updating the server):
  - `Shared/Products.luau`: `Products.List` (every item: `key`, `kind` "product"/"pass",
    `section`, `name`, `description`, `glyph`, `color`, `price`), `Products.SECTIONS` (tab
    order, labels, glyphs, colors), `Products.POTIONS` (potion key → boost name),
    `Products.LIMITED_ENDS` (the limited guns' sale end, os.time).
  - `Shared/PackValues.luau`: `PackValues.amount(profile, key)` returns what a Power or Coin
    pack gives this player right now. Show it on those cards ("You get ⚡ X"), refreshed as the
    profile changes. The server grants the same number.
  - Profile (`ClientState.profile`): `potions[key]` owned, `boosts[name]` end times,
    `luckyForges`, `starterPackBought`.
  - Owned passes are player attributes `Pass_<key>` (true). Server Luck's end time is the
    `ServerLuckUntil` attribute on ReplicatedStorage.
- Actions the UI calls: `UI/Purchases.prompt(key)` for any buy (it prompts the real product or
  pass, or toasts "not for sale yet"); `Net.event("UsePotion"):FireServer(key)` to use a potion.
- Owned passes show as owned and can't be bought again; the Starter Pack shows as bought.
- Check it at phone size too (Studio's device emulator).

## Monetization facts

- The experience is universe **10779068698**, owned by the group FarSource Development. All 11
  game passes and 26 developer products exist and are on sale; their ids are in
  `Products.luau` (`IDS`). A spec checks every product has a unique id there.
- `Modules/Server/Shop.luau` grants products through `ProcessReceipt` (once per receipt id,
  kept in `profile.receipts`) and checks passes on join and purchase. Studio test purchases
  work and don't charge; they report 0 Robux spent, so the Robux Spent board only moves live.
- Creating or editing products uses an Open Cloud key in the `ROBLOX_OPEN_CLOUD_API_KEY`
  environment variable. The person manages that key; never ask for it in chat or write it
  anywhere.

## Systems added recently (where to look)

| System | Files |
|--------|-------|
| Passes and potions in play | `Modules/Server/Boosts.luau` (the only place gameplay asks about them) |
| Purchases, potions, Lucky Wheel spins, Auto Rebirth loop | `Modules/Server/Shop.luau` |
| Lucky Wheel | `Shared/Wheel.luau`, `Menus/Wheel.luau`, stand in `LobbyBuilder.wheelStand` |
| Quests (knight SIR PEW) | `Shared/Quests.luau`, `Modules/Server/QuestKeeper.luau`, `Menus/Quests.luau` |
| Settings and codes | `Modules/Server/Settings.luau` (codes live here, server only), `Menus/Settings.luau` |
| Leaderboard tabs | `Modules/Server/Leaderboard.luau` (ordered data stores), `Menus/Leaderboard.luau` |
| Prestige (warning window, full reset) | `Economy.luau` `onPrestige`, `Menus/Progress.luau` |
| Boost icons, top right | `Controllers/BoostBar.luau` |
| Intro screen | `Controllers/Intro.luau` |
| Stages 81–250, tiers Celestial/Cosmic/Omega | `Shared/Biomes.luau` (`generated`), `Ores.luau`, `Rarity.luau`, `Balance.TIER_KEYS` |
| Tier cutscene (tiers 9–11) | `Controllers/Cutscene/TierCutscene.luau` |
| Gun focus (Damage, Training, FireRate) | `Guns.FOCUS`, `Balance.focusTuning` / `focusTraining` |

Saved-profile fields are added with defaults in `PlayerData.defaultProfile`; `reconcile` fills
missing ones, so old saves load without a migration. Nested `settings` keys are filled too.

## Balance knobs the person may ask about

All in `Shared/Balance.luau` unless noted: `ORE_DROP_CHANCE` (0.15) and `BOSS_ORE_DROPS` (2);
prestige rewards (`prestigeDamage`/`Ores` = 2^n, `prestigeLuck`); growth past stage 80
(`GROWTH_SHIFT_STAGE` and the `shifted(...)` factors in `enemyHealth`/`enemyDamage`/
`enemyCoins`, first guesses still to playtest); `GUN_DAMAGE_TIERS`; `FOCUS_*`; pack minutes in
`PackValues.luau`.

## Working in Studio

- With the Studio MCP: `tools/studio-sync/sync.ps1 -Parts shared,server,client` builds
  `build/studio-sync/*.rbxm`; import each into `ServerStorage.__Sync`, then run
  `require(game.ServerStorage.__SyncApply)()`. Specs: `require(game.ServerStorage.__RunSpecs)()`.
  Without it, `rojo serve places/main/default.project.json` works too (see `CLAUDE.md`).
- Edits made directly in Studio must be pulled back before the next sync, or the sync
  overwrites them: export with the MCP's `export_rbxm`, then
  `lune run tools/studio-sync/pull.luau <file.rbxm> places/main/src`.
- `ReplicatedStorage.ForgeModels` comes from `places/main/src/ReplicatedStorage/ForgeModels.rbxm`.
  After importing a model in Studio, re-export that folder into the file.
- Studio's screenshot tool doesn't show AlwaysOnTop billboards (all pixel icons); use a real
  screen capture to see them. Simulated mouse moves often don't reach Studio, so hover effects
  need a real mouse to check.

## Gotchas

- luau-lsp's new solver widens string literals and mixed tables: give records explicit types
  and wrap `pcall` targets in a closure.
- A GuiObject rotates around its own center, not its AnchorPoint. To spin things around a
  wheel's center, put each in a full-size frame and rotate that (see `Menus/Wheel.luau`).
- Some ScreenGuis use global ZIndex layering; a backdrop with a high ZIndex hides its own
  children there. Give backdrops the lowest layer.
- `Kit.text` passes every prop to the TextLabel except its own options (`Stroke`,
  `StrokeColor`, `Gradient`, `MaxTextSize`, `Parent`); add a new option to that skip list.
- Billboards in the 2D view must draw at any distance (`MaxDistance = math.huge`) and be pinned
  to the floor (`floorBelow` in `Birdseye.luau`) or they drift as the camera moves.

## Open items

- One request arrived empty ("for forging,"); ask the person what they meant.
- Gun evolutions exist for Legendary to Eternal; the Celestial, Cosmic, and Omega guns have none.
- New regions past stage 80 have no new eggs or pets yet, and the new guns have no Blender
  models (the 3D forge scene uses the brick builder for them).
- Product and pass icons are Roblox defaults; the person can upload art in the dashboard.
