# Infinite Tower

Roadmap item 6: "Unlock the Tower at 1B Power, clear escalating floors, earn permanent checkpoint
bonuses, and resume after leaving." The person asked for the whole checklist to run without
stopping, so the calls below are the builder's.

## Goals

- **Unlock:** 1B Power (`Balance.TOWER_UNLOCK_POWER`). The Gauntlet menu gets a Tower card. Before
  unlock it shows the Power still needed; after, it shows the best floor, the bonus, and "Enter
  at floor N".
- **Floors:** floor N plays as stage `70 + N`, so difficulty keeps rising past Aurora Reach. Every
  5th floor is a boss floor, by the same rule as stages, and the biome look cycles with the stage.
  The run is a normal arena run in Tower mode, so ores, boss materials, and armor all apply.
- **Clearing floors:** each cleared floor above `profile.towerBest` raises it.
- **Checkpoints:** every 10th floor cleared adds a permanent +10% to training Power and coins from
  kills. That's `Balance.towerBonus(best) = 1 + 0.1 × floor(best / 10)`, applied in `Combat` and
  the kill reward.
- **Resuming:** a Tower run starts at the last checkpoint passed: `floor(best / 10) × 10 + 1`.
- **The HUD** shows "FLOOR N" or "BOSS FLOOR N" instead of "STAGE N" in the Tower.
- **Saves:** `Profile.towerBest`, at version 6.

## Non-goals

- No Tower leaderboard yet.
- No Tower-only enemies.
- Item 7's chests (attachments) will also drop from Tower bosses.

## Anti-goals

The Tower never lowers `bestStage` or changes Gauntlet checkpoints. Its floors only write
`towerBest`.
