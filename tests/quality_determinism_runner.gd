extends SceneTree

## Quality tiers are allowed to change only cosmetic work. This runner drives
## the real Game -> RunSession fixed-step path three times with the same seed,
## movement/ability trace and deterministic upgrade choices, then hashes a
## canonical trace containing gameplay state only.

const FIXED_DELTA := 1.0 / 60.0
const SIMULATION_FRAMES := 900
const CHECKPOINT_INTERVAL := 30
const RUN_SEED := 0x51A7E2026
const POSITION_PRECISION := 10000.0

const MOVEMENT_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
]

var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var qualities: Array[CosmeticBudgetController.Quality] = [
		CosmeticBudgetController.Quality.FULL,
		CosmeticBudgetController.Quality.REDUCED,
		CosmeticBudgetController.Quality.MINIMAL,
	]
	var results: Array[Dictionary] = []
	for quality in qualities:
		results.append(await _simulate_quality(quality))

	for index in range(results.size()):
		var result: Dictionary = results[index]
		_assert_equal(int(result.quality), int(qualities[index]), "%s tier was applied to the real game" % result.quality_name)
		_assert_equal(int(result.fixed_ticks), SIMULATION_FRAMES, "%s completed every requested fixed tick" % result.quality_name)
		_assert_equal(int(result.checkpoints), SIMULATION_FRAMES / CHECKPOINT_INTERVAL, "%s produced the complete gameplay trace" % result.quality_name)
		_assert_true(not String(result.gameplay_hash).is_empty(), "%s produced a gameplay hash" % result.quality_name)
		_assert_true(bool(result.session_running), "%s remained an active run for the complete trace" % result.quality_name)

	# Prove that the runs actually used distinct cosmetic budgets. These values
	# are deliberately not part of the gameplay hash.
	_assert_equal(int(results[0].cosmetic_particle_probe), 10, "FULL keeps the complete cosmetic particle probe")
	_assert_equal(int(results[1].cosmetic_particle_probe), 7, "REDUCED lowers the cosmetic particle probe")
	_assert_equal(int(results[2].cosmetic_particle_probe), 5, "MINIMAL lowers the cosmetic particle probe further")

	var baseline: Dictionary = results[0]
	for index in range(1, results.size()):
		var candidate: Dictionary = results[index]
		_assert_equal(candidate.gameplay_hash, baseline.gameplay_hash, "%s has the same complete gameplay trace as FULL" % candidate.quality_name)
		_assert_equal(candidate.final_state, baseline.final_state, "%s has the same final gameplay state as FULL" % candidate.quality_name)
		_assert_equal(candidate.rng_state, baseline.rng_state, "%s consumes the same gameplay RNG sequence as FULL" % candidate.quality_name)

	_release_movement_actions()
	if failures == 0:
		print("ALVEOLUS_QUALITY_DETERMINISM_OK assertions=%d hash=%s checkpoints=%d frames=%d" % [
			assertions,
			String(baseline.gameplay_hash),
			int(baseline.checkpoints),
			SIMULATION_FRAMES,
		])
	else:
		push_error("ALVEOLUS_QUALITY_DETERMINISM_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _simulate_quality(quality: CosmeticBudgetController.Quality) -> Dictionary:
	paused = false
	_release_movement_actions()
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	# _ready() can load the player's real save before a test changes public
	# flags, so reset all persistent/discovery state explicitly as part of test
	# isolation. No file is read or written after this point.
	game.quick_run = true
	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)

	game.selected_level = game.levels[1]
	var context := RunContext.create(
		game.selected_level.id,
		RUN_SEED,
		PreparedLoadout.default_loadout(),
		{},
		&""
	)
	game.start_run(context)
	# Keep the test alive beyond the quick-run boss spawn without changing the
	# spawn curve or contact mechanics that make the trace meaningful.
	game.config.final_deadline_seconds = 9999.0
	game.config.boss_health_multiplier = 3.0
	game.state.max_stability = 500.0
	game.state.stability = 500.0
	# CharacterBody2D.move_and_slide() is tied to PhysicsServer frame state and
	# is intentionally not called from this accelerated, manually-clocked test.
	# A deterministic input adapter below applies the exact same movement vector
	# before the real RunSession tick; all combat systems still consume the real
	# avatar transform.
	game.avatar.input_enabled = false
	game.cosmetic_budget_controller.configure(false, false)
	game.cosmetic_budget_controller.set_quality(quality)

	# Stop SceneTree-driven frames. The test owns the one authoritative 60 Hz
	# clock and calls the same RunSession path used by Game._physics_process().
	paused = true
	var trace_lines := PackedStringArray()
	for frame in range(SIMULATION_FRAMES):
		var movement := _apply_input_trace(frame)
		_apply_avatar_input(game, movement)
		_apply_command_trace(game, frame)
		game.run_session.step_fixed(FIXED_DELTA)
		_resolve_deterministic_choices(game)
		if (frame + 1) % CHECKPOINT_INTERVAL == 0:
			trace_lines.append(_canonical_gameplay_state(game, frame + 1))

	var final_state := _canonical_gameplay_state(game, SIMULATION_FRAMES)
	var result := {
		"quality": int(quality),
		"quality_name": _quality_name(quality),
		"cosmetic_particle_probe": game.cosmetic_budget_controller.particle_count(10, CosmeticBudgetController.EffectPriority.COMBAT),
		"gameplay_hash": _sha256("\n".join(trace_lines)),
		"final_state": final_state,
		"rng_state": int(game.rng.state),
		"fixed_ticks": int(game.run_session.fixed_tick),
		"checkpoints": trace_lines.size(),
		"session_running": game.run_session.lifecycle == RunSession.Lifecycle.RUNNING,
	}

	_release_movement_actions()
	paused = false
	game.queue_free()
	await process_frame
	return result

