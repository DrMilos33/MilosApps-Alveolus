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

## Progression compatibility

The visible plan currently contains treatment, two active and two passive
slots. `LoadoutSlotId.RESERVE`, `PreparedLoadout.reserve_id`, version-5 save
adapters and catalog IDs remain intact solely for old-save roundtrips; new plan
drafts clear the Reserve and the UI does not expose it. Reintroducing it is a
product decision, not a schema migration.

Talent definitions keep stable IDs, costs and effects while their topology may
gain prerequisites. Saves therefore carry an additive `talent_tree_revision`.
Loading an older revision performs one complete talent-selection refund while
preserving mastery completion and every earned point. It must never silently
discard only the now-invalid descendants.

The temporary unlimited progression mode is runtime configuration rather than
save data and must be set on `MetaProgressionState` before deserialization.
Current-revision talent selections are validated atomically against stable IDs,
prerequisites and the active economy mode. A rejected overspent selection is
cleared as one refund state; partial descendant pruning is forbidden. Likewise,
interactive refunding proceeds from leaves toward the root so one parent click
cannot silently remove several active talents.

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
