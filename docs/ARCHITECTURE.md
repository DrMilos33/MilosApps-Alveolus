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
- `RunConfig` owns the authored standard-spawn density curve;
  `StandardWaveDirector` is the sole owner of its run-local packet clock,
  isolated content RNG, pending intents and generation-safe membership. The
  elapsed gate time accrues spawn credit at 1.10 times the established density;
  clearing a wave early therefore releases a smaller packet instead of creating
  extra enemies or EXP. Its successor opens after at most 4.5 seconds or, after
  a two-second lockout, when at least 70 percent of the current packet weight
  has been defeated. At most four
  bodies materialize per fixed tick, pending intent state is bounded to 64 and
  the 145-weight gameplay cap freezes the gate without debt. The six campaign
  cases and the spawn/obstacle practice tests use this path. Tutorial enemies,
  boss-only practice, bosses, phase reinforcements, pressure targets and finding
  spawns remain event-authored exceptions. Boss start and run end cancel all
  pending standard-wave state before handles can be reused.
  Every standard-wave intent captures `RunConfig.regular_enemy_health_scale()`,
  which resolves to the authored case baseline for the entire run. Generic
  spawns and boss adds use the same baseline; explicit request and boss health
  overrides still take precedence.
- `CombatSpatialGrid` and `CombatQuery` are the sole broad-phase query path.
  Both use `ArenaTopology`. `WRAP` remains the explicit compatibility mode;
  playable runs select `BOUNDED`, whose direct distances, clamped cell ranges
  and ray limits prevent movement, targeting or feedback across an opposite
  edge. Queries are invalidated after movement and
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
visual archetype. A topology relocation or newly reserved generation snaps both
CPU snapshots to the same position; release clears the visible slot synchronously
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

The core registries, generation-safe handles, spawn requests, event queue and
snapshot renderers are already the durable foundation. Further decomposition
is deliberately serial and begins only after the current crowd behavior has
passed the manual gameplay acceptance:

1. Remove the unreachable ring, lane, queue and predictive-steering path from
   `EnemyWorld` and the corresponding compatibility fields from
   `InfectionEnemy`; keep the accepted direct-collision path unchanged.
2. Add flow-invariant tests, then introduce an internal `AppFlowCoordinator`
   that updates route, modal, focus, tree pause, `GameFlowState` and
   `RunSession` as one transition. `Game` remains the public facade.
3. Move launch flags, test switches and smoke-harness orchestration out of
   `Game` without changing production startup.
4. Register the fixed-step phases with `RunSession` one at a time. Every slice
   preserves phase order, RNG trace, pause semantics and determinism hash.
5. Put enemy, projectile and pickup lease/pool/render-slot changes behind
   small lifecycle services so activation and release stay atomic.
6. Extract preparation presentation and its immutable view models from
   `GameHUD`; the facade keeps its public signals and methods while screens
   emit intents only. Presenters, not `Game`, format domain values.
7. Add caller-owned `CombatQuery` buffers only for a hotpath demonstrated by
   profiling; do not add speculative query abstractions.

Each wave is a separate local commit and focused task. Save version, content
IDs, public Game/HUD signals and the deterministic gameplay trace stay
compatible throughout. A possible process-free `EnemyCrowdMotionSolver`
extraction is considered only after the dead path is removed and profiling
shows that the remaining `EnemyWorld` boundary is still too broad.

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

There are ten research definitions. Six are applied directly through
`PlayerStats.apply_meta_progression()` to maximum life, treatment damage,
sample experience, defense, life regeneration and movement speed. Two unlock
the additional treatments and two unlock the selectable active abilities.
None of these effects depends on an equipped
passive module. `RunBuildState.MOVEMENT_SPEED` is the common research/run-build
surface; `TherapyAvatar` reads its resolved fixed-step value from `PlayerStats`.

Run upgrades are grouped by the resolved `<component>:<family>` key. Damage,
attack speed and movement families contain weighted Common, Magic and Rare
definitions, but `UpgradePoolBuilder` may offer at most one rarity of a family
in one choice. `PlayerStats` retains per-definition counts for modifier-source
stability and a separate aggregate family count for UI and weighting. A
repeatable definition ignores `max_level`; finite utility upgrades keep their
cap in data while `show_cap == false` prevents that implementation limit from
leaking into the card. Reroll exclusion expands from a picked ID to its whole
resolved family.

