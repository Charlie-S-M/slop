# Eternal tier and Legendary+ effects

Roadmap item 2. The person asked for the checklist to run on its own, so every call below is the
builder's and is marked that way where it isn't from the roadmap.

## Intent

Top guns should look and feel like top guns, and Foundry players need something past Godly to
forge toward. The roadmap asks for:
- a distinct firing effect for each top rarity;
- the first post-Godly guns, forged with a new-region ingredient;
- impact frames when a Legendary, Mythic, or Godly gun is revealed.

## Goals

- **A new 8th rarity, Eternal** (my call on the name; "Celestial" is already a label in the gun
  list). It has a white-gold color with a pale blue glow, a ×800 power multiplier, and ×2.1 gun
  scale.
- **Eternal is gated.** The forge can roll Eternal only when the mix includes at least one
  Glasscore, the Foundry's rarest ore. Every other mix tops out at Godly, so existing Godly ores
  can't reach the new tier. The gate is `Balance.ETERNAL_ORES = { Glasscore = true }` (my call
  on which ore).
- **Two Eternal guns**, both my calls: **Dawnbringer** (Rifle) and **Everlight Cannon**
  (Launcher). They use brick blueprints in their own colors for now, appear at the end of the
  Index, and don't evolve yet.
- **Firing styles.** Each top tier fires with its own style, defined as data in
  `Shared/ShotStyles.luau` and drawn by `GunController`. Tiers 1–4 keep today's look.
  - Legendary: a gold tracer with ember sparks, and a spark burst on hit.
  - Mythic: a twin tracer with a crimson core and a violet sheath, and a ring on hit.
  - Godly: a prismatic tracer that shifts color, and a halo ring on hit.
  - Eternal: a white beam with a star nova on hit and a short light pillar at the muzzle.
  - Other players' shots use the same style at a smaller size.
- **Impact frames.** Forge and evolve reveals of Legendary and up play an impact frame before the
  card:
  - All of them start with a few high-contrast frames showing the gun's silhouette.
  - Legendary: a gold silhouette and an ember shockwave ring.
  - Mythic: particles pull inward, then a violet burst.
  - Godly: the scene darkens and a prismatic halo opens behind the gun, staying while the card
    shows.
  - Eternal: the Godly sequence plus a white flash and a light pillar.

  The style data is in `Shared/RevealStyles.luau`. The player is `Cutscene/ImpactFrames.luau`,
  which takes a model so armor (item 3) and attachment chests (item 7) can reuse it.

## Non-goals

- Eternal guns don't evolve, and there are no Blender models for them yet.
- No new region; stages 71–80 are item 5.

## Anti-goals

- Existing saves and forge results don't change. Odds for any mix without Glasscore stay exactly
  as they are today.
- Effects must not tank frame rate. Each shot's extra parts are capped and short-lived, and impact
  frames clean up after themselves.

## Approaches

- **The gate.** I picked a key ore that unlocks the tier. Spending a Glassheart was the other
  option, but it would compete with evolving, and Glasshearts drop at only 15% after the first
  kill. A new material would need a new drop, and that belongs to item 5's region.
- **Effects.** Style data lives in Shared so specs can pin it, and the drawing stays on the client.
  Pure client code would have been simpler but couldn't be tested.
