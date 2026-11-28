# Eternal Tier and Top Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add the gated Eternal rarity with two guns, a firing style for each top tier, and impact
frames for Legendary+ reveals.

**Architecture:** The data goes in Shared modules: `Rarity`, `Balance`, `Guns`, `ShotStyles`, and
`RevealStyles`. The client draws from that data: `GunController` draws shots, and
`Cutscene/ImpactFrames` plays reveals.

**Tech Stack:** Luau, Rojo, Jest specs run in Studio.

**Spec:** `docs/superpowers/specs/2026-11-25-eternal-tier-and-top-effects-design.md`

## Global Constraints

- Every progression number lives in `Balance.luau`.
- Odds for any ore mix without Glasscore stay exactly as they are today.
- Specs run in Studio with `require(game.ServerStorage.__RunSpecs)()` after a sync.

## Review Focus

- A five-Godly-ore forge (no Glasscore) never rolls Eternal, even at max Forge Luck.
- The forge odds panel fits 8 rows without overflowing.
- An evolve reveal of a Legendary gun plays the impact frame and still cleans up the camera, HUD,
  and controls.
- Holding fire with an Eternal Minigun-speed gun doesn't pile up effect parts. Each shot cleans up
  within half a second.
- Other players' Legendary+ shots draw the styled tracer, and their drawing doesn't error when the
  gun id is unknown.

---

### Task 1: Eternal rarity, gate, and guns

**Files:** Modify `Shared/Rarity.luau`, `Shared/Balance.luau`, `Shared/Guns.luau`. Test: new
`Tests/Specs/Shared/Eternal.spec.luau`; update `Collection.spec.luau` (25 → 27).

- [ ] Specs:
  - `Rarity.Count == 8` and `Rarity.get(8).name == "Eternal"`.
  - The odds for five `Glasscore`-free Foundry ores, at luck 5, have a tier-8 chance of `0`.
  - The odds for four Prismite plus one Glasscore have a tier-8 chance above `0`.
  - Odds for a mix of Common ores equal the values from before the change: chance of tiers 1–3,
    rounded to 4 places.
  - `#Guns.pool(8) == 2`, and `Guns.evolutionOf("Dawnbringer") == nil`.
- [ ] Watch them fail.
- [ ] Implement:
  - Add tier 8 to `Rarity`.
  - Add `Balance.ETERNAL_ORES` and `Balance.ETERNAL_TIER = 8`. In `forgeOdds`, cap the ceiling at
    `ETERNAL_TIER - 1` unless some ore id is in `ETERNAL_ORES`.
  - Add the two guns and their collection ids.
- [ ] Specs pass. Commit.

### Task 2: Shot styles

**Files:** Create `Shared/ShotStyles.luau`. Modify `Controllers/GunController.luau`. Test: new
`Tests/Specs/Shared/ShotStyles.spec.luau`.

- [ ] Specs:
  - `ShotStyles.forRarity(t).name` is `"Basic"` for tiers 1–4.
  - Tiers 5–8 return four distinct names: `"Legendary"`, `"Mythic"`, `"Godly"`, `"Eternal"`.
  - `extraParts` is at most 6 for every tier.
  - Out-of-range tiers clamp.
- [ ] Watch them fail.
- [ ] Implement `ShotStyles.forRarity(tier): ShotStyle`. Its fields are `name`, `coreColor`,
  `sheathColor`, `widthScale`, `trail` (`"None" | "Embers" | "Prism" | "Beam"`), `impact`
  (`"Puff" | "Sparks" | "Ring" | "Halo" | "Nova"`), `extraParts`, and `pillar`. Use it in
  `fire` and `drawOtherShot`.
- [ ] Specs pass. Playtest by firing a Legendary, Mythic, Godly, and Eternal gun. Commit.

### Task 3: Impact frames

**Files:** Create `Shared/RevealStyles.luau` and `Controllers/Cutscene/ImpactFrames.luau`. Modify
`ForgeCutscene.reveal`. Test: new `Tests/Specs/Shared/RevealStyles.spec.luau`.

- [ ] Specs:
  - `RevealStyles.forRarity(t)` is nil for tiers 1–4.
  - Tiers 5–8 return the kinds `"Ember"`, `"Implode"`, `"Prism"`, and `"Radiant"`.
  - Each kind's `seconds` is between 0.6 and 2.5.
  - Only Prism and Radiant have `halo = true`.
- [ ] Watch them fail.
- [ ] Implement `ImpactFrames.play(tier, model, screen): Instance?`. It yields for the sequence and
  returns a lingering halo for the caller to destroy, or nil. `reveal` calls it before the card,
  and `restore` destroys the halo.
- [ ] Specs pass. Playtest a Legendary and a Godly reveal, and screenshot them. Commit.

### Task 4: Forge odds panel and handoff

- [ ] Size the odds rows by `Rarity.Count` so 8 fit. Check visually in a playtest.
- [ ] Update `docs/HANDOFF.md`.
- [ ] Commit.
