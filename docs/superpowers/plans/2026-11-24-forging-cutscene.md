# Forging Cutscene and Three-Stat Guns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the menu-only forge with a private ~8s forging cutscene (melt, pour, a four-strike timing game, quench, reveal) and give every gun Power, Speed, Training Power, and a grade.

**Architecture:** Pure stat and grading rules go in a new shared `GunStats` module (testable with Jest). The server splits forging into a two-step exchange (`Forge` → `ForgeStart`, `ForgeFinish` → `ForgeResult`) in a new `Forge` server module that keeps the pending forge in the profile. The client builds a brick forge set far from the map and plays the cutscene with a scripted camera, with the timing game as a ScreenGui overlay.

**Tech Stack:** Luau (strict), Roblox engine APIs, Rojo, crusherfire ModuleLoader, Jest-Lua specs run in Studio.

**Spec:** `docs/superpowers/specs/2026-11-24-forging-cutscene-design.md`

## Global Constraints

- Every tunable number lives in `places/main/src/ReplicatedStorage/Shared/Balance.luau` (grade multipliers, accuracy windows, ore training factor, timings).
- Grade multipliers: S 1.30/1.15, A 1.15/1.07, B 1.00/1.00, C 0.85/0.93, D 0.70/0.85 (Power/Speed).
- Strike accuracy: within 8% of shrink time → 1.0 (Perfect), 18% → 0.75 (Great), 32% → 0.45 (Good), else 0 (Miss). Grade from the average of four: S ≥ 0.9, A ≥ 0.7, B ≥ 0.5, C ≥ 0.3, else D.
- Ore training factor: `1.25 ^ (average ore.rarity − 1)`.
- Speed = grade Speed multiplier × roll in [0.97, 1.03]. Power = base × grade Power multiplier. Training Power = base Power before the grade × ore training factor.
- Fire rate everywhere = kind `fireRate` × `item.speed`. Training gain per shot = `item.train` × kind `damageScale` × `pellets` × zone × Training Boost.
- The forge never loses ores: timeout (60s), leaving, or a crash finishes the forge with unplayed strikes as Misses (grade D).
- `ForgeFinish` earlier than 3 seconds after `ForgeStart` is rejected; accuracies are clamped to 0–1; tokens are single-use.
- Profile version 2; migrated guns get `speed = 1`, `grade = "B"`, `train` from power × factor of the gun's catalog rarity; the Pop Pistol keeps `power = 1, train = 1`.
- Checks from `CLAUDE.md` (rojo build, sourcemap, selene, stylua) pass; luau-lsp runs only if `globalTypes.None.d.luau` is present.

## Review Focus

- A player who presses Forge twice quickly (double click, lag) should get one forge, not two tokens or lost ores. → Task 3 test `rejects a second forge while one is pending`.
- A player who leaves mid-cutscene should find the gun in their backpack on rejoin. → Task 3 manual check plus `finishes the pending forge on load`.
- A `ForgeFinish` with NaN, negative, huge, missing, or extra accuracies should grade like Misses, never error. → Task 1 test `treats bad accuracies as misses`.
- Old saves with guns lacking the new fields should load and train no slower than before. → Task 1 test `migrates an old gun without slowing its training`.
- A player who dies or resets during the hammer step should still finish the forge with the strikes they played. → Task 6 manual check.

---

### Task 1: GunStats rules and Balance constants

**Files:**
- Create: `places/main/src/ReplicatedStorage/Shared/GunStats.luau`
- Modify: `places/main/src/ReplicatedStorage/Shared/Balance.luau` (add constants; change `trainingGain`)
- Modify: `places/main/src/ReplicatedStorage/Shared/Types.luau` (GunItem fields, Profile.pendingForge, PendingForge type)
- Test: `places/main/src/ServerScriptService/Tests/Specs/Shared/GunStats.spec.luau`, update `Balance.spec.luau`

