# ALVEOLUS performance budget

## Supported load

The target on the current development PC, both native and in the local Chrome
web build at 1280×720, is stable 60 FPS with:

- 600 regular enemies plus 40 reserved critical/boss slots;
- 360 active pickup stacks preserving the value of at least 1,200 drops;
- up to 512 simulated, gameplay-relevant projectiles; cosmetic trails and glow
  may be reduced, but the projectile bodies remain visible;
- up to 80 simultaneous feedback visuals.

The mass-entity SceneTree node count must remain constant as these counts rise.
Render draw calls scale with visual archetypes, not entity count.
The static organic `ArenaBackdrop` is baked once per level configuration into
an isolated 2400×1350 `SubViewport`; after warm-up that render target is
disabled and the gameplay viewport submits the arena as one textured quad.
Reconfiguration reuses the same viewport and canvas, while unsupported or
unsafe target sizes keep the original primitive renderer as a visible fallback.

## Frame acceptance

The deterministic CPU gate and five-minute soak publish machine-readable JSON.
The native and Chrome release builds additionally measure whole rendered
frames; headless timing is never presented as a GPU/browser result. Native
acceptance uses the strict frame budgets below. Browser acceptance uses its
end-to-end `requestAnimationFrame` p95 budget of 22.2 ms while still requiring
exact entity/render counts, zero lifecycle violations, and no stalls over
100 ms; native timing thresholds are never applied to a Web trace.

- target frame rate: 60 FPS;
- p95 total frame time: at most 16.7 ms;
- p99 total frame time: at most 20 ms;
- no frame above 33.3 ms after warm-up;
- no continuing growth in object count or memory after all pools are warm;
- identical gameplay hash for the same seed and input trace at every cosmetic
  quality level.

Headless `await physics_frame` timing alone is not an acceptance benchmark. The
native and browser builds must report per-subsystem CPU time and whole-frame
percentiles from a release build.

## Capacity behavior

`CombatCapacity` is a gameplay contract, not merely an inactive pool size.

- Regular spawns stop allocating at 600; the remaining 40 slots are reserved
  for bosses and critical phase spawns.
- Deferred regular spawn debt is stored as bounded counters per archetype and
  drained when slots become available. No emergency nodes are allocated.
- Pickup overflow merges into existing stacks without losing sample value.
- Projectile state is capped at 512. Quality reduction may remove only trails,
  glow and secondary particles; it never removes a gameplay projectile body,
  drops damage or alters cooldowns.
- Cosmetic overflow is discarded by priority: decorative first, combat second,
  critical indicators never.

## Automatic cosmetic reduction

`CosmeticBudgetController` uses hysteresis so quality cannot oscillate every
frame:

- `FULL` to `REDUCED`: below 55 FPS for 2 seconds;
- `REDUCED` to `MINIMAL`: below 45 FPS for 2 seconds;
- recover one level only after at least 5 seconds at 58 FPS or more.

Only particle counts, pickup trails, secondary glow, decorative pulses, and
decorative effect concurrency may change. Enemy count, targetability, spawn
telegraphs, boss information, ability areas, damage, cooldowns, RNG, rewards,
and required status feedback are never degraded.

## Hot-loop guardrails

- No dynamic representation switch based on entity count.
- No per-frame allocation of particle materials or query dictionaries.
- No full-world scan when a system has no active zone or effect.
- Status products are cached when their sources change.
- Range, circle, and line mechanics use `CombatQuery` rather than independent
  scans.
- Render interpolation uses previous/current physics positions; any explicit
  topology relocation resets the previous position.
- Dynamic 2D MultiMeshes use CPU snapshot interpolation and ordinary packed
  `set_buffer()` uploads. Engine-side MultiMesh physics interpolation and
  `set_buffer_interpolated()` are prohibited on the supported Godot 4.7.1 GL
  Compatibility build because the native stress reproduction corrupts memory.
- Short feedback effects are process-free records stepped by one
  `FeedbackRenderer`; they must not create one particle node or callback per
  hit.
- Dense-crowd guard and body-width corridor queries reuse the existing
  `CombatSpatialGrid`, a caller-owned packed candidate buffer and 24 slot
  phases. A queued follower validates only its exact generation-safe contact
  body per tick. On its scheduled phase it may retain the exact two side
  blockers and skip a full refresh only while both still close their sweeps.
  A moving or direct lease resolves at most three cached guards in two
  projection passes. Only an already active lease against a stationary Doctor
  may retain up to five guards for its short contact-boundary chord; it reuses
  the same phased query and performs no additional grid lookup. Neither queued
  nor leased bodies may restore one query per enemy and tick.
  Deferred contact is resolved from one local grid query per fixed tick, not
  one Doctor-distance check per distant enemy.