Savegame version 7 and `talent_tree_revision` 4 are the current outer formats.
The v6-to-v7 migration maps the old highest completed campaign order
`0/1/2/3` to `0/2/4/6` while retaining stable case IDs, records, seeds,
loadouts, talents and already claimed research. Retired offline-research and
clinic-job fields are read only as legacy input and are never written again.
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
while `CombatSpatialGrid` and `CombatQuery` keep exact radii. Enemy damage
contact uses the separately authored `EnemyDefinition.contact_radius`; it is
slightly smaller than the visible enemy core and does not alter targeting,
projectile hits, body-size classes or crowd spacing.

Enemy locomotion starts with one direct-pursuit proposal. Every mobile
`InfectionEnemy` recomputes the shortest direction to Doctor Milos on every
fixed tick and clamps that tick's travel to its separately authored
damage-contact shell. `EnemyWorld` then resolves the proposal against other
targetable enemies. The minimum center distance is exactly the sum of both
`contact_radius` values, and a free path remains perfectly direct.

When the exact sweep identifies a real body nearer to Doctor Milos within an
eight-world-unit activation envelope, the phased guard refresh evaluates both
short side corridors from the complete local
`CombatSpatialGrid` candidate buffer before reducing collision guards to the
nearest fixed set. The exact first swept front body is then retained in that
small guard set even when three other surfaces are nearer. Each corridor
sweeps the follower's contact circle for up to three own contact radii, capped
by the existing guard lookahead. The
triggering front body is excluded from this occupancy test; all other active
bodies and the hard arena boundary count. If both corridors are closed, the
follower waits without an intentional lateral component. If one is open, the
generation-safe blocker lease binds that side. If both are open, greater
clearance wins and slot parity resolves an exact tie deterministically.

A new side lease is valid only when that complete corridor sample was produced
in the current fixed tick. If a body reaches the activation envelope between
its distributed refresh phases, it keeps its exact direct pursuit until the
first swept contact circle and waits only at that physical boundary. An old
closed sample may therefore neither stop it early nor invent a lateral route.
The ordinary disc projection is only a safety boundary: without a valid lease
it may never preserve a tangential remainder. This makes the three runtime
outcomes explicit without adding per-entity objects: direct pursuit, one
verified bypass side, or stationary wait at real contact.

An active lease never switches sides or front bodies directly. A phased refresh may close its
route, which clears the lease and leaves the follower waiting until a later
refresh can acquire a valid corridor; otherwise five consecutive free fixed
ticks release the lease. A later episode prefers its previous side whenever
that side remains valid. Between full samples the selected side is checked
cheaply against the hard arena, its generation-safe side blocker and the fixed
nearest-contact guard set. A second body entering the leased route stalls the
tick and cannot trigger an immediate opposite-side switch. Handles and the
current blocking body are validated every tick, while spatial guard/corridor
queries are distributed over 24 slot phases. A queued body retains the exact
generation-safe contact body and validates only that physical contact in the
per-tick hot path. Its closed corridor also retains the body closing each side;
only at the slot's scheduled phase are those two sweeps revalidated. If both
still intersect, the full neighborhood query is unnecessary. Releasing the
contact body wakes the follower in the next fixed tick; moving or invalidating
a side body restores the complete query at the next distributed phase.

When Doctor Milos has no actual displacement in the current fixed tick, an
already verified lease may replace its straight tangent with one short chord
along the leased body's contact boundary. The chord keeps the established side,
must not increase distance to the Doctor, and is accepted only inside the arena
and outside the cached contact bodies. A stationary collision solution retains
at most eight earliest forward-contact guards so differently sized bodies at a
mixed outer edge preserve every authored contact circle while continuing along
a physically open boundary. The ordinary eight-world-unit activation envelope
still applies; a distant body never starts a proactive side route. A genuinely
sealed contact shell therefore remains still, while a physically open edge can
keep feeding attackers without a waypoint, push force or global path search.

