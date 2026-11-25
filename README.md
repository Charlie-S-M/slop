# Pew Incremental

A Roblox incremental shooter. Every shot at a training target adds your gun's power to your
Power. Enemies drop ores in the Gauntlet. Forge the ores into bigger, rarer guns, and rebirth for
stronger training pads. Every stage, the enemies get bigger, tougher, and hit harder.

## The loop

1. **Train.** Stand on a training pad and shoot its target. Each hit adds `gun power x pad
   multiplier x Training Boost` to your Power. The starter Pop Pistol gives exactly +1.
2. **Fight.** Step through the portal into the Gauntlet. Your damage is `(10 + gun power + Power)
   x rebirth and level boosts x the gun kind's damage share`. Enemies get bigger, tougher, and
   hit harder every stage, and every fifth stage is a boss. There are six biomes of ten stages
   each, and the stages never end: after the sixth biome they loop as Ascensions.
3. **Collect ores.** Enemies drop ores from their biome. Your bag has limited space, and dying
   empties it.
4. **Forge.** Put one to five ores in the forge to roll a new gun. More ores and better ores
   shift the rarity odds up, and the gun's power comes from the ores' value times the rarity's
   multiplier. There are seven rarities, from Common to Celestial, and higher rarities make
   bigger, glowier guns.
5. **Rebirth.** Trade your Power for a permanent damage and health boost plus the next training
   pad: 2x, 4x, and so on up to 128x.

Coins from kills and sales buy upgrades: Ore Bag, Forge Luck, Training Boost, Swift Boots,
Toughness, Coin Boost, and Ore Magnet. You can also claim a Daily reward.

## Where things live

| Path | What |
| --- | --- |
| `places/main/src/ReplicatedStorage/Shared` | Game data and formulas both sides use: `Balance` (all progression numbers), `Guns`, `Ores`, `Biomes`, `Rarity`, `Upgrades`, the brick `GunBuilder`/`OreBuilder`, and `Net` (every remote). |
| `places/main/src/ServerScriptService/Modules/Server` | Server systems: `PlayerData` (session-locked saves), `Combat` (validated shooting), `Arena` (stages, enemies, drops), `Economy` (forge, sell, upgrades, rebirth, daily), `Loadout`, `Leaderboard`, `WorldSetup` (lighting and sky). |
| `.../Modules/Server/World` | Builders for the lobby, arenas, enemies, and props. The world is built from code out of studded bricks. |
| `places/main/src/StarterPlayer/StarterPlayerScripts/Controllers` | Client: `Hud`, `GunController`, `Effects`, `WorldFx` (enemy animation, health bars, biome mood), `Music`, and the menus (`Backpack`, `Forge`, `Upgrades`, `Index`, Rebirth, Daily, and Gauntlet in `Progress`). |
| `places/main/src/ServerScriptService/Tests/Specs` | Jest specs for the shared logic. |

To tune progression, edit `Balance.luau`. Enemy health climbs about 150x per biome, so each new
biome asks for better guns, a rebirth or two, and some time on the pads.

## Working on it

```bash
rojo serve places/main/default.project.json
```

Then connect from the Rojo plugin in Studio. `CLAUDE.md` lists the checks a change must pass.

The lobby is saved in the place file. A place without a `Workspace.Lobby` builds it from
`LobbyBuilder` when the server starts. To rebuild it in Studio after changing the builder, delete
`Workspace.Lobby` and run this in the command bar:

```lua
require(game.ServerScriptService.Modules.Server.World.LobbyBuilder).build(workspace)
```