**Interfaces:**
- Produces in `Types`: `GunItem = { uid, id, power: number, speed: number, train: number, grade: Grade, locked: boolean? }`, `export type Grade = "S" | "A" | "B" | "C" | "D"`, `PendingForge = { token: string, gunId: string, rarity: number, basePower: number, train: number, oreIds: { string }, startedAt: number }`, `Profile.pendingForge: PendingForge?`.
- Produces in `Balance`: `GRADE_MULTIPLIERS: { [Grade]: { power: number, speed: number } }`, `STRIKES = 4`, `RING_SECONDS = 1.1`, `FORGE_MIN_SECONDS = 3`, `FORGE_TIMEOUT_SECONDS = 60`, `SPEED_ROLL_MIN = 0.97`, `SPEED_ROLL_MAX = 1.03`, and `trainingGain(train: number, kind, zoneMultiplier: number, trainingLevel: number): number` (first argument is now Training Power).
- Produces in `GunStats`:
  - `strikeAccuracy(errorFraction: number): number` (errorFraction = |click time − ring end| / RING_SECONDS)
  - `gradeFor(accuracies: { any }): Grade` (reads indexes 1..STRIKES; anything not a finite number counts as 0; clamps to 0–1)
  - `oreTrainingFactor(ores: { Ores.OreDef }): number`
  - `finalize(basePower: number, grade: Grade, speedRoll: number): (power: number, speed: number)`
  - `migrateGun(item: { [string]: any }): Types.GunItem`
  - `fireRate(kind: Guns.GunKind, speed: number): number`

- [ ] **Step 1: Write the failing specs** in `GunStats.spec.luau`:
  - `strikeAccuracy`: 0.05 → 1, 0.15 → 0.75, 0.3 → 0.45, 0.5 → 0.
  - `gradeFor`: `{1,1,1,1}` → "S"; `{1,0.75,0.75,0.75}` (avg 0.8125) → "A"; `{0.45,0.45,0.45,0.45}` → "C"; `{0,0,0,0}` → "D".
  - `treats bad accuracies as misses`: `{0/0, -3, math.huge, "x"}` → "D"; `{}` → "D"; `{1,1,1,1,1,1}` → "S" (extras ignored).
  - `oreTrainingFactor`: four Common ores → 1; four Celestial (`Singularity`) → `1.25^6` within 1e-9.
  - `finalize(100, "S", 1)` → power 130, speed 1.15; `finalize(100, "D", 1)` → 70, 0.85.
  - `migrates an old gun without slowing its training`: `{uid="g5", id="RookieRifle", power=40}` → speed 1, grade "B", train ≥ 40; `{uid="g1", id="PopPistol", power=1}` → train 1.
  - Update `Balance.spec`: `trainingGain(10, "Pistol", 2, 0)` → 20.
- [ ] **Step 2: Sync to Studio and run specs; expect failures** for missing `GunStats` (run the Jest runner per `tools/ci/run-tests.luau`, or require the spec runner in a Studio playtest).
- [ ] **Step 3: Implement** the types, constants, and `GunStats` functions above. `migrateGun` keeps existing fields and fills missing ones; `train` for non-starter guns = `power × 1.25^(def.rarity − 1)`.
- [ ] **Step 4: Run specs; expect all green.**
- [ ] **Step 5: Commit** `feat: add GunStats rules for grades, speed, and training power`.

### Task 2: Use speed and train in combat and saves

**Files:**
- Modify: `places/main/src/ServerScriptService/Modules/Server/PlayerData.luau` (CURRENT_VERSION 2; `reconcile` runs `GunStats.migrateGun` on every gun; default starter gun gets speed 1, train 1, grade "B"; add `pendingForge` default nil)
- Modify: `places/main/src/ServerScriptService/Modules/Server/Combat.luau` (rate limit uses `GunStats.fireRate(kind, item.speed)`; training uses `item.train`)
- Modify: `places/main/src/StarterPlayer/StarterPlayerScripts/Controllers/GunController.luau` (shot interval from `GunStats.fireRate`)
- Modify: `places/main/src/ServerScriptService/Modules/Server/Economy.luau` (remove `onForge` and its connection; `better` comparison moves to Task 3)

**Interfaces:**
- Consumes: Task 1 `GunStats.migrateGun`, `GunStats.fireRate`, `Balance.trainingGain(train, ...)`.
- Produces: `PlayerData.equippedGun(profile)` now returns items with `speed`, `train`, `grade`. Adds `PlayerData.BeforeRelease: Signal<Player, Profile>`, fired synchronously in `onPlayerRemoving` before the final save, and `PlayerData.Loaded` unchanged.