Every moving-Doctor tick retains the established maximum of three guards. A
stop-to-move transition forces an immediate local guard refresh before movement,
and the stationary blocker hold no longer participates once the Doctor moves.
The wider stationary cache adds no spatial query and cannot leak into the
accepted moving path. Final contact validation uses only a numerical epsilon
below the authored radius sum, never a smaller gameplay body.

Registration, release, ordinary movement, avatar push and explicit relocation
update the same grid incrementally; a full rebuild is only the recovery path
after topology configuration or an unlocated relocation. A queued body uses a
stationary fixed-step that preserves visual, cooldown and contact clocks, and
`EnemyWorld` batches exact deferred contact checks behind one local grid query.
This preserves post-movement contact semantics without scanning every distant
enemy against the Doctor. No per-enemy node, timer, dictionary or second
spatial index is introduced. Knockback and stun remain the only systems
permitted to intentionally move an enemy away from the Doctor. `EnemyWorld`
remains the single typed fixed-step owner; entities add no process loops.

Large ordinary contact islands use an additive bulk-flow layer above that
single-body contract. Every 0.25 seconds `EnemyWorld` derives connected
components from the same authored contact circles with at most four world units
of surface gap. A small bacterium contributes weight one and a bacterial cluster
weight two. Two completed snapshots with weight at least six and at least 25
percent queued weight activate one generation-safe lease; four snapshots below
weight four or below ten percent queued weight release it. The lease chooses the
less occupied lateral side once and blends a maximum 20-degree arc into the
unchanged direct-pursuit step.
The accepted endpoint is still bounded by the arena, the Doctor-distance
monotonicity check and the cached contact circles. The component stores the
maximum effective member speed in packed root/member arrays and blends every
active member toward that shared speed with the existing lease blend. It still
cannot retreat, overlap, teleport or create combat state. A physically exposed
local front body inside the final 24-world-unit attack margin drops only the
lease's lateral arc and keeps the shared speed directly toward Doctor Milos;
this prevents the faster component from becoming a closed nonattacking shell.
Stun and knockback
transitions invalidate only the affected slot and cached local neighbors; a
stale closed-corridor fast path may never survive the transition back to chase.
Final bulk and bypass validation distinguishes a new or deepening contact-circle
penetration from a rare pre-existing one. A fixed step that preserves or
increases separation is allowed to drain that old overlap; rejecting it would
recommit the same origin and could freeze the slot indefinitely after knockback
or a phased guard update. The check is allocation-free and adds no query.

The topology snapshot is built into a double buffer over four fixed ticks. Its
limited broad-phase query retains the nearest seven exact bodies per member
inside a 41-world-unit surface horizon; this scales the cache to the current
85-world-unit maximum ordinary base speed without changing steering;
front-to-back resolution consumes only that packed cache and commits through the
existing spatial grid. A routed mover with cached group neighbors uses this same
bounded solver even while an obstacle temporarily splits the connected
component. Profiling counters expose snapshot count, active ticks, examined
projection candidates and solve time without production dictionaries.
Bosses, minor foci, ranged roles and tutorial enemies are disabled at
registration. An explicit relocation invalidates only the current lease and
cache while preserving whether an ordinary enemy may join a later island.
Regular timed waves stop at 145 weighted melee units; critical, boss and
case-pressure allocations remain governed by `CombatCapacity` and its reserved
slots rather than this ambient gameplay cap.

Authored stationary bodies use the complete `EnemySpawnRequest` pair
`BodyRole.STATIC_FLOW_OBSTACLE` and `ObstacleTraversal`. The pair survives
duplication and deferred activation; `InfectionEnemy.recycle()` restores
`MOBILE`/`DEFAULT`. `DEFAULT` resolves to `FLOW_AROUND` for non-bosses and
`PHASE_THROUGH` for bosses, while an explicit request may override either
route. Static obstacles reject displacement and knockback, never join a bulk
component or offscreen relocation, and register through packed per-slot flags
and generation-safe handles. Release clears every guard and lease naming the
old generation; same-slot reuse resets that slot's obstacle and route state
before it may represent another generation.

