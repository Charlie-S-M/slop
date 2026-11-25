# Forging cutscene, timing game, and three-stat guns

## Intent

Forging is the payoff of every Gauntlet run, and right now it's a two-second pulse in a menu. This
change turns it into a short cinematic the player watches and plays: the ores melt, the metal pours
into a mold shaped like the new gun, the player hammers it into shape with four timed clicks, and
the gun is quenched and revealed. The clicks make the player's skill part of the gun.

The cutscene must work for every gun, current and future, without per-gun work. It builds
everything from the gun's catalog entry and `GunBuilder`, so adding a gun to `Guns.luau` is all a
new gun needs.

At the same time, guns move from one stat to three: **Power** (damage), **Speed** (fire rate), and
**Training Power** (what each training shot adds). Training Power is how rarer ores pay off beyond
raw damage.

## Goals

- A ~8 second forging cutscene, seen only by the forging player, that works for any gun.
- A four-strike timing game during the hammer step whose grade (S, A, B, C, D) raises or lowers the
  gun's Power and Speed.
- Guns carry Power, Speed, Training Power, and a grade, shown wherever guns are shown.
- Training Power grows with the rarity of the ores used.

## Non-goals

- The timing game doesn't change the gun's rarity or which gun it is. The server rolls those before
  the cutscene starts.
- Other players don't see anyone else's cutscene.
- No new guns, armor, or other forge recipes in this change.

## Anti-goals

- Forging again and again must not feel slow. Skip stays one tap away for the parts that don't need
  the player.
- A forge must never lose the player's ores. Leaving, disconnecting, dying, or a server crash
  partway still produces the gun.
- Cheating the timing game must never beat a perfect honest run (see Security).

## Approaches considered

1. **Private forge set (chosen).** A small dark stage built only in the forging player's client,
   far from the map, with a scripted camera cutting between close-ups. Full control of framing and
   lighting, nothing moves for other players, at the cost of a second forge scene to build and keep.
2. **Inside the Forge menu.** The sequence plays in a ViewportFrame. Cheap, but small and boxed-in,
   with limited effects; it would never feel like a cinematic.
3. **On the lobby's real forge.** Ties into the world, but those props are placed for walking past,
   other players walk through the shot, and two players forging at once collide. Ruled out.

## Gun stats

Each gun item gains three fields next to `power`:

| Field | Meaning | Where it's used |
| --- | --- | --- |
| `power` | Damage stat, as today. | `Balance.pelletDamage` / `shotDamage`. |
| `speed` | Fire-rate multiplier on the gun kind's base rate. | Client fire loop, server shot rate limit, stat displays. |
| `train` | Training Power: base power added per training shot. | `Balance.trainingGain` (replaces `gunPower` there). |
| `grade` | `"S"`, `"A"`, `"B"`, `"C"`, or `"D"`. | Display only; its effect is already baked into `power` and `speed`. |

### How a forge rolls them

The server rolls rarity, gun, and the base values when the forge starts, exactly as today, then
applies the grade when the timing game ends:

- **Power** = ores' value sum × rarity power multiplier × random roll (0.85–1.2) × grade Power
  multiplier.
