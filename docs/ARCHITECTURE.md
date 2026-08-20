# ALVEOLUS runtime architecture

## Dependency direction

The runtime is split into an always-running application layer and a pausible
run layer:

```text
Game / navigation / save / HUD
                 |
                 v
             RunSession
                 |
        simulation systems and worlds
                 |
   core data, topology, queries, definitions
                 |
                 v
        render and HUD view adapters
```

UI code may send commands to a `RunSession` and consume view data or signals.
Simulation systems must not call the HUD directly. Save data, research IDs, and
content definitions do not depend on scene nodes.

## Runtime ownership rules

- `RunSession` owns fixed-step ordering, elapsed simulation time, capacity, and
  the deferred `CombatEventQueue`.
- `EnemyWorld`, `ProjectileWorld`, and `PickupWorld` own the active mass-entity
  registries, fixed stepping, capacities and generation-safe resolution.
  Renderers never create, kill, or retarget entities.
- `EnemySpawnRequest` describes a spawn without exposing a partly configured
  node. Position, definition, visual, scaling, phases, source, and priority are
  complete before activation.
- Mass entity references cross system boundaries only as generation-safe
  integer handles created by `EntityHandle`. Long-lived projectile, discovery,
  and timer references must resolve and validate the handle before use.
- Deaths, drops, phase spawns, and removals are queued and applied after the
  current system iteration. A system never removes from a collection that it
  is currently iterating.
- `CombatSpatialGrid` and `CombatQuery` are the sole broad-phase query path.
  Both use `ArenaTopology`, so seam-crossing range, circle, and line queries
  stay consistent with movement. Queries are invalidated after movement and
  entity lifecycle changes, then rebuilt exactly once by the first real
  nearest, circle, or line consumer of that fixed tick. An idle system never
  rebuilds a world-sized grid speculatively.
- `CrowdRenderer` owns the visible representation of common enemies and
  pickups from registration through synchronous release. Configuration and
  registration happen in one fixed step before rendering; the detail fallback
  is selected once per activation and never switches at a population threshold.
  Because ordinary enemy nodes are hidden while batched, the renderer also owns
  their damaged-health bars. Health signals are generation-bound, and release
  removes the corresponding bar synchronously; detailed enemies keep their own
  node-drawn bar and are never drawn twice.
- `ProjectileRenderer` owns one generation-bound MultiMesh slot for every
  gameplay projectile. Projectile nodes remain process-free state shells and
  never duplicate their batched body.
- `FeedbackRenderer` owns the complete lifecycle of up to 80 short combat
  feedback events. `VisualBurst` is a process-free `RefCounted` record; one
  dense MultiMesh upload replaces per-effect particle nodes and draw calls.

### Render snapshot contract

Ordinary enemies, pickups, and projectiles keep one stable render slot for an
entire activation. Fixed ticks publish previous/current position, size, angle,
and tint snapshots. The renderers interpolate those immutable snapshots using
`Engine.get_physics_interpolation_fraction()` and submit one packed buffer per
visual archetype. A torus crossing or newly reserved generation snaps both CPU
snapshots to the same position; release clears the visible slot synchronously
before a node may return to a pool.

Godot 4.7.1's Windows GL Compatibility path must not own physics interpolation
for dynamically updated `MultiMeshInstance2D` objects: under sustained updates
it can corrupt native memory during shutdown. Therefore every mass-render node
sets `PHYSICS_INTERPOLATION_MODE_OFF` before insertion, disables interpolation
on its RID again after insertion, and uses only `MultiMesh.set_buffer()`. Do not
replace this with `set_buffer_interpolated()` or per-slot engine interpolation
without a native and Web regression on the exact supported Godot version.

### Bio-Lumen render-resource contract

`AlveolusVisualTheme` and `AlveolusUIComponents` are the sole public sources
for semantic UI surfaces and actions. Bio-Lumen fills cache their three shader
programs centrally, but each visible fill owns a lightweight `ShaderMaterial`
and supplies its colors, size, radii, and state through regular shader
uniforms. This is intentional: sharing one material through CanvasItem
instance uniforms rendered unset parameters as opaque black in the supported
WebGL Compatibility export even though the native renderer appeared correct.

