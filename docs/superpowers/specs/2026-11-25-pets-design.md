# Pets

Roadmap item 4: "Earn and equip a companion for better ore drops, faster training, or bonus
damage. See the exact bonus before equipping it." The person asked for the whole checklist to run
without stopping, so everything below that the roadmap doesn't name is the builder's call.

## Goals

- **Eggs earn pets.** A Pets menu (a new HUD button) sells three eggs for coins. Each egg unlocks
  at a best stage and costs that stage's enemy coins times a multiplier:

  | Egg | Unlocks at stage | Cost (× enemy coins) |
  |-----|------------------|----------------------|
  | Meadow Egg | 1 | 200 |
  | Ember Egg | 31 | 400 |
  | Prism Egg | 61 | 800 |

- **Each egg holds four pets, one per rarity:**

  | Egg | Rarity weights |
  |-----|----------------|
  | Meadow | Common 60, Uncommon 30, Rare 9, Epic 1 |
  | Ember | Uncommon 45, Rare 35, Epic 16, Legendary 4 |
  | Prism | Epic 50, Legendary 35, Mythic 13, Godly 2 |

- **Each pet boosts one thing:** ore drop chance (`"Ores"`), training power (`"Training"`), or
  shot damage (`"Damage"`).
  - The bonus by rarity is +5, +10, +20, +35, +60, +100, or +175%.
  - Bonuses of the same kind add up: two +20% Training pets give ×1.4 training.
  - Ore drop chance is capped at 95%.
- **Up to 3 pets equipped** (`Balance.PET_SLOTS`). The menu shows each pet's exact bonus and what
  equipping it changes, e.g. "Training ×1.20 → ×1.40". Pets can be released for a small coin
  refund. The cap is `Balance.MAX_PETS = 50`.
- **Equipped pets follow their owner.** Each one is a small brick creature in its colors that
  floats beside the player. The server publishes the equipped ids in a player attribute, and every
  client draws them.
- **Hatching shows a reveal.** The egg shakes and pops, then a card shows the pet and its bonus.
  Legendary+ pets play the item-2 impact frames.
- **Saves:** `Profile.pets: { PetItem }` and `Profile.equippedPets: { string }`, at version 5.
  A `PetItem` is `{ uid, id, locked? }`.

## Non-goals

No pet leveling, fusing, trading, or eggs from drops yet.

## Anti-goals

- No bonus without a visible number.
- Pets never change server-side power or damage without the same numbers the menu shows: the menu
  and the server use one function, `PetStats.multiplier(pets, equipped, kind)`.

## Approaches

Eggs bought with coins (chosen) give a coin sink that late players need. Boss drops would compete
with item 7's chests.
