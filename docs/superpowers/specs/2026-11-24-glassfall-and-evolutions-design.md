# Glassfall Foundry and evolving weapons

## Intent

Checklist item #1 from the expansion roadmap. Players past stage 60 run out of new things: stage
61 loops back to Brickwood Meadow as "Ascension 1". This adds a seventh biome, Glassfall Foundry
(stages 61–70), whose boss drops the first evolution catalyst, and lets the best guns evolve into a
stronger named version. The new region gives late players a destination, and evolutions give their
best guns somewhere to grow.

## Goals

- A seventh biome for stages 61–70 with its own look, three enemies, a boss at stage 70, and five
  ores. The Ascension loop starts after it, at stage 71.
- Legendary, Mythic, and Godly guns can evolve once into their own catalog entry, at the forge, for
  one Glassheart catalyst plus coins.
- The five forgeable guns of those rarities each get an evolved version: Solar Flare → Solar Crown,
  Titan Howitzer, Gilded Handcannon, Cosmic Annihilator, and Starforge (names for the last four
  left to the builder).
- Evolved guns use mesh models made in Blender, following the existing `ForgeModels` part-role
  convention.

## Non-goals

- Common to Epic guns don't evolve.
- No second evolution, no evolution trees, no other catalysts yet.
- No new rarity above Godly.
- Stages 71–80 and further regions are later checklist items.

## Anti-goals

- Evolving must never lose a gun or its grade: the same owned gun (same `uid`) becomes the evolved
  one, keeping its lock state and equipped status.
- A catalyst must never be lost to dying in a run.
- Players already past stage 60 keep their `bestStage` and checkpoints.

## Approaches considered

For storing evolved guns:

1. **Own catalog entries (chosen).** Each evolved gun is a normal entry in `Guns.luau` with an
   `evolvesFrom` field. Evolving swaps the owned gun's `id` and multiplies its stats. Every existing
   screen shows it by name without extra work, the Index gets new entries, and the model hangs off
   the new id.
2. **An `evolved` flag on the owned gun.** No new entries, but every screen, the damage math, and
   the model lookup must check the flag; one missed check shows the old name or drops the boost.

For the cost, catalyst + coins was chosen over catalyst + spare copies: copies of Legendary-and-up
guns are too rare to make a fair cost.

For models, a mix: everyday guns stay as they are; evolved guns get hero mesh models from Blender.

## The new biome

`Biomes.luau` gains a seventh entry, **Glassfall Foundry**: a glassworks of glowing kilns, crystal
cullet piles, and stained-glass panels. Palette: smoky glass floor, cool teal glass walls, amber kiln
glow. Three enemies built by the existing `EnemyBuilder` shapes (one Humanoid, one Brute, one
Floater or Critter) and a boss, the **Glassheart Warden** (Brute or Humanoid, Crown or Spikes).
`ArenaBuilder.decorate` gets a biome-7 prop set (kilns with glowing mouths, crystal clusters).

`Biomes.forStage` and `Biomes.ascension` work off the list length, so adding the biome makes stage
61 the Foundry and moves the loop to stage 71 with no other change. Stage numbers, `bestStage`, and
checkpoints stay as they are; a player who reached stage 64 before simply finds the Foundry there.

### New ores

Five ores for biome 7 (`Ores.luau` indexes 31–35), all rarity tier 7 (Godly), with values
continuing the existing curve (`2 × 1.4^(index − 1)`). Names left to the builder; they should read
as glass and kiln materials. The forge's "at most one rarity above the best ore" rule is unchanged,
and Godly stays the top rarity.

## The Glassheart catalyst

The Glassheart is not an ore: it doesn't go in the bag, can't be forged or sold, and isn't lost on
death. Profiles gain `materials: { [string]: number }` and `bossesDefeated: { [string]: boolean }`
(version 3), both starting `{}`.

- The Glassheart Warden is biome 7's boss, so it appears on every boss stage in the Foundry: 65 and
  70, and 135/140, 205/210, ... in later Ascensions.
- The first Warden kill ever guarantees one Glassheart (`bossesDefeated.GlassheartWarden` records
  it). Every later Warden kill gives one with a 15% chance.
- A reward toast and the existing ore-pickup style popup announce it.

## Evolving

### Catalog

Each evolved gun is a `Guns.luau` entry with:

- the same `kind` as its base gun, a new `id` and `name`, the same `rarity`, its own colors;
- `evolvesFrom = "<base id>"`;
- left out of `Guns.pool` (the forge can never roll an evolved gun) but present in `Guns.get` and
  in `Guns.List`, placed right after its base gun, so the Index shows it there and its count goes
  from 20 to 25. Evolved ids copy their base gun's `GUN_DAMAGE_TUNING` entry.

`Guns.evolutionOf(id): GunDef?` returns the evolved entry for a base id.

### Cost and effect (tunable in `Balance.luau`)

- Cost: 1 Glassheart + coins worth a number of stage-70 kills, so the price keeps pace with
  late-game income: Legendary `enemyCoins(70) × 10`, Mythic `× 30`, Godly `× 100` (about 8B, 25B,
  and 83B coins).
- Effect: Power × 3, Training Power × 2, Speed × 1.1. Grade, lock, `uid`, and equipped status stay.
- `evolveCost(rarity)` and `evolveStats(item)` live in `Balance` / `GunStats` so the client previews
  exactly what the server applies.

### Where and how

The Forge menu gets an **Evolve** tab next to the ore picker. It lists owned guns that have an
evolution, each with a before/after preview (both models, and Power, Speed, Training Power before →
after), the cost, and an Evolve button that is greyed out with the reason when the player lacks the
catalyst or coins. Pressing it sends `Evolve(uid)`.

The server (`Forge.luau` or a new `Evolution.luau`) checks: not in a run, near the anvil, the gun
exists and has an evolution, the player has the catalyst and coins, then spends them, swaps `id`,
applies the multipliers, marks the evolved id in `gunIndex`, refreshes the held gun if it was
equipped, and replies with `EvolveResult({ item })`.

The client plays the existing forge reveal (`ForgeCutscene.reveal`) for the evolved gun, with
"EVOLVED!" in place of "NEW!". The bigger Legendary+ impact frames are a separate checklist item.

## Models

Evolved guns follow the `ForgeModels` convention the current guns use, so `GunBuilder` builds them
with no code change:

- A `Model` named by the gun id in `ReplicatedStorage.ForgeModels`, all `MeshPart`s.
- Parts named by role: `Handle` (the grip, required), `Body`, `Shell`, `Stock`, `Metal`, `Tip`
  (the muzzle end, required), `Glow`, `Crystal`. `GunBuilder` colors each role from the catalog
  entry and makes `Glow` and `Crystal` neon.
- Barrel along −Z, grip at the origin, sized like the base gun (GunBuilder scales by rarity).

The Blender workflow (Blender 2.93 is installed here and runs headless): one script per model in
`tools/blender/` builds the mesh by role, renders a preview PNG for review, and exports an `.fbx`
to `assets/models/`. This change includes all five scripts, previews, and exports. The person
imports each `.fbx` into `ForgeModels` with Studio's 3D Importer (or it's uploaded if an Open Cloud
key is added), then the `ForgeModels.rbxm` export in the repo is refreshed from Studio. Until a
model is imported, an evolved gun falls back to its base gun's brick blueprint, so the system works
before the art lands.

Evolving is refused while the player has a pending forge.

## Left to the builder

- Names for the four other evolutions, the Foundry enemies, and the new ores.
- Exact colors, decoration layout, and Blender model shapes, within the role convention.
- Whether evolving lives in `Forge.luau` or its own server module.