Bio-Lumen controls must not poll in `_process()`. Their material follows the
control lifetime, state changes update it explicitly, and released screens
must return live material, node, and callback-owner counts to the warmed-up
baseline. Reintroducing shared mutable materials or CanvasItem instance
uniforms requires both native and exported-Web visual regression evidence;
native captures alone are insufficient.

## Fixed-step phases

The canonical fixed-step order is:

1. `INPUT`: apply queued player commands.
2. `CLOCK`: advance run clocks and cooldowns.
3. `SPAWN`: create fully initialized telegraph states.
4. `ENEMY`: lifecycle, movement, and contact.
5. `QUERY`: invalidate spatial indices after movement; the first consumer
   prepares the required enemy or pickup grid lazily.
6. `COMBAT`: treatment, abilities, defense, and support.
7. `PROJECTILE`: projectiles and pickup movement.
8. `EVENT`: apply damage, deaths, drops, and requested spawns.
9. `SNAPSHOT`: publish one consistent render snapshot.

`Game` is currently the compatibility facade registered with `RunSession` and
invokes the worlds/controllers in exactly this order. `RunSession` also accepts
independent systems through `register_system()`/`register_callable()`; a later
system never runs after pause, finish or cancellation in the same tick.

## Integration path

The core classes are deliberately usable with the current Node runtime:

- Give active nodes a slot and generation in a small registry.
- Register current enemy, projectile, and pickup nodes with `EnemyWorld`,
  `ProjectileWorld`, and `PickupWorld`. Registration disables their automatic
  physics callback; the world invokes their public `step_fixed(delta)` method.
- Configure `CombatQuery` with Callables that resolve handle position, radius,
  targetability, and the underlying node.
- Replace direct spawn argument lists with `EnemySpawnRequest`.
- Queue current signal outcomes in `CombatEventQueue`; flush after each combat
  phase rather than erasing arrays inside signal callbacks.
- Move orchestration behind `RunSession` one system at a time while retaining
  the existing `Game` signals as the external facade.

Mass entities keep pooled scene nodes only as data/compatibility shells; their
automatic physics callbacks are disabled and the worlds step them centrally.
The stable registries can later replace those shells with packed data without
changing save version, definition IDs, RNG inputs, rewards or public UI flow.

## Progression and save compatibility

The active product plan contains exactly one treatment and up to two active
abilities. Passive modules and Reserve are not active catalog or preparation
features. `PreparedLoadout.passive_ids`, `PreparedLoadout.reserve_id`, legacy
`LoadoutSlotId` values and the embedded loadout adapter remain only as stable
schema boundaries for old-save roundtrips. Every policy-sanitized effective
plan copy clears those compatibility fields; reintroducing them requires a new
product decision.

Research ownership and preparation availability are separate contracts.
`LoadoutAvailabilityPolicy` is the sole selection gate: Precision Treatment is
the starter, Spread Treatment and Piercing Treatment require their respective
research ranks, and Defense Burst plus Treatment Line are the two selectable
active abilities. Focus Field, Emergency Aid, Protection Field and Sample Pull
remain visible but unavailable. The UI may explain a locked definition, but it
must never infer availability from the mere existence of a stable content ID.

There are eight global research definitions. Six are applied directly through
`PlayerStats.apply_meta_progression()` to maximum life, treatment damage,
sample experience, defense, life regeneration and movement speed. Two unlock
the additional treatments. None of these effects depends on an equipped
passive module. `RunBuildState.MOVEMENT_SPEED` is the common research/run-build
surface; `TherapyAvatar` reads its resolved fixed-step value from `PlayerStats`.

Savegame version 6 and `talent_tree_revision` 4 are the current outer formats.
The treatment tree contains exactly four ranked definitions: the root
Treatment Damage Training plus Spread Penetration, Manual Treatment Aim and
Piercing Persistence. `piercing_return` is absent from the active catalog and
its ID remains retired. Loading revision 3 discards/refunds that whole
selection atomically while preserving mastery, research and earned points. The
inner loadout adapter can retain its older schema version independently; it is
not the savegame version.

The temporary unlimited progression mode is runtime configuration rather than
save data and must be set on `MetaProgressionState` before deserialization. In
that mode both research and talent economies expose a resettable one-billion
point pool. Current-revision selections are still validated atomically against
stable IDs, rank limits, prerequisites and the active economy mode.

