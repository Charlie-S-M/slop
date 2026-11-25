# Armor at the forge

Roadmap item 3. The person asked for the checklist to run on its own, so every call below is the
builder's unless the roadmap says otherwise.

## Intent

Deep stages hit hard, and Toughness is the only defense. Armor gives the forge a second thing to
make. A player can craft a chestplate, compare it with what they're wearing, and see how much
damage it blocks. The roadmap also asks for helmets and boots; they share every system with the
chestplate, so all three ship together (my call).

## Goals

- **Three slots: Helmet, Chestplate, Boots.** Each owned piece is an `ArmorItem`:
  `{ uid, id, defense, grade, locked? }`. `defense` is the share of each hit that piece blocks.
- **One armor set per rarity** (set names are my calls):

  | Tier | Set |
  |------|-----|
  | Common | Scrap |
  | Uncommon | Copperplate |
  | Rare | Steelguard |
  | Epic | Amethyst |
  | Legendary | Sunforged |
  | Mythic | Bloodmoon |
  | Godly | Prismatic |
  | Eternal | Dawnlight |

  `Shared/Armor.luau` generates the 24 catalog entries (`SunforgedChestplate` → "Sunforged
  Chestplate"). Each set has its own colors.
- **Defense** (numbers in `Balance.luau`):
  - A piece's defense = slot share × rarity defense × grade multiplier × roll.
  - Slot shares: Chestplate 0.5, Helmet 0.3, Boots 0.2.
  - Rarity defense, for a full set: 0.08, 0.13, 0.19, 0.26, 0.34, 0.42, 0.50, 0.58.
  - Grade multipliers: S 1.15, A 1.05, B 1, C 0.95, D 0.9.
  - The roll is between 0.9 and 1.1.
  - Total blocked = the sum over equipped pieces, capped at 0.75 (`Balance.ARMOR_MAX_BLOCK`).
  - `Arena.damagePlayer` scales every hit by `1 - blocked`.
- **Forging armor.**
  - The Forge tab gets a target picker: Gun, Helmet, Chestplate, or Boots.
  - Armor uses the same ores, odds, Eternal gate, and timing game. Its grade comes from the
    strikes, like a gun's.
  - A new remote, `ForgeArmor(slot, request)`, shares the ore validation with `Forge`.
  - The pending forge records `armorId` and `slot`, and `ForgeFinish` creates the `ArmorItem`.
- **The cutscene** builds the armor piece with `Shared/ArmorBuilder.luau` instead of a gun. The
  reveal card shows "Defense X%". Legendary+ armor plays the item-2 impact frames.
- **Wearing it.** `Loadout` welds equipped pieces onto the character: the helmet on the head, the
  chestplate on the torso, and a boot on each foot. They're built from studded bricks in the set's
  colors.
- **Backpack Armor tab.**
  - Three slot cards show what's equipped and the total blocked.
  - Below them is a list of owned pieces.
  - Selecting a piece shows its defense and the change against the equipped piece in that slot,
    e.g. "+4% blocked".
  - Pieces can be equipped, sold, and locked. Selling uses `Balance.armorSellPrice`.
- **Saves.** `Profile` gains `armor: { ArmorItem }` and `equippedArmor: { [Slot]: string }`, at
  `PlayerData` version 4 with defaults. The cap is `Balance.MAX_ARMOR = 60`.

## Non-goals

- No armor evolutions, set bonuses, or Index entries yet (item 5's collection goals can add
  them).
- No Blender armor models yet; the brick builder is the fallback, the same as for guns.

## Anti-goals

- Armor can never reduce damage to zero. The 0.75 cap stays.
- A forge in progress, whether gun or armor, still can't lose ores (`pendingForge` stays the
  safety net).
- Gun forging behaves exactly as before.

## Approaches

- **Defense model.** I chose a percent block. Flat damage reduction stops mattering as enemy
  damage grows each stage, and extra max health is what Toughness already gives.
- **Ore value.** Armor ignores ore value beyond rarity, so the forge's odds stay the one thing ores
  decide. The cost is that two Godly mixes make equally strong armor.