func _apply_input_trace(frame: int) -> Vector2:
	_release_movement_actions()
	# A repeating square with short diagonal sections exercises movement, torus
	# distance queries and contacts without relying on render-frame input timing.
	var phase := frame % 360
	if phase < 90:
		Input.action_press(&"move_right")
	elif phase < 180:
		Input.action_press(&"move_down")
	elif phase < 270:
		Input.action_press(&"move_left")
	else:
		Input.action_press(&"move_up")
	if frame % 120 in range(18, 34):
		Input.action_press(&"move_up" if phase < 180 else &"move_down")
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

func _apply_avatar_input(game: Node, direction: Vector2) -> void:
	game.avatar.global_position = game.topology.wrap_position(
		game.avatar.global_position + direction * game.stats.movement_speed * FIXED_DELTA
	)
	game.avatar.reset_physics_interpolation()

func _apply_command_trace(game: Node, frame: int) -> void:
	# Active abilities are input commands too, but Game receives them through
	# _unhandled_input in interactive builds. Invoke the same controller entry
	# point directly so headless timing is exact and repeatable.
	if frame in [90, 510]:
		game.ability_controller.use_slot(
			AbilityController.SLOT_Q,
			game.topology.wrap_position(game.avatar.global_position + Vector2(210.0, -70.0))
		)
	elif frame in [240, 780]:
		game.ability_controller.use_slot(AbilityController.SLOT_E, game.avatar.global_position)
	# Deterministic guided samples exercise pickup collection, level-up pauses,
	# upgrade RNG and projectiles while remaining identical for every quality.
	if frame in [120, 300, 480, 660, 840]:
		game._spawn_analysis_pickup(
			4,
			game.topology.wrap_position(game.avatar.global_position + Vector2(46.0, -14.0)),
			true
		)

func _resolve_deterministic_choices(game: Node) -> void:
	# Choose option one as the fixed player decision whenever a sample triggers
	# a level-up. Discoveries are pre-marked, and this RunContext has no hidden
	# event, so no other modal state should enter the trace.
	var safety := 0
	while game.flow_state == GameFlowState.State.LEVEL_UP and safety < 8:
		safety += 1
		if game.current_upgrade_options.is_empty():
			break
		game._on_upgrade_chosen(game.current_upgrade_options[0])