## Typed damage and player durability

`DamageProfile` stores a normalized composition over the fixed order `fire`,
`water`, `earth`, `wind`. Treatments, damaging
active abilities, defense cells and enemy contact attacks own explicit damage
profiles. New authoring calls reject unknown IDs. Only the explicit
`from_legacy_authoring_components()` boundary may canonicalize retired
`blood -> fire`, `holy -> water` and `undead -> wind`; retired IDs are never
accepted by the active catalog or reused.

`ResistanceProfile` stores authoring ratings but compiles fixed four-value
effective-percent and multiplier buffers once. Positive resistance uses
`75 * rating / (75 + rating)` percent; negative ratings are linear
vulnerability down to -100 percent. `CombatDamageResolver` reads only those
packed buffers, then applies defense using the same curve with cap 90. Shield
and life run after resistance and defense. The hit hotpath performs four fixed
iterations without dictionaries or temporary profile allocations. UI and
lexicon presentation receive effective percentages only, never raw ratings or
the formula.

## Combat distance, body size and presentation DTOs

`CombatDistanceScale` is the sole conversion boundary for effect radius and
range: one stage equals 30 world units. Definitions normalize through it,
`RunBuildState.value()` applies all modifiers first and quantizes staged stats
once, and previews call the identical resolver. UI/VM data contains stages,
never render units. Body radii remain exact query geometry and are classified
separately by `BodySizeCatalog`; `Game` supplies
`BodySizeCatalog.maximum_radius(enemy_definitions)` to `CombatQuery` instead of
a magic maximum. Range checks and ordering use distance to the body surface,
while `CombatSpatialGrid` and `CombatQuery` keep exact radii.

Enemy crowd spacing is a separate presentation/locomotion envelope exposed by
`InfectionEnemy.crowd_radius()`. `EnemyWorld` rebuilds a dedicated 64-unit grid,
examines a bounded local broad-phase window, keeps the six nearest bodies and
refreshes each steering slot at 10 Hz while movement stays at 60 Hz. The body
closer to the avatar owns the lane. Its follower selects one passing side, keeps
that side through a short hysteresis window and follows a continuous unit-speed
boundary relative to the leader's resolved velocity. Bodies behind a pursuer
never steer its front line; no reciprocal displacement or position repair is
allowed. Contact is a separate latched state: the unblocked front body reaches
the true contact shell and attacks. If the avatar stands still, a reduced,
non-zero passing speed propagates through the local queue behind that latched
front; normal avoidance and movement around a moving avatar retain authored
speed. Model factors approximate the visible body core, not its decorative outer pixels.
Standard waves retain the deterministic golden-angle stream as a tie-breaker
while the actual spawn direction fills the least occupied of twelve sectors.
Materializing enemies count immediately, so one batch cannot collapse into a
single off-screen corner.

`PlayerStats.stat_sections()` returns defensive-copy `StatSectionViewModel`
data with stable IDs `general`, `treatment:<content-id>`,
`ability:0:<content-id>` and `ability:1:<content-id>`. Expansion state remains
UI-owned. Values are resolved from the bound `RunBuildState` when the DTO is
created, so opening the pause screen cannot fall back to run-start values after
an upgrade. `PlayerStats.stat_rows()` remains a read-only compatibility adapter
for the current GameHUD group keys until that facade consumes the section API;
it exposes stages rather than render units. `LexiconEntryViewModel.type_presentations()`
likewise returns a defensive array of immutable four-type DTOs. Each item
contains type/icon ID, expanded name, semantic role, effective percent/share,
ready-formatted value, meaning and indicator; the order within each role is
fire, water, earth, wind.

`MetaProgressionState.calculate_run_reward()` is the pure reward preview and is
the only arithmetic used by `award_run()`. A loss preview therefore shares the
same multiplier, rounding and minimum with the eventual mutation.

