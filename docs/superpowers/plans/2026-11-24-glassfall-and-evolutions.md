# Glassfall Foundry and Evolving Weapons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a seventh biome (Glassfall Foundry, stages 61–70) whose boss drops Glassheart catalysts, and let Legendary+ guns evolve once into their own catalog entry for a Glassheart plus coins, with Blender hero models.

**Architecture:** Data first (Biomes, Ores, Guns, Balance, GunStats) with Jest specs; then the Glassheart drop in `Arena`, an `Evolve` exchange on the server, an Evolve tab in the Forge menu reusing `ForgeCutscene.reveal`, and five headless Blender scripts producing previews and `.fbx` exports that follow the `ForgeModels` part-role convention.

**Tech Stack:** Luau (strict), Rojo, ModuleLoader, Jest-Lua in Studio, Blender 2.93 (Python, headless).

**Spec:** `docs/superpowers/specs/2026-11-24-glassfall-and-evolutions-design.md`

## Global Constraints

- Evolvable rarities: Legendary (5), Mythic (6), Godly (7). One evolution per gun.
- Evolve cost: 1 Glassheart + `Balance.enemyCoins(70) × {5 = 10, 6 = 30, 7 = 100}`.
- Evolve effect: Power × 3, Training Power × 2, Speed × 1.1; grade, `uid`, `locked`, equipped status unchanged.
- Glassheart: first Glassheart Warden kill ever guarantees 1; later Warden kills 15%. Stored in `profile.materials.Glassheart`; first kill recorded in `profile.bossesDefeated.GlassheartWarden`. Never lost on death.
- Profile version 3 adds `materials = {}` and `bossesDefeated = {}`.
- Biome 7 ores: indexes 31–35, rarity 7, value `2 × 1.4^(index − 1)`.
- Evolved guns: in `Guns.List` right after their base gun (25 total), never in `Guns.pool`, copy the base gun's `GUN_DAMAGE_TUNING`.
- Evolve refused when in a run, away from the anvil, or with a pending forge.
- Model convention: `ForgeModels.<gunId>` of MeshParts named `Handle` (required), `Body`, `Shell`, `Stock`, `Metal`, `Tip` (required), `Glow`, `Crystal`; barrel along −Z.
- CLAUDE.md checks pass (rojo build, sourcemap, selene, stylua); specs green in Studio.

## Review Focus

- A player with an evolved gun equipped and locked keeps it equipped and locked after evolving. → Task 4 test `evolving keeps uid, grade, lock`.
- Evolve with too few coins or no Glassheart spends nothing. → Task 5 playtest check.
- Spamming Evolve on the same gun evolves it once (evolved ids have no further evolution). → Task 4 test `evolved guns do not evolve again`.
- Stage 61 shows the Foundry and stage 71 shows Brickwood Ascension 1 for returning players. → Task 1 test.
- An evolved gun with no imported model still builds (brick fallback). → Task 4 test `builds an evolved gun without a template`.

---

### Task 1: Biome 7 and its ores

**Files:** Modify `ReplicatedStorage/Shared/Biomes.luau`, `ReplicatedStorage/Shared/Ores.luau`; Test `ServerScriptService/Tests/Specs/Shared/Glassfall.spec.luau`.

**Interfaces — Produces:** `Biomes.List[7]` with `boss.id = "GlassheartWarden"`; `Ores.forBiome(7)` returns 5 ores of rarity 7.

- [ ] **Step 1: Write failing specs:** `Biomes.forStage(61).index == 7`, `forStage(70).index == 7`, `forStage(71).index == 1`, `Biomes.ascension(71) == 1`, `Biomes.ascension(70) == 0`, `Biomes.List[7].boss.id == "GlassheartWarden"`; `#Ores.forBiome(7) == 5` and each has `rarity == 7` and `index` 31–35.
- [ ] **Step 2: Run specs in Studio; expect the Glassfall spec to fail.**
- [ ] **Step 3: Implement** the biome entry (glass/kiln palette, three enemies, Warden boss) and five ore entries.
- [ ] **Step 4: Run specs; expect green.**
- [ ] **Step 5: Commit** `feat: add the Glassfall Foundry biome and its ores`.

### Task 2: Foundry arena decor

**Files:** Modify `ServerScriptService/Modules/Server/World/ArenaBuilder.luau` (biome-7 branch in `decorate`: kilns with neon mouths, crystal clusters).

- [ ] **Step 1: Implement**, then **verify in a playtest** by entering stage 61 (set `bestStage = 70` via `eval_server_runtime`) and taking a screenshot of the arena and an enemy.
- [ ] **Step 2: Commit** `feat: decorate the Glassfall Foundry arena`.

### Task 3: Glassheart drops

**Files:** Modify `Shared/Types.luau` (Profile `materials`, `bossesDefeated`), `Shared/Balance.luau`, `Server/PlayerData.luau` (version 3 defaults; reconcile keeps maps), `Server/Arena.luau` (on boss kill in biome 7), `Controllers/Effects.luau` (`kind = "material"` reward popup and toast); Test `Glassfall.spec.luau`.

**Interfaces — Produces:** `Balance.GLASSHEART_REPEAT_CHANCE = 0.15`; `Balance.glassheartDrop(firstKill: boolean, roll: number): number` (1 or 0); Reward event `{ kind = "material", id = "Glassheart", count = 1, position }`.