- [ ] **Step 1: Implement** the changes. `reconcile` must keep `pendingForge` when present and valid.
- [ ] **Step 2: Verify in a playtest:** with an old-style gun injected via `eval_server_runtime` (`{uid="g9", id="TinSpitter", power=50}`), rejoin and confirm it gains speed 1, grade "B", train 50; training gain per SMG shot = 50 × 0.45 × 1 × 1 = 22.5.
- [ ] **Step 3: Commit** `feat: drive fire rate and training from gun speed and training power`.

### Task 3: Two-step server forge

**Files:**
- Create: `places/main/src/ServerScriptService/Modules/Server/Forge.luau`
- Modify: `places/main/src/ReplicatedStorage/Shared/Net.luau` (add `"ForgeStart"`, `"ForgeFinish"` to `EVENTS`)
- Test: manual (server state), plus `GunStats` specs already cover the math

**Interfaces:**
- Consumes: Task 1 `GunStats.*`, `Balance.forgeOdds`, `Balance.pickRarity`; Task 2 `PlayerData.BeforeRelease`.
- Produces remotes:
  - Client → `Forge(request: { [oreId]: count })` (same validation as today's `Economy.onForge`).
  - Server → `ForgeStart({ token: string, gunId: string, rarity: number, oreIds: { string } })`.
  - Client → `ForgeFinish(token: string, accuracies: { number })`.
  - Server → `ForgeResult({ item: GunItem, new: boolean, better: boolean })` (item now has grade/speed/train).
- Produces module API: `Forge.finishPending(player: Player, accuracies: { number }?): GunItem?` (used by timeout, leave, and load).

- [ ] **Step 1: Implement `Forge` start:** validate as today (rate limit, in lobby, near anvil, gun cap, ore table), remove ores, roll rarity/gun/base power (ores × rarity mult × roll 0.85–1.2), `train = basePower × GunStats.oreTrainingFactor(ores)`, store `profile.pendingForge` with an `HttpService:GenerateGUID(false)` token and `startedAt = os.time()`, mark state, fire `ForgeStart`. Reject (notify "Finish your current forge first!") when `pendingForge` exists — `rejects a second forge while one is pending`.
- [ ] **Step 2: Implement `ForgeFinish`:** rate limit; token must equal `pendingForge.token`; `os.time() - startedAt >= Balance.FORGE_MIN_SECONDS` else ignore; grade = `GunStats.gradeFor(accuracies)` (non-table → all misses); `finalize` with a speed roll in [0.97, 1.03]; append item, update `gunIndex`, `forges`, clear `pendingForge`, fire `ForgeResult` with `better` computed from `shotDamage × fireRate` as Economy did.
- [ ] **Step 3: Implement timeouts and recovery:** a 1s loop finishes any pending forge older than `FORGE_TIMEOUT_SECONDS` with `{}`; `PlayerData.BeforeRelease` finishes with `{}`; `PlayerData.Loaded` finishes any saved `pendingForge` with `{}` — `finishes the pending forge on load`.
- [ ] **Step 4: Verify via `eval_server_runtime`:** fire `Forge` with ores, confirm `pendingForge` set and bag reduced; firing again is rejected; `ForgeFinish` with `{1,1,1,1}` after 3s yields grade S, power = round(base × 1.3); a second `ForgeFinish` with the same token does nothing; a pending forge left alone becomes grade D after 60s.
- [ ] **Step 5: Commit** `feat: split forging into start and finish with pending forges`.

### Task 4: Forge set and cutscene camera (melt, pour, quench, reveal)

**Files:**
- Create: `places/main/src/StarterPlayer/StarterPlayerScripts/Controllers/Cutscene/ForgeSet.luau`
- Create: `places/main/src/StarterPlayer/StarterPlayerScripts/Controllers/Cutscene/ForgeCutscene.luau`

**Interfaces:**
- Consumes: `GunBuilder.build(def, power?)`, `OreBuilder.build(def)`, `Kit`, `Effects.confetti`, `Hud.screen()`, `Menus.close()`.
- Produces:
  - `ForgeSet.get(): { root: Model, crucible: BasePart, metal: BasePart, mold: BasePart, anvilTop: CFrame, hammer: Model, barrel: BasePart, waterTop: CFrame }` (built once at `Vector3.new(0, 600, -4000)`, parented to `workspace` under a local folder).
  - `ForgeCutscene.play(start: { token, gunId, rarity, oreIds }, strike: (index: number) -> number): { number }` — yields through melt, pour, hammer (calls `strike(i)` four times, which returns that strike's accuracy), and quench; returns the four accuracies. `strike` is supplied by Task 5.
  - `ForgeCutscene.reveal(result: { item, new, better })` — rising gun, rarity light, sunburst card with grade and three stats, Equip/Continue; restores camera and HUD on Continue/Equip.
  - `ForgeCutscene.skipRequested: boolean` set by a Skip button visible only during melt and pour.

- [ ] **Step 1: Build `ForgeSet`:** brick crucible on chains, mold tray, anvil, hammer model, water barrel, dark backdrop plate, warm point lights; all local, anchored, `CanCollide = false`.
- [ ] **Step 2: Implement the shots** with a Scriptable camera: melt (ores drop and sink, metal rises, final flash of `Rarity.get(rarity).color`), pour (crucible tween tilt, neon stream, flattened neon copy of the gun filling the mold), hammer staging (glowing gun on anvil; parts lerp 25% toward real colors after each `strike`), quench (dip into barrel, steam particles, `Sounds.Poof`). Hide `Hud.screen()` during play; restore after reveal. Skip jumps from melt/pour to hammer.
- [ ] **Step 3: Verify in a playtest** by calling `ForgeCutscene.play` from `eval_client_runtime` with a stub `strike` returning 1: screenshots of each shot; camera returns to the character after reveal.
- [ ] **Step 4: Commit** `feat: add private forge set and forging cutscene`.

### Task 5: Timing game

**Files:**
- Create: `places/main/src/StarterPlayer/StarterPlayerScripts/Controllers/Cutscene/TimingGame.luau`

**Interfaces:**
- Consumes: `GunStats.strikeAccuracy`, `Balance.RING_SECONDS`, `Kit`, `Sounds`.
- Produces: `TimingGame.strike(index: number, screenPoint: Vector2): number` — shows a target circle and a ring shrinking over `RING_SECONDS` at `screenPoint`, waits for any click/tap/ButtonA (or the ring passing 0.32 late), shows PERFECT/GREAT/GOOD/MISS, returns the accuracy. A random 0.25–0.6s pause precedes each ring.

- [ ] **Step 1: Implement** with `UserInputService.InputBegan` (MouseButton1, Touch, ButtonA) and the error fraction measured from the ring's end time.
- [ ] **Step 2: Verify in a playtest** with `simulate_mouse_input` clicks at known delays: a click at ring end → PERFECT/1.0; no click → MISS/0.
- [ ] **Step 3: Commit** `feat: add hammer timing game`.

### Task 6: Wire the Forge menu to the cutscene

**Files:**
- Modify: `places/main/src/StarterPlayer/StarterPlayerScripts/Controllers/Menus/Forge.luau` (Forge button fires `Forge`; on `ForgeStart`, close menus and run `ForgeCutscene.play(start, TimingGame.strike-with-anvil-point)`, then fire `ForgeFinish(token, accuracies)`; on `ForgeResult`, `ForgeCutscene.reveal`; remove the old in-menu overlay; odds panel adds "🎯 Training x.x–y.y" from base power range × `GunStats.oreTrainingFactor`)
- Modify: `places/main/src/StarterPlayer/StarterPlayerScripts/Controllers/Menus/Backpack.luau` (grade badge on cards; detail shows Power, Speed as `fireRate/s (×speed)`, Training Power)

**Interfaces:**
- Consumes: Tasks 3–5.

- [ ] **Step 1: Implement**; if the character dies or resets mid-cutscene, stop the cutscene and fire `ForgeFinish` with the strikes played and zeros for the rest.
- [ ] **Step 2: Verify the full loop in a playtest:** give ores, forge, play the four strikes with timed clicks, confirm the reveal shows grade and three stats and the Backpack matches the server's item; reset mid-hammer and confirm the gun still arrives.
- [ ] **Step 3: Run the CLAUDE.md checks** (rojo build, rojo sourcemap, selene, stylua --check).
- [ ] **Step 4: Commit** `feat: play the forging cutscene from the Forge menu`.
