# ALVEOLUS ability pipeline

Active abilities cross three strict boundaries:

1. Input creates an `AbilityCommand`. Enqueuing it does not mutate gameplay.
2. `AbilityController` drains commands in ascending sequence order during the
   fixed combat phase and returns one `AbilityExecutionResult` per command.
3. Gameplay state consumes the result immediately. `AbilityFeedbackWorld`
   receives the same immutable-by-convention snapshot and visualizes only its
   geometry.

`use_slot()` remains a synchronous adapter for the current game facade. New
input code should use `enqueue_command()` and let `RunSession` call
`step_fixed()` after rebuilding `CombatQuery`.

## Runtime ownership

- `GameplayZoneWorld` exclusively owns focus and protection fields.
- Zone handles use `EntityHandle(slot, generation)`. A stale zone or enemy
  handle can never resolve a pooled replacement.
- `CombatQuery` supplies all area and line candidates. A legacy Node-provider
  fallback exists only until the game facade completes its integration.
- Cooldowns start only after a successful handler result.
- Paused `RunSession` instances do not drain commands, advance cooldowns, or
  step zones.

## Visual ownership

`AbilityFeedbackWorld` is one pausable `Node2D` with fixed data slots. It uses
no per-effect Nodes or callbacks. Ring, field, line, pull, and tracer states are
redrawn from the central snapshot. All ability geometry is critical feedback
and remains present on FULL, REDUCED, and MINIMAL quality.

The current renderer intentionally does not use MultiMesh. If a future atlas
renderer replaces the CanvasItem draw path, engine-side MultiMesh physics
interpolation must remain disabled and the complete buffer may be uploaded at
most once per rendered frame.

`AbilityFeedbackDefinition.validate_catalog()` requires a definition for all
six active abilities and all three base treatments. `CombatTagCatalog`
normalizes tags at definition creation and rejects vocabulary drift in tests.

## Fixed-step integration order

```text
Input commands
EnemyWorld movement
CombatQuery rebuild
AbilityController.step_fixed
GameplayZoneWorld status synchronization
Combat events
AbilityFeedbackWorld.step_fixed
Render snapshot
```

Connect `AbilityController.feedback_requested` to
`AbilityFeedbackWorld.spawn_from_result`. Connect
`TreatmentController.feedback_requested` to
`AbilityFeedbackWorld.spawn_treatment_shots`.

Streuimpuls-Salven share one generation-safe target set at the gameplay
integration boundary unless `spread_shotgun` is active. A ray skips handles
already damaged by the same volley without spending its own penetration count,
so it remains visible and may continue to a later target. Individual ray
penetration stays a regular `TREATMENT_MAX_HITS` build value.

Talent effects keep the same ownership boundary. Treatment Damage Training is
compiled into the run's `TREATMENT_DAMAGE` base before additive cards. A
tracking Impulse projectile delegates its impact to the Game facade through an
optional hit callback; the facade resolves the primary hit and, when
`impulse_splash` is present in the immutable run snapshot, one generation-safe
60-unit circle snapshot for secondary 10-percent hits. Splash events use the
internal source `treatment_precision_splash`, which result aggregation maps back
to `treatment_precision`. The projectile remains responsible only for travel,
generation validation and exactly-once impact.

Defense Burst remains a zero-damage control definition. The
`defense_burst_damage` talent adds a tagged 20-point `ABILITY_DAMAGE` modifier
when the run build is compiled. Its +6/+10/+14 run family declares
`required_talent_ids`, so neither the pool nor preview can expose those cards
without the talent. This keeps unlock policy out of `AbilityController` while
the resulting execution still follows the normal command/result pipeline.

The regression entrypoint is `tests/ability_pipeline_runner.gd`.