Every four fixed ticks, `EnemyWorld` queries outward from each active obstacle
through the existing `CombatSpatialGrid` and retains at most four obstacle
handles per nearby mover. A finite sweep entry at the current fixed-step length,
not mere presence in the discovery horizon, starts a route and chooses one stable
circular side from the mover's existing direct-guard or bulk-neighbor cache;
clearance wins, then Doctor progress, then deterministic slot parity. Each tick
reconstructs an exact constant-time chord from the authoritative position toward
the Minkowski circle consisting of mover radius, obstacle radius and 0.05 skin.
If the ordinary pursuit reaches its Doctor contact shell while that contact path
is still blocked, a non-boss derives one deterministic point beside Doctor on
the already leased side and outside the mover-expanded obstacle. Direct and bulk
projection temporarily measure progress against that point instead of rejecting
the valid lateral chord against Doctor distance. Once the actual path to the
Doctor contact shell is clear, ordinary Doctor pursuit owns movement again.
Only the locally clear front mover may blend from base speed to 1.25x over 0.15
seconds; the blend leaves over 0.20 seconds and a body-blocked follower remains at
base speed.

A geometrically open route never waits: the exact chord is recomputed every tick
and the group solver consumes relative same-tick motion. If both sides are sealed
only by static geometry, the object-only fail-open begins at the actual blocked
contact instead of after a visible 0.8-second stall. Until the mover has cleared
every active static obstacle plus the release margin, only those obstacle bodies
are ignored; ordinary enemy bodies, Doctor contact, arena bounds, statuses and
generation remain authoritative. This path adds no teleport, global steering
graph, per-entity process or timer, dictionary or second spatial index. The
Doctor-side point is allocation-free O(1) geometry derived from packed lease
state each active tick; it is never published as an entity combat target.

`CasePressurePlan` is authored on `LevelDefinition`, copied defensively into
`RunConfig` and consumed by one seed-isolated `CasePressureDirector` after the
run clock advances. It never reads player movement, aim or the standard spawn
RNG. Due targets use complete critical `EnemySpawnRequest` records and
generation-safe handles; their small lifecycle dictionaries live on the Game
facade because at most two exist. Target expiration is applied only after the
combat event flush, so a same-tick defeat wins and cannot lose its pickup or
reward. The fixed-step owner emits target fans and Case-3 gates through the
existing pooled `ProjectileWorld` and hostile renderer. Regular projectiles
stop 48 slots below technical capacity; only authored pressure patterns may use
that reserve. Gate IDs remain attached to pooled projectiles until the final
member finishes, enforcing one incoming hit per wall without per-projectile
process state. Boss start cancels pending schedule/gates. Offscreen target HUD
state is published with the render snapshot; a visible boss arrow always has
priority.
The plan also owns optional per-target movement, attack-rate and projectile-width
multipliers. Fall 1 uses those fields for its mobile event focus; the activation
stores the resolved rate and width on `InfectionEnemy`, and the existing attack
director, projectile simulation and renderer consume them without changing the
shared `EnemyDefinition` used by hidden nests or later target foci.

Before the avatar step, `EnemyWorld.prepare_avatar_body_interaction()` resolves
the same authored contact circles from the player's side. Ordinary mobile
non-bosses receive a bounded physical push by default and therefore yield
gradually without changing either movement stat or applying a slow status. The
shared yield cap is 72 world units per second, forty percent of the base Galopp
value, so contact is easier to work through but never equals free travel.
`EnemyDefinition.player_push_enabled` is the explicit opt-out; bosses and
`STATIC_FLOW_OBSTACLE` bodies always hard-clip the proposed avatar displacement.
The contacted body still cannot cross another contact circle or the arena edge.

Standard-wave placement evaluates twelve sectors around the current camera.
Only enemies on screen or in the near offscreen band contribute pressure;
closer bodies count more and a bacterial cluster counts twice. A packet leases
one, two or three separated fronts from the lowest-pressure sectors according
to its size. Its bodies receive small deterministic angle offsets and remain
beyond the actual viewport until they enter together.
Materializing enemies publish their leased render slot immediately, so a batch
does not create a transient invisible frame.

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
same multiplier, rounding and minimum with the eventual mutation. All positive
research income uses the central 3.75 gain factor; purchases and refunds do not.
Run rewards apply `1 + 0.25 * bosses_defeated` once before the single final
rounding. The one-time intro grant is exactly 30 for completion or skip and
deliberately bypasses the boss multiplier, so it equals the canonical Stoß
unlock cost without creating surplus research.

