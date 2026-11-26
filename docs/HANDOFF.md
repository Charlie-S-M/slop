# Handoff

Where the Pew Incremental expansion stands, so a new session can pick up without the old
conversation. Update the **Status** column and **Now** section whenever an item lands.

## Now

- **Item 2 is done** on branch `feat/top-tier-guns-and-effects`, stacked on `feat/pew-incremental`.
  It has been reviewed, and its one Important finding (an aborted reveal leaving the shade and
  card up) is fixed.
  - It adds the Eternal tier, gated behind Glasscore, with the Dawnbringer and Everlight Cannon
    guns.
  - It adds firing styles in `Shared/ShotStyles.luau`.
  - It adds impact frames in `Controllers/Cutscene/ImpactFrames.luau`. Armor and chests reuse them
    by calling `ImpactFrames.play(tier, model, screen, world, alive)`, where `alive()` returns
    false once the caller's cutscene is gone.
- **Item 3, armor, is done** (branch `feat/armor`). It was reviewed, and the Important finding, a sell-price coin loop, is fixed: a piece records the sell value of its ores in `worth` and sells for 60% of it.
- **Item 4, pets, is done** on branch `feat/pets`, stacked on armor:
  - eggs bought in the Pets menu, three pets equipped at most;
  - Training, Damage, and Ores bonuses applied in `Combat` and `Arena` through `PetStats.multiplier`;
  - pets drawn locally by `PetFollow`.
- **Item 5 is done** on `feat/aurora-reach`. It adds Aurora Reach (stages 71–80) and the Aurora Shard; tempering armor at the forge; drop notes in the Index; and a client-side training dummy by the forge. It also carries the pets review fixes, including a shutdown-save fix in `PlayerData`.
- **Item 6 is done** on `feat/infinite-tower`: the Tower opens at 1B Power from the Gauntlet menu. Floor N plays as stage 70+N, and every 10 floors gives +10% training and coins.
- **Item 7 is done** on `feat/attachments`:
  - boss chests, the reel, and Part Luck;
  - the Backpack Parts tab;
  - parts drawn on guns;
  - `GunStats.effective` applies parts everywhere.
  Its review was still running when this was written.