- Offscreen relocation uses the incrementally maintained EnemyWorld broad
  phase before its exact body-distance check and falls back to the complete
  `CombatQuery` registry while materializing bodies exist. Candidate placement
  must not scan every enemy for every attempted sector position. Its snapshot
  scan remains fixed at twice per second; a larger backlog may schedule at most
  eighteen distributed moves per snapshot and still applies at most one move in
  a fixed tick.

## Crowd measurement contract

Crowd changes report two deterministic CPU scenarios with the same seed and
fixture: 220 enemies as the currently reachable dense gameplay load and 600
enemies as the technical capacity gate. Both retain 360 pickup stacks, 512
moving gameplay projectiles and 80 feedback effects. Warm-up lasts eight
simulated seconds and the measured interval at least fifteen simulated
seconds.

The report includes total, `enemy_world`, `clock_spawn` and `crowd_renderer`
p50/p95/p99/max plus exact entity counts, node/memory development and fixed
crowd counters for grid rebuilds, guard queries, examined candidates, corridor
evaluations, queued ticks, bypass starts and side switches. Counters are active
only in the profiling run and are returned as one fixed `PackedInt64Array`
snapshot; production movement creates no report dictionaries.

The 220-enemy scenario must satisfy the native frame budget and may not regress
against its exact pre-change baseline. The 600-enemy scenario remains the
capacity gate and is reported honestly if it misses an absolute threshold;
an improvement relative to a broken baseline is not a pass. Headless CPU
figures remain diagnostic until a visible native 1280×720 run confirms the
rendered result.

## Render and browser telemetry

The explicit stress path owns a non-gameplay observer named
`RenderStressTelemetry`. After its warm-up it samples the `delta` delivered to
the rendered `_process()` callback, then writes exactly one log line prefixed
with `ALVEOLUS_RENDER_STRESS_JSON=`. Its payload schema is
`alveolus.render_stress.v1` and contains p50/p95/p99/max frame intervals,
effective FPS, current cosmetic quality, entity counts, pool occupancy,
render monitors, and start/warm-up/end node and memory development.

Native example (a visible window is required for a rendered result):

```powershell
& $alveolusGodotConsole --path . --quit-after 3000 -- --auto-start --stress-test --stress-warmup=2 --stress-duration=5
```

The explicit native stress path disables VSync so its frame intervals measure
render headroom rather than monitor cadence; normal gameplay and the browser
build keep their regular presentation behavior. The final development-PC gate
on 2026-08-16 used moving projectiles and the exact 600/360/512/80 load. It
stayed on `FULL`, exited cleanly, and held every sampled entity/render count:
p95 13.657 ms, p99 16.136 ms and max 22.199 ms over the measured five-second
window. The batched scene reported 36 draw calls rather than scaling with its
1,552 mass visuals.

The final 18,000-tick CPU soak processed 6,000/6,000 immediate pool reuses with
no node growth: p95 14.841 ms, p99 17.436 ms, max 30.429 ms and 1.74% bounded
static-memory growth after warm-up. These development-PC results do not
substitute for the still required reference mid-range measurement.

For a five-minute local browser run, serve the project root and open:

```text
http://127.0.0.1:8767/tests/browser_soak_harness.html?duration=300&warmup=5&autostart=1
```

The harness appends `stress=1`, `auto_start=1`, `stress_warmup`, and
`stress_duration` only to its embedded game URL. A normal web URL therefore
does not enter diagnostic mode. The game sends ready/result messages through
`postMessage`; the final `alveolus.browser_performance.v1` report embeds the
complete `alveolus.render_stress.v1` payload. If that payload is missing, the
harness marks the run as failed instead of accepting an unloaded rAF trace.

The final local Chrome run on 2026-08-16 completed 300.008 measured seconds at
an exact 1280x720 canvas. All 305 one-second invariant samples held 600
enemies, 360 pickup stacks, 512 moving projectiles, 80 feedback effects, and
the corresponding renderer counts. Nodes, memory, and orphan counts did not
grow after warm-up, and no application JavaScript error or visibility
interruption was observed. This validates lifecycle stability and the absence
of the former threshold flicker under sustained maximum load.

The browser timing gate passed. Across 26,234 rAF samples the trace measured
p95 17.9 ms, p99 20.8 ms, max 50.9 ms and 87.44 effective FPS, with no stall
over 100 ms. The correlated in-game trace measured p95 17.4 ms and p99 19.7
ms. Cosmetic quality stayed on `FULL` for the entire run. The complete
machine-readable result is stored in
`.codex-temp/reports/browser-soak/browser-soak-latest.json` and the immutable
`.codex-temp/reports/browser-soak/browser-soak-2026-08-16-final.json`.