func _canonical_gameplay_state(game: Node, frame: int) -> String:
	var parts := PackedStringArray()
	parts.append("frame=%d" % frame)
	parts.append("input=%s" % _current_input_signature())
	parts.append("flow=%d" % int(game.flow_state))
	parts.append("session=%d,%d,%s" % [
		int(game.run_session.lifecycle),
		int(game.run_session.fixed_tick),
		_f(game.run_session.elapsed),
	])
	parts.append("run=%s,%s,%s,%d,%d,%d,%d" % [
		_f(game.state.elapsed),
		_f(game.state.stability),
		_f(game.state.max_stability),
		int(game.state.analysis),
		int(game.state.analysis_target),
		int(game.state.level),
		int(game.state.boss_spawned),
	])
	parts.append("run_flags=%d,%d,%d" % [
		int(game.state.active),
		int(game.state.level_up_pending),
		int(game.state.boss_defeated),
	])
	parts.append("avatar=%s,%s" % [_v(game.avatar.global_position), _v(game.avatar.velocity)])
	parts.append("combat=%d,%s,%s,%d" % [
		int(game.defeats),
		_f(game.therapy_timer),
		_f(game.treatment_controller.cooldown_remaining),
		int(game.rng.state),
	])
	var wave: Dictionary = game.standard_wave_director.snapshot()
	parts.append("wave=%d,%s,%s,%s,%d,%d,%d,%d" % [
		int(wave["wave_ordinal"]),
		_f(float(wave["wave_age_seconds"])),
		_f(float(wave["seconds_until_forced_wave"])),
		_f(float(wave["slot_credit"])),
		int(wave["current_total_weight"]),
		int(wave["current_alive_weight"]),
		int(wave["pending_intents"]),
		int(wave["random_state"]),
	])
	parts.append("stats=%s" % _canonical_stats(game.stats))
	parts.append("abilities=%s" % _canonical_abilities(game.ability_controller))
	parts.append("enemies=%s" % _canonical_enemies(game))
	parts.append("pickups=%s" % _canonical_pickups(game))
	parts.append("projectiles=%s" % _canonical_projectiles(game))
	parts.append("deferred=%s" % _canonical_deferred_spawns(game))
	return "|".join(parts)

func _canonical_stats(stats: PlayerStats) -> String:
	var upgrades: Array = stats.upgrade_levels.keys()
	upgrades.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	var upgrade_parts := PackedStringArray()
	for id in upgrades:
		upgrade_parts.append("%s:%d" % [String(id), int(stats.upgrade_levels[id])])
	return "%s,%s,%s,%d,%d,%d,%s,%d,%s,%s,%s,%s,[%s]" % [
		_f(stats.therapy_damage),
		_f(stats.therapy_cooldown),
		_f(stats.therapy_range),
		stats.therapy_targets,
		stats.therapy_projectiles,
		stats.immune_level,
		_f(stats.immune_damage),
		stats.support_level,
		_f(stats.pickup_range),
		_f(stats.max_stability_bonus),
		_f(stats.ability_cooldown_multiplier),
		_f(stats.overheal_shield_cap),
		",".join(upgrade_parts),
	]

func _canonical_abilities(controller: AbilityController) -> String:
	var parts := PackedStringArray()
	parts.append("shield=%s/%s" % [_f(controller.shield), _f(controller.shield_maximum)])
	for slot in [AbilityController.SLOT_Q, AbilityController.SLOT_E]:
		var state: Dictionary = controller.ability_state(slot)
		parts.append("slot%d=%s,%s,%s" % [slot, String(state.get("id", &"")), _f(float(state.get("remaining", 0.0))), _f(float(state.get("total", 0.0)))])
	var zones: Array[AbilityEffectZone] = controller.zones.duplicate()
	zones.sort_custom(func(left: AbilityEffectZone, right: AbilityEffectZone) -> bool: return left.id < right.id)
	for zone in zones:
		parts.append("zone=%d,%s,%s,%s,%s" % [zone.id, String(zone.effect_id), _v(zone.center), _f(zone.radius), _f(zone.remaining)])
	return ";".join(parts)