- **Item 8 is done** on `feat/upgrade-caps`: caps are ×4 and ×3, with soft caps past the old maximum.
- **The game is 2D now.** Another assistant ("chat") did items 11–16 directly in the Studio place. That work was pulled into the repo in commit 70efda7:
  - 11: a bird's-eye pixel-art world, drawn by `Controllers/Birdseye.luau` as BillboardGui icons over the 3D parts, which stay for movement and hits;
  - 12: Tower crystal-defense waves;
  - 13: combat and pet fixes;
  - 14: zoom and longer breaks;
  - 15: Eternal evolutions;
  - 16: `FarmAnimals.luau`.
  The forging cutscene stays 3D. If the place is ever edited directly again, pull it into the repo before syncing. ``tools/studio-sync/pull.luau` does this by exporting the code containers with the MCP `export_rbxm` and writing each Source back with Lune.
- **Done on `feat/hotbar-and-armor-models`, after the 2D pull:**
  - steady icons (ground-pinned scenery and a high, narrow camera);
  - avatars hidden through Transparency;
  - player walk frames;
  - Aurora Shards for Eternal evolutions;
  - ×1/×5/×10 upgrade buying;
  - Toughness up to 1000 levels;
  - Prestige at rebirth 15 (1.5× damage, +10% forge luck, +25% ores, stacking);
  - a skip-wait countdown bar for stages and Tower waves.
- **Items 9 and 10 are done in code.**
  - Blender scripts (`tools/blender/Armor*.py`, `SmithyInterior.py`) export to `assets/models/`.
  - `ArmorBuilder` and `ForgeSet` use those models from `ReplicatedStorage.ForgeModels` (`ArmorHelmet`, `ArmorChestplate`, `ArmorBoots`, `SmithyInterior`). They were imported into the place on 2026-11-25. Without them, the builders fall back to bricks.
  - The lobby's sell counter is removed, in `LobbyBuilder` and in the baked lobby.
- The "equip items station" was the Upgrades stall; it is removed. Upgrades open from the HUD button (U).
- All branches stack in order: pew-incremental → top-tier → armor → pets → aurora-reach → infinite-tower → attachments → upgrade-caps.
- The test profile in Studio keeps three hatched pets and a Copperplate Chestplate. Its coins were restored after testing.

## Current batch (2026-11-25): monetization, settings, quests

The person's list, with their answers to the open questions. Branch: `feat/hotbar-and-armor-models`.

| Item | Status |
|------|--------|
| Side buttons restyled like the loadout bar (only the side buttons, not menu windows) | Done, b60b0f2 |
| Intro screen (sunburst, hammer on anvil, title, loading bar, tips, click to skip) | Done, b60b0f2 |
| Training dummy label sized in studs; wall torches centered on their wall; pet click freeze | Done, b60b0f2 |
| Leaderboard tabs: Power (server), Robux Spent, Playtime, Forged (all-time ordered stores) | Done, 031fc8c |
| Settings: auto auto mode, auto skip wave, SFX and music volume, codes (music button moved here) | Done, 031fc8c |
| Quests like the reference (Daily, Challenge, swap, New Quests for Robux, rank, daily chest), with a 3D voxel knight instead of "Sarge" | Done, 33761c5 |
| Shop station near the forge (walk to it, cash and $ effects that fade), shop menu like the reference: Featured + limited guns, Passes, currency and boosts (power, coins, eggs, Server Luck, Lucky Forge), Potions (new timed-boost inventory) | Done, 2111d56 |
| Lucky Wheel station: a free spin a day, paid spins (1/3/10), 0.5% exclusive gun | Done, f24009a |
| Enemies spawn at least 40 studs from the player | Done, 626bc3f |
| Stages up to 250, one new rarity per 50 stages past 80, balanced damage, a cutscene for each new rarity (added while the person was away) | Done, 3f30f73 and the next commit |
| Create the real developer products and game passes ("create them now") | Blocked on an Open Cloud key |

Codes: `release`, `update_0`, `pewpew`, `forgefire`, `thankyou`; `dev_everything` is the testing kit
(Studio or the owning group's rank 255 only). They live in `Modules/Server/Settings.luau`.

## Roadmap

The person set this order. Names, drop rates, and growth numbers are proposals to playtest.

| # | Item | Status |
|---|------|--------|
| 1 | Glassfall Foundry (stages 61–70) and evolving Legendary+ guns | Done, PR #1 |
| 2 | Higher-tier guns and Legendary+ effects | Done, `feat/top-tier-guns-and-effects` |
| 3 | Armor at the forge | Done, `feat/armor` |
| 4 | Pets | Done, `feat/pets` |
| 5 | Stages 71–80 and collection goals | Done, `feat/aurora-reach` |
| 6 | Infinite Tower at 1B Power | Done, `feat/infinite-tower` |
| 7 | Attachments and boss chests | Done, `feat/attachments` |
| 8 | Upgrade caps ×3–×4 | Done, `feat/upgrade-caps` |
| 9 | Blender armor and an equipment hotbar | Done |
| 10 | Blender forge, and remove the sell and equip stations | Done |

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
   9. **Blender armor and an equipment hotbar** (added by the person mid-run). Remake the armor
   pieces as Blender models, and stop welding armor onto the avatar. Instead, add a hotbar showing
   the equipped weapon, armor, and pet as pixel-art icons. The person's references were a sheet
   of pixel-art gun sprites and a sleek dark rounded hotbar with numbered slots and a glowing
   selected slot. The icons can be rendered from Blender (orthographic, low resolution, nearest
   filter) and uploaded as image assets.
10. **Blender forge** (added by the person mid-run). Rebuild the forge as a Blender model, like
   the reference: a cozy medieval smithy with a timber frame, a stone base, a thatched or
   shingled roof, a glowing hearth, an anvil out front, and a hanging sign. Remove the lobby's
   Sell station and Equip station, which aren't useful now. Selling stays in the Backpack.

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

- An Open Cloud API key for the Studio MCP (`ROBLOX_OPEN_CLOUD_API_KEY`) with
  `developer-product:read/write` and `game-pass:read/write` for universe 10779068698, so the shop's
  products can be created with `manage_monetization`. The person makes the key; an agent never
  handles it.
- The five evolved guns, the armor pieces, and the smithy were imported on 2026-11-25 and saved
  into `ForgeModels.rbxm`. The 3D Importer drops models where the camera is, facing +X, so each
  was moved to the origin and the guns turned to point down −Z like the older ones.

## Known small issues

- The Forge tab shows "No ores yet!" twice.
- The Evolve tab's "Need X more coins" text doesn't refresh on `StatsChanged`.
- The Glassheart count only shows on the Evolve tab.
- The material pickup message always says "Glassheart".
- Ship with "migrate to latest update". Old servers drop `materials` and `bossesDefeated` from
  saves.
- Item 2 review minors, left as they are:
  - Ember spark frames stay until the reveal closes instead of being destroyed after their tween.
  - The Eternal pillar part doesn't set `CanTouch = false`.
  - `GunBuilder` gives tier 7 a denser corona than tier 8 (`tier == 7` should be `tier >= 7`).
  - The tween goal tables are typed `{ [string]: any }`.

## Resume prompt

Paste this into a new session to pick up where the last one stopped:

> Read `docs/HANDOFF.md` and `CLAUDE.md`, then continue the roadmap from the **Now** section. Use
> superpowers:executing-plans on the plan it names, carry on from the next unfinished task, and
> keep running through the remaining checklist items without stopping to ask. Commit as you go
> (don't push), and update `docs/HANDOFF.md` after each task.

## Stages 81–250 (2026-11-25)

- Biomes 9–25 come from `generated(...)` in `Biomes.luau` (three colors and a roster each). Regions:
  Celestial 9–13 (ores rarity 8), Cosmic 14–18 (9), Omega 19–23 (10), finale 24–25 (11).
- Each biome's fifth ore is a Core; `Balance.TIER_KEYS` lists which Cores open which tier, and
  `Balance.unlocksTier` applies the gate from Eternal up.
- Past stage 80, `Balance.GROWTH_SHIFT_STAGE` switches health to 1.5x a stage, hits to 1.11x, and
  coins to 1.28x. These are first guesses to playtest: if stages 81+ feel too easy or too hard,
  tune the `after` numbers in `enemyHealth`, `enemyDamage`, and `enemyCoins`.
- `Cutscene/TierCutscene.luau` plays for tiers 9–11 before the impact frame.
- Not done yet: new eggs and pets for the new regions, evolutions for the new tier guns, and
  Blender models for the new guns (they use the brick builder in the 3D forge scene).
