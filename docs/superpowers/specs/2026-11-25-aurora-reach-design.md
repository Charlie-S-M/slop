# Aurora Reach (stages 71–80) and collection goals

Roadmap item 5: "Chase armor recipes and evolution materials in a second region. Use the Index to
find drops and a training dummy to compare builds." The person asked for the whole checklist to
run without stopping, so the calls below are the builder's.

## Goals

- **Aurora Reach**, biome 8, stages 71–80.
  - A frozen ridge under the northern lights: snow floor, ice walls, and green-violet aurora glow.
  - Enemies: Frost Lynx (Critter/Fast), Rime Archer (Humanoid/Ranged), Glacier Ox (Brute/Tank).
  - The boss is the **Aurora Sentinel** (Humanoid/Ranged, Crown).
  - The Ascension loop now starts at stage 81.
- **Five Godly-tier ores:** Frostglass, Rimesteel, Polarite, Borealite, and **Aurorite**. Aurorite
  also unlocks the Eternal tier at the forge, like Glasscore.
- **Starshard**, the region's material. Each Sentinel kill drops one: always on the first kill,
  then 15% of the time, the same rule as the Glassheart. Boss materials become one table,
  `Balance.BOSS_MATERIALS`.
- **The armor recipe: Tempering.** At the forge, one Starshard plus coins tempers an armor piece
  once. It blocks 1.25× as much, is marked "Tempered", and its sell worth is unchanged. The cost is
  `enemyCoins(80) × TEMPER_KILLS[rarity]`. This is the armor counterpart to gun evolutions.
- **Index drop info:** each ore entry says where it drops ("Drops in Aurora Reach"), and boss
  materials are listed with their boss.
- **Training dummy:** a dummy in the lobby by the forge. Shooting it shows damage numbers and a
  rolling 5-second DPS readout above it, so builds can be compared. The numbers are client-side
  and don't train Power.

## Non-goals

- No new guns or armor sets.
- No migration: `bestStage` and checkpoints are stage numbers, and stages 71+ keep their scaling.
  Only the biome drawn at 71–80 changes.

## Anti-goals

Tempering can't push total block past the 75% cap; `ArmorStats.blocked` still caps it.
