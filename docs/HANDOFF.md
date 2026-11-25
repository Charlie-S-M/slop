# Handoff

Where the Pew Incremental expansion stands, so a new session can pick up without the old
conversation. Update the **Status** column and **Now** section whenever an item lands.

## Now

- Item 2 is built on branch `feat/top-tier-guns-and-effects` (stacked on `feat/pew-incremental`),
  and its final review is in progress. Next up is **item 3, armor**, on a branch stacked on item
  2's.
- What item 2 added:
  - the Eternal tier, gated behind Glasscore, with the Dawnbringer and Everlight Cannon guns;
  - firing styles in `Shared/ShotStyles.luau`;
  - impact frames in `Controllers/Cutscene/ImpactFrames.luau`, which armor and chests can reuse
    by calling `ImpactFrames.play(tier, model, screen, world)`.
- `feat/pew-incremental` is PR #1 (Charlie-S-M/slop#1) with Auto-fix on. Merging it to `main`
  publishes to staging. Later branches stack on it; rebase them after it merges.
- Nothing past PR #1 is pushed.

## Roadmap

The person set this order. Names, drop rates, and growth numbers are proposals to playtest.

| # | Item | Status |
|---|------|--------|
| 1 | Glassfall Foundry (stages 61–70) and evolving Legendary+ guns | Done, PR #1 |
| 2 | Higher-tier guns and Legendary+ effects | Built, in review |
| 3 | Armor at the forge | Not started |
| 4 | Pets | Not started |
| 5 | Stages 71–80 and collection goals | Not started |
| 6 | Infinite Tower at 1B Power | Not started |
| 7 | Attachments and boss chests | Not started |
| 8 | Upgrade caps ×3–×4 | Not started |

What each item should let a player do:

2. **Higher-tier guns and Legendary+ effects.** Each top rarity (Legendary, Mythic, Godly, and the
   new tier) fires with its own effect. The first post-Godly guns can be forged, but only with a
   new-region ingredient: the forge rolls up to one tier above its best ore, so without a gate a
   new tier would be reachable with Godly ores at once. Forge reveals for Legendary, Mythic, and
   Godly get impact frames:
   - Legendary: gold silhouette and an ember shockwave.
   - Mythic: particles pull inward, then a violet burst.
   - Godly: the scene darkens and a prismatic halo opens behind the item.
3. **Armor at the forge.** Craft a chestplate, compare it with equipped gear, and see how much
   damage it prevents. Helmets and boots follow. Legendary+ armor uses the same impact frames.
4. **Pets.** Earn and equip a companion for better ore drops, faster training, or bonus damage. The
   exact bonus shows before equipping.
5. **Stages 71–80 and collection goals.** A second new region with armor recipes and evolution
   materials. The Index shows where things drop; a training dummy compares builds. Adding a region
   moves the Ascension loop, so returning players past stage 70 need a migration.
6. **Infinite Tower at 1B Power.** Unlocks at 1B Power. Escalating floors, permanent checkpoint
   bonuses, resume after leaving. Tower bosses also give chests (item 7).
7. **Attachments and boss chests.**
   - Every weapon, Commons included, can equip a scope, grip, barrel, magazine, and keychain. Each
     part changes the look, and the equip preview shows its stat effect. Parts carry over when a
     gun evolves.
   - Every boss clear, repeats and Tower bosses included, gives a chest: 95% coins, 5% attachment.
   - An attachment opens a scrolling reel that slows and stops on the part. Rarity odds: Common 50,
     Uncommon 25, Rare 15, Epic 5, Legendary 3.9, Mythic 1, Godly 0.1 (%).
   - The upgrade menu gets **Attachment Luck**, which improves the reel's rarity. The 5% chest
     chance stays fixed.
   - Legendary, Mythic, and Godly reel results use the item-2 impact frames.
8. **Upgrade caps.** 4× the cap for Ore Bag, Training Boost, Toughness, and Coin Boost; 3× for
   Forge Luck, Swift Boots, and Ore Magnet. Tune prices above the old caps so the new levels can be
   reached.

## How the work runs

- Each item: a short design in `docs/superpowers/specs/`, a plan in `docs/superpowers/plans/`, then
  build task by task with a failing spec first. A fresh reviewer checks the whole branch at the end.
- `CLAUDE.md` has the commands that must pass. Specs run in Studio.
- **Syncing into Studio without `rojo serve`** (what these sessions use):
  1. `tools/studio-sync/sync.ps1 -Parts shared,server,client` formats, lints, and builds models into
     `build/studio-sync/`.
  2. Import each `.rbxm` into `ServerStorage.__Sync` with the Studio MCP's `import_rbxm`.
  3. Run `require(game.ServerStorage.__SyncApply)()` in Studio.
  4. Specs: `require(game.ServerStorage.__RunSpecs)()`.

  `__SyncApply` and `__RunSpecs` are ModuleScripts that live only in the Studio place. Their
  source is in `tools/studio-sync/`, so you can recreate them if the place loses them.
- Playtest with the MCP's `solo_playtest`, `eval_server_runtime`, and `eval_client_runtime`.
  `capture_screenshot` doesn't show AlwaysOnTop billboards.
- Blender 2.93 runs headless:
  `"C:\Program Files\Blender Foundation\Blender 2.93\blender.exe" -b --python tools/blender/<Id>.py`.
  Models follow the `ForgeModels` part roles (Handle, Body, Shell, Stock, Metal, Tip, Glow,
  Crystal), barrel toward −X, grip at the origin, about 4 studs long.

## Waiting on the person

- Import the five evolved-gun FBX files from `assets/models/` into `ReplicatedStorage.ForgeModels`
  with Studio's 3D Importer, named by gun id, then refresh `ForgeModels.rbxm`. After that, check
  that they sit right in hand.

## Known small issues

- The Forge tab shows "No ores yet!" twice.
- The Evolve tab's "Need X more coins" text doesn't refresh on `StatsChanged`.
- The Glassheart count only shows on the Evolve tab.
- The material pickup message always says "Glassheart".
- Ship with "migrate to latest update". Old servers drop `materials` and `bossesDefeated` from
  saves.