- **Speed** = grade Speed multiplier × small random roll (0.97–1.03).
- **Training Power** = base Power before the grade (ores × rarity × roll) × ore training factor.
  The ore training factor comes from the average `rarity` tier of the ores used (the existing field
  in `Ores.luau`): `1.25^(average tier − 1)`, so Common ores give 1.0 (today's training rate) and
  Celestial ores about 3.8. No gun trains slower than it does today; rarer ores only add. Within a
  biome, the ores a tier above the biome's commonest train about 25% better.

Starting grade multipliers (tunable in `Balance`):

| Grade | Power | Speed |
| --- | --- | --- |
| S | 1.30 | 1.15 |
| A | 1.15 | 1.07 |
| B | 1.00 | 1.00 |
| C | 0.85 | 0.93 |
| D | 0.70 | 0.85 |

Speed swings less than Power because faster fire also means more training shots per second.

### Training and damage formulas

- Fire rate = kind's `fireRate` × `item.speed`. The server's shot rate limit uses the same number.
- Training gain per shot = `item.train` × kind `damageScale` × `pellets` × zone multiplier ×
  Training Boost. Keeping the kind's damage share means each kind still trains about the same per
  second at equal Training Power; Speed is what makes one gun train faster.
- Damage is unchanged: it still uses `item.power`.

### Existing saves

Profiles go to version 2. Each saved gun without the new fields gets `speed = 1`, `grade = "B"`,
and `train` derived from its power and its catalog rarity (using that rarity as the ore tier), so
no existing gun trains slower. The starter Pop Pistol keeps exactly `power = 1, train = 1`, so the
"+1 per shot" promise holds.

## Forge flow

The forge becomes a two-step exchange so the server stays in charge:

1. The client sends `Forge` with the chosen ores, as today. The server validates them, removes the
   ores, rolls rarity, gun, base Power, and Training Power, and stores a **pending forge** for that
   player: a one-use token, the rolled values, and the start time. It sends `ForgeStart` with the
   token, the gun id, the rarity, and the ore ids so the client can build the scene. A player can
   have one pending forge at a time. The pending forge is stored in the profile, so an autosave
   or server crash between start and finish can't lose the ores; on the next load it finishes as
   in step 3.
2. The client plays the cutscene and sends `ForgeFinish` with the token and the four strike
   accuracies (numbers from 0 to 1). The server checks the token, checks that enough time has
   passed for the cutscene to really have played (at least ~3 seconds), clamps every accuracy to
   0–1, works out the grade, applies it, adds the gun, and sends `ForgeResult` as today, now with
   the grade and all three stats.
3. If no `ForgeFinish` arrives within 60 seconds, or the player leaves, the server finishes the
   forge itself, counting every strike as a Miss (grade D), so the ores are never lost and quitting
   never beats playing. When the player leaves, this happens before `PlayerData` saves. If the
   client's cutscene is cut short (death or reset mid-hammer), it sends the strikes played so far
   with the rest as Misses. There's no close button during the ~4 second hammer step.

## The cutscene

The client builds a private set the first time it's needed (well away from the map, for example
`Vector3.new(0, 600, -4000)`) and reuses it. While it plays, the HUD and menus hide, the camera is
scriptable, and the player's character stays where it was. The set has a crucible on chains, a mold
tray, an anvil, a hammer, and a water barrel, built from bricks like the rest of the game, against a
dark backdrop lit by the molten metal.

1. **Melt (~1.5s).** Top-down view into the crucible. The player's actual ores (built with
   `OreBuilder`) drop in one by one with pops, sink, and melt into a rising orange surface. In the
   last moment the metal flashes the rolled rarity's color.
2. **Pour (~1.5s).** Side view. The crucible tips, a glowing stream falls into the mold, and a
   gun-shaped cavity fills. The cavity is the new gun's own model, flattened and glowing orange.
3. **Hammer: the timing game (~4s).** Close-up of the glowing gun on the anvil. Four times, a ring
   appears around a circle over the gun and shrinks toward it; the player clicks or taps when the
   ring meets the circle, and the hammer slams down. Each strike shows **PERFECT**, **GREAT**,
   **GOOD**, or **MISS**, with sparks and camera shake sized by the result. After each strike the
   gun's parts shift a quarter of the way from glowing orange to their real colors.
4. **Quench (~1s).** The gun plunges into the barrel with a burst of steam and a sizzle.
5. **Reveal.** The gun rises from the barrel spinning, with the rarity light and sunburst, and
   confetti from Legendary up. A card shows the name, kind, rarity, grade badge, Power, Speed, and
   Training Power, with **Equip** and **Continue** (the current reveal, extended).

Effects scale with rarity: more sparks and a brighter light from Epic, confetti from Legendary.

### Timing game rules

- Each ring shrinks over about 1.1 seconds, with a short random pause between rings so the rhythm
  can't be memorized.
- Accuracy is how close the ring is to the target circle at the click: within 8% of the shrink time
  is Perfect (1.0), within 18% Great (0.75), within 32% Good (0.45), anything else or no click is a
  Miss (0).
- The grade comes from the average of the four: S at 0.9 or more, A at 0.7, B at 0.5, C at 0.3, D
  below.
- Any click, tap, or gamepad A press counts, anywhere on screen, so it works the same on phones.

### Skip

A **Skip** button is visible during the melt and pour; it jumps straight to the hammer step. The
four strikes always play, since they decide the gun. The quench and reveal play after.

## Where the stats show

- **Backpack:** cards show the grade badge; the detail panel lists Power, Speed (as a fire rate and
  multiplier), and Training Power.
- **Forge menu:** the odds panel adds an estimated Training Power range next to the Power range.
- **Forge reveal card:** grade and all three stats.
- **Index** stays as it is.

## Security

The timing results come from the client, so a cheater can always report four Perfects. That's
acceptable because the best a cheater can get is grade S, the same as a player who times every
strike well; the grade can't exceed S, can't change rarity, and only applies to a server-issued
token once. The server also rejects a finish that arrives faster than the cutscene could have
played.

## Left to the builder

- Exact camera angles, set layout, sounds, and effect details.
- The exact constants (grade multipliers, accuracy windows, ore training factor, timings), as long
  as the shapes above hold. All of them go in `Balance.luau`.
- How the cutscene code is split across client modules.