`UISettingsState.show_discovery_info` is an additive Save-v7 setting with a
default of `true`. When disabled, `Game` drains requested discoveries through
`DiscoveryManager.complete_active()` without entering `DISCOVERY_PAUSE`; IDs
remain unlocked and cannot accumulate into a later modal backlog. It does not
disable guided intro prompts or campus guidance.
`UISettingsState.show_character_health_bar` is another additive, default-false
setting. `RunState.stability_changed` publishes its cached current/maximum values
to `TherapyAvatar`, which draws a small numberless world bar only when enabled;
the accessible central HUD bar remains authoritative and always present.

The event-driven intro uses `GameFlowState.State.INTRO_CONFIRMATION` for its two
blocking explanations. That state pauses both `RunSession` and the scene tree;
only `GameHUD.run_prompt_confirmed`, emitted by the topmost left-click prompt,
may resume it. The first observation timer begins on `InfectionEnemy.materialized`,
not on the spawn request. Three ordinary one-point pickup events feed the same
`RunState` analysis target of three and the three-card treatment-only pool is
applied through the same bound `RunBuildState` as the rest of the run. Intro
learning events mark their discovery IDs as seen without entering the discovery
modal flow.

Save v7 retains the legacy `ui_scale` and `glyph_mode` fields, but the current runtime normalizes
them to 1.0 and keyboard/mouse. Those legacy fields therefore remain readable
without allowing an old scale or forced-gamepad value to alter this milestone's
visible runtime.

Practice tests are a debug-build-only runtime surface, not campaign content.
`PracticeScenarioDefinition` and `PracticeBossProfile` live outside
`ContentCatalog.level_definitions()` and are carried through an explicit
`RunContext.Mode.PRACTICE_TEST`. Practice results bypass discoveries, findings,
mastery, rewards, records and every meta-save mutation. The separate
`user://alveolus_test_tools.cfg` owns immunity, outgoing-damage and movement
test values; it is never serialized through `UISettingsState` or
`MetaProgressionState` and its UI is absent outside debug builds.

## Case lifecycle and variation

The campaign catalog contains the intro plus exactly six ordered cases.
Existing stable IDs remain the anchor cases at orders 2, 4 and 6; the new
orders 1, 3 and 5 are data-authored interpolation cases. Start populations,
spawn-ramp duration, pressure-object mobility and automatic boss activation
are `LevelDefinition`/`RunConfig` data, never inferred from a numeric order.
This keeps unique boss mechanics discrete while wave pressure can progress
linearly between the preserved anchor cases.

Product cases use `total_seconds <= 0` to mean no run deadline and schedule
their boss at 300 seconds. Their standard spawn ramp uses the same 300-second
horizon and 125-percent authored intervals, producing roughly four thirds of
the previous total over five minutes at free capacity. The player baseline is
50 life. A case with no prior
completion starts without a trait or finding; subsequent attempts derive both
from the saved case seed. That seed advances only after a successful non-intro
result, so failure and cancellation cannot silently reroll the case.

`minor_focus` participates in the normal centralized enemy movement path with
base speed 38 before case modifiers. It remains a detailed,
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
second phase. Projectile geometry is data-driven: the later special boss emits
its two phased diamond shots at 212.5 world units per second and a 25-percent
larger authored amplitude; ranged phase adds use 322.5. The intro boss emits one
ordinary hostile projectile per attack interval. The Fall-1 boss configures a
director lease that requests four shooting small bacteria every 15 seconds from
phase zero. Periodic and phase adds use a 2.0 attack-rate multiplier. Its
Game-owned 10 Hz aura query reuses the existing enemy collision grid, applies
one named 1.45 speed/damage status to nearby nonbosses inside a radius equal to
60 percent of the shorter visible dimension, and generation-safely enables the
boss projectile lease only while that local query contains no materialized
nonboss. Its own double-turn projectile uses a 1.3 travel-speed multiplier. Aura
status is removed on exit, death, reuse or run cleanup. Boss locomotion remains direct and ignores all
enemy-enemy contact circles in both directions; Doctor contact, damage, stun,
knockback and bounded-arena constraints remain unchanged. The HUD resolves at
most the active boss handles once per fixed snapshot and drives one process-free
edge arrow only while a boss body is fully outside the actual camera rectangle.