The event-driven intro uses `GameFlowState.State.INTRO_CONFIRMATION` for its two
blocking explanations. That state pauses both `RunSession` and the scene tree;
only `GameHUD.run_prompt_confirmed`, emitted by the topmost left-click prompt,
may resume it. The first observation timer begins on `InfectionEnemy.materialized`,
not on the spawn request. Three ordinary one-point pickup events feed the same
`RunState` analysis target of three and the three-card treatment-only pool is
applied through the same bound `RunBuildState` as the rest of the run. Intro
learning events mark their discovery IDs as seen without entering the discovery
modal flow.

Save v6 retains `ui_scale` and `glyph_mode`, but the current runtime normalizes
them to 1.0 and keyboard/mouse. Those legacy fields therefore remain readable
without allowing an old scale or forced-gamepad value to alter this milestone's
visible runtime.

## Case lifecycle and variation

Product cases use `total_seconds <= 0` to mean no run deadline and schedule
their boss at 180 seconds. The player baseline is 100 life. A case with no prior
completion starts without a trait or finding; subsequent attempts derive both
from the saved case seed. That seed advances only after a successful non-intro
result, so failure and cancellation cannot silently reroll the case.

`minor_focus` participates in the normal centralized enemy movement path with
base speed 20 before case modifiers. It remains a detailed,
generation-safe spawning objective and releases four bacteria after its
20-second lifecycle if it survives; mobility does not authorize a per-entity
process loop or a second renderer.

Enemy ranged attacks are scheduled by the fixed-capacity `EnemyAttackDirector`.
It stores only generation-safe `EnemyWorld` handles and timers. Hostile shots
reuse `TherapyProjectile` simulation records and `ProjectileWorld`, but occupy
a separate stable `ProjectileRenderer` batch with a distinct texture. Release
clears both possible render owners before a projectile node returns to its
pool. Boss phase adds preserve their shooter role through deferred spawn
metadata; the first boss starts its repeating four-add schedule only after its
second phase.

`EnemyWorld` owns one predictive body-avoidance pass before enemy movement. It
rebuilds one `CombatSpatialGrid`, samples only the local neighborhood and
constrains the next preferred velocity. Preferred envelopes cover the visible
body core. A stable per-slot approach-lane bias prevents all pursuers from
choosing the same center line, while a short time horizon slows converging
bodies before a rear body can enter the front row. Steering refreshes at 10 Hz
and locomotion remains at 60 Hz. It never repairs positions after movement.
Only `pneumococcus` yields to avatar pressure;
larger bodies publish one blocking normal to `TherapyAvatar`, which removes
only movement into that body and keeps tangential escape available. Entities
must not add independent collision polling or pairwise O(n²) scans.

Knockback state lives on `InfectionEnemy` and advances inside the existing
typed EnemyWorld loop. `Stoß` supplies a distance, short eased travel duration
and one-second stun. While stunned, chase/contact handling and
`EnemyAttackDirector` projectile scheduling are suspended. `CrowdRenderer`
tracks only the generation-bound stunned subset and draws the tiny shared CC0
status icon; it does not introduce per-enemy process owners.

`ArenaBackdrop` precomputes the coral dashed torus seam and its eight corner
segments during `configure()`. They are part of the existing one-shot static
SubViewport bake. The viewport returns to `UPDATE_DISABLED`, the short bake
callback stops, and reconfiguration reuses the same viewport/canvas nodes.

## Defense-cell hit contract

`DefenseCellWorld` owns defense-cell gameplay in the fixed `COMBAT` phase. The
avatar may render the orbit snapshot but must not apply damage. Every cell
queries `CombatQuery.circle()` at its actual topology-wrapped world position,
selects at most one generation-safe enemy handle and starts its own cooldown
only after a valid geometric hit. The current base trigger interval is 0.2
seconds per cell. The 0.1-second minimum remains the hard lower bound for later
attack-speed upgrades. Cell count, hit radius and damage come from `RunBuildState`; a single
shared avatar-centered area may not substitute for these geometric contacts.

## Feature contribution rule

A new mass enemy or mechanic is added as:

1. data definition and stable IDs;
2. world/system behavior;
3. query participation where needed;
4. render profile keyed by `visual_id`;
5. isolated correctness and budget tests.

Do not add per-enemy `_process()`/`_physics_process()`, direct HUD calls from a
simulation system, hot-loop `filter()`/`sort_custom()`/deep duplication, or an
unbounded fallback allocation when a capacity is exhausted.