- [ ] **Step 1: Failing specs:** `glassheartDrop(true, 0.99) == 1`, `glassheartDrop(false, 0.10) == 1`, `glassheartDrop(false, 0.20) == 0`.
- [ ] **Step 2: Run; expect fail. Step 3: Implement. Step 4: Run; green.**
- [ ] **Step 5: Verify in a playtest:** kill the stage-65 Warden via `Arena.damage`; `materials.Glassheart == 1`, `bossesDefeated.GlassheartWarden == true`; die in the run and confirm the Glassheart remains.
- [ ] **Step 6: Commit** `feat: drop Glassheart catalysts from the Foundry boss`.

### Task 4: Evolution catalog and rules

**Files:** Modify `Shared/Guns.luau` (5 evolved entries, `evolvesFrom`, `Guns.evolutionOf`, list order, keep out of pools), `Shared/Balance.luau` (`EVOLVE_KILLS = { [5] = 10, [6] = 30, [7] = 100 }`, `evolveCost(rarity): number?`, tuning copies), `Shared/GunStats.luau` (`evolve(item, evolvedId): GunItem`); Tests `Glassfall.spec.luau`, update `Collection.spec.luau` (25 guns; pools unchanged).

**Interfaces — Produces:** `GunDef.evolvesFrom: string?`; `Guns.evolutionOf(id): GunDef?`; `Balance.evolveCost(rarity): number?` (nil below 5); `GunStats.evolve(item, evolvedId): Types.GunItem`.

- [ ] **Step 1: Failing specs:** `Guns.evolutionOf("SolarFlare").id == "SolarCrown"`; every Legendary+ base in the forge pools has an evolution; `evolved guns do not evolve again` (`evolutionOf(evolved.id) == nil`); no evolved id appears in any `Guns.pool`; `evolveCost(4) == nil`, `evolveCost(5) == Balance.enemyCoins(70) * 10`; `evolving keeps uid, grade, lock` with power ×3, train ×2, speed ×1.1; `builds an evolved gun without a template` (`GunBuilder.build(Guns.get("SolarCrown"))` returns a Model with a `Handle`).
- [ ] **Step 2: Run; fail. Step 3: Implement. Step 4: Run; green (Collection.spec updated to 25).**
- [ ] **Step 5: Commit** `feat: add evolved gun catalog entries and evolution rules`.

### Task 5: Server evolve exchange

**Files:** Modify `Shared/Net.luau` (`Evolve`, `EvolveResult`), `Server/Forge.luau` (handler).

**Interfaces — Consumes:** Task 3 `materials`; Task 4 `evolutionOf`, `evolveCost`, `GunStats.evolve`. **Produces:** client → `Evolve(uid: string)`; server → `EvolveResult({ item: GunItem })`.

- [ ] **Step 1: Implement** with rate limit, in-lobby, near-anvil, no pending forge, gun exists, has evolution, has Glassheart and coins; spend, swap via `GunStats.evolve`, set `gunIndex`, mark state, refresh held gun if equipped (`Loadout.refreshGun`), fire `EvolveResult`.
- [ ] **Step 2: Verify via `eval_server_runtime` + client FireServer:** without catalyst nothing changes; with catalyst+coins the Solar Flare becomes Solar Crown with ×3 power, coins and Glassheart spent once; a second Evolve on it does nothing.
- [ ] **Step 3: Commit** `feat: evolve guns at the forge on the server`.

### Task 6: Evolve tab and reveal

**Files:** Modify `Controllers/Menus/Forge.luau` (Forge / Evolve tabs; evolvable gun list with before/after previews, stats, cost, greyed button with reason), `Controllers/Cutscene/ForgeCutscene.luau` (`reveal(result, label: string?)` showing "EVOLVED!"), HUD or Forge header shows Glassheart count.

- [ ] **Step 1: Implement**, then **verify in a playtest:** give a Solar Flare, 1 Glassheart and enough coins; open Forge → Evolve, screenshot the card; press Evolve; the reveal shows Solar Crown with "EVOLVED!"; the Backpack shows Solar Crown with the same grade.
- [ ] **Step 2: Run the CLAUDE.md checks. Step 3: Commit** `feat: add the Evolve tab and evolution reveal`.

### Task 7: Blender hero models

**Files:** Create `tools/blender/common.py` (role materials, preview camera/render, FBX export), `tools/blender/<gunId>.py` for the five evolved guns, outputs `assets/models/<gunId>.fbx` and `assets/models/<gunId>.png`.

- [ ] **Step 1: Implement `common.py`** with `new_part(role, mesh)` naming objects by role, `render_preview(path)`, `export_fbx(path)` (Y-up, −Z forward, scale for Roblox studs).
- [ ] **Step 2: Write one script per model; run** `blender -b --python tools/blender/<id>.py`; Expected: `.fbx` and `.png` written; view each PNG and iterate until it reads as an upgraded version of its base gun.
- [ ] **Step 3: Verify** each `.fbx` object list contains `Handle` and `Tip` (print from the script).
- [ ] **Step 4: Commit** `feat: add Blender scripts and exports for evolved gun models`.