func _canonical_enemies(game: Node) -> String:
	var handles: PackedInt64Array = game.enemy_world.handles()
	handles.sort()
	var parts := PackedStringArray()
	for handle in handles:
		var enemy := game.enemy_world.resolve(handle) as InfectionEnemy
		if not is_instance_valid(enemy):
			parts.append("%d:null" % int(handle))
			continue
		parts.append("%d,%s,%s,%s/%s,%s,%s,%d,%d,%d,%s,%s" % [
			int(handle),
			String(enemy.definition.id),
			_v(enemy.global_position),
			_f(enemy.health),
			_f(enemy.max_health),
			_f(enemy.spawn_timer),
			_f(enemy.contact_cooldown),
			int(enemy.is_targetable()),
			int(enemy.dying),
			enemy.next_phase_index,
			_f(enemy.status_speed_multiplier()),
			_f(enemy.status_contact_multiplier()),
		])
	return "[" + ";".join(parts) + "]"

func _canonical_pickups(game: Node) -> String:
	var handles: PackedInt64Array = game.pickup_world.handles()
	handles.sort()
	var parts := PackedStringArray()
	for handle in handles:
		var pickup := game.pickup_world.resolve(handle) as AnalysisPickup
		if not is_instance_valid(pickup):
			parts.append("%d:null" % int(handle))
			continue
		# phase, trail and decorative_trail_enabled are render-only and excluded.
		parts.append("%d,%s,%d,%d" % [
			int(handle),
			_v(pickup.global_position),
			pickup.analysis_value,
			int(pickup.guided_to_target),
		])
	return "[" + ";".join(parts) + "]"

func _canonical_projectiles(game: Node) -> String:
	var handles: PackedInt64Array = game.projectile_world.handles()
	handles.sort()
	var parts := PackedStringArray()
	for handle in handles:
		var projectile := game.projectile_world.resolve(handle) as TherapyProjectile
		if not is_instance_valid(projectile):
			parts.append("%d:null" % int(handle))
			continue
		parts.append("%d,%s,%s,%s,%s,%s,%d,%s" % [
			int(handle),
			_v(projectile.global_position),
			_v(projectile.direction),
			_f(projectile.damage),
			_f(projectile.lifetime),
			_f(projectile.travelled_distance),
			int(projectile.target_handle),
			String(projectile.damage_source),
		])
	return "[" + ";".join(parts) + "]"

func _canonical_deferred_spawns(game: Node) -> String:
	var parts := PackedStringArray()
	for index in range(game.deferred_spawn_cursor, game.deferred_spawn_requests.size()):
		var request: EnemySpawnRequest = game.deferred_spawn_requests[index]
		if request == null:
			parts.append("null")
			continue
		parts.append("%s,%s,%s,%s,%d" % [
			String(request.definition_id),
			_v(request.position),
			_f(request.health_scale),
			_f(request.contact_scale),
			int(request.priority),
		])
	return "[" + ";".join(parts) + "]"

func _current_input_signature() -> String:
	var active := PackedStringArray()
	for action in MOVEMENT_ACTIONS:
		if Input.is_action_pressed(action):
			active.append(String(action))
	return ",".join(active)

func _release_movement_actions() -> void:
	for action in MOVEMENT_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)

func _quality_name(quality: CosmeticBudgetController.Quality) -> String:
	match quality:
		CosmeticBudgetController.Quality.REDUCED:
			return "REDUCED"
		CosmeticBudgetController.Quality.MINIMAL:
			return "MINIMAL"
	return "FULL"

func _f(value: float) -> String:
	# Quantization avoids irrelevant text formatting differences while retaining
	# substantially more precision than any collision/gameplay tolerance.
	return "%.4f" % (round(value * POSITION_PRECISION) / POSITION_PRECISION)

func _v(value: Vector2) -> String:
	return "%s,%s" % [_f(value.x), _f(value.y)]

func _sha256(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)