Case-pressure combat and presentation modifiers are copied from the immutable
plan into scalar activation fields on `InfectionEnemy` and cleared on recycle.
The Fall-1 target resolves to speed 60, 1.875 attack-rate, 1.95 projectile-speed
and width multipliers; a zero-damage Stoß control hit pauses only its projectile
timer for ten seconds. The Fall-2 target remains one gameplay entity with shared
health: its composed bacteria texture and repeated bars are presentation-only,
while only source `ability_treatment_line` receives its 10x incoming multiplier.

The Fall-2 boss uses one pooled `HOSTILE_DOUBLE_TURN` projectile per shot. The
first and second leg distances are frozen from the shorter visible world extent
at spawn, and the fixed-step projectile consumes overshoot piecewise before each
same-direction 90-degree turn. A packed per-handle sequence alternates turn side.
Its periodic and phase adds receive a per-activation permanent Stoß shooting
lock; generations, recycle and director release clear every timer and sequence.

The Lexicon catalog has five stable presentation categories, including
`abilities`; its entries are derived from the complete `AbilityDefinition`
catalog and its view-model facts remain stage- and data-driven. Preparation
publishes timing intelligence separately from the values: campaign duration and
boss facts are created only after `has_completed_level(exact_id)`, while debug
practice scenarios keep their timing visible. Trait facts are never hidden by
this progressive reveal.

The relocation director snapshots the complete eligible offscreen backlog every
0.5 seconds instead of deriving sources from the local target-pressure window.
The same single pass also determines the adaptive budget: every 12 eligible
bodies add one move to the half-second snapshot, capped at eighteen moves or 36
moves per second. Those generation-safe handles are executed at evenly spaced
times inside the snapshot window, at most one per fixed tick; the director does
not increase its full-world scan frequency as pressure rises. The most distant
body in the strongest backlog sector is preferred. A dedicated deterministic
RNG stream chooses among several calm target sectors outside the source sector
and its direct neighbors, then jitters angle and adds a bounded continuous depth
offset around one of three offscreen bands. At most two targets reserve one
sector per snapshot, and target search
uses a bounded local broad-phase attempt window. The full body plus a
24-world-unit safety margin must remain outside the actual camera
rectangle; there is no visible fallback. A source still lies at
least 72 world units beyond the camera and the same entity cannot move again for
three seconds. Relocation preserves generation, health and status and
atomically snaps renderer history. It is denied for bosses, minor foci, ranged
roles, tutorial roles, stunned or recently damaged/knocked bodies. Runtime
locomotion still performs only the bounded local contact-circle query described
above; it never gains a global steering target.

Knockback state lives on `InfectionEnemy` and advances inside the existing
typed EnemyWorld loop. `Stoß` supplies a distance, short eased travel duration
and one-second stun. The same `player_push_enabled` contract controls its
translation; bosses retain the stun but never change position. While stunned,
chase/contact handling and `EnemyAttackDirector` projectile scheduling are
suspended. `CrowdRenderer` tracks generation-bound status subsets without
per-enemy process owners. It draws the tiny shared CC0 star for stun and, on the
separate `shooting_lock_changed` edge, a small procedural question mark above
that row for a Stoß-disabled projectile attack. Both records are cleared on
expiry, release and generation reuse.

`ArenaBackdrop` precomputes the coral dashed hard boundary and its eight corner
segments during `configure()`. They are part of the existing one-shot static
SubViewport bake. Logical arenas may exceed GPU-safe texture dimensions; the
bake preserves aspect ratio while capping its longest texture edge and then
maps that immutable result over the full 8,640 × 4,860 world rectangle. The
viewport returns to `UPDATE_DISABLED`, the short bake callback stops, and
reconfiguration reuses the same viewport/canvas nodes.

## Defense-cell hit contract

`DefenseCellWorld` owns defense-cell gameplay in the fixed `COMBAT` phase. The
avatar may render the orbit snapshot but must not apply damage. Every cell
queries `CombatQuery.circle()` at its actual topology-resolved world position,
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
