extends SceneTree

class FakeEnemyDefinition extends RefCounted:
	var id: StringName = &"pneumococcus"
	var radius: float = 12.0

class FakeEnemy extends Node2D:
	var definition := FakeEnemyDefinition.new()
	var health: float = 500.0
	var targetable: bool = true
	var movement_multiplier: float = 1.0
	var contact_multiplier: float = 1.0
	var displacement: Vector2 = Vector2.ZERO
	var shooting_locks: int = 0
	var treatment_line_geometry_multiplier: float = 1.0

	func is_targetable() -> bool:
		return targetable and health > 0.0

	func take_damage(amount: float, _source: StringName = &"") -> void:
		health -= amount

	func set_status_modifier(_source: StringName, movement: float, contact: float) -> void:
		movement_multiplier = movement
		contact_multiplier = contact

	func clear_status_modifier(_source: StringName) -> void:
		movement_multiplier = 1.0
		contact_multiplier = 1.0

	func apply_displacement(offset: Vector2) -> void:
		displacement += offset
		global_position += offset

	func apply_defense_burst_shooting_lock() -> void:
		shooting_locks += 1

	func treatment_line_damage_multiplier_for_geometry(
		_origin: Vector2,
		_direction: Vector2,
		_length: float,
		_half_width: float
	) -> float:
		return treatment_line_geometry_multiplier

class FakeAvatar extends Node2D:
	var last_facing := Vector2.RIGHT

class FakePickup extends Node2D:
	var guided_to_target: bool = false

class FakeRunState extends RefCounted:
	var stability: float = 30.0
	func change_stability(amount: float) -> void:
		stability += amount

var assertions := 0
var failures := 0
var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
var enemy_world: EnemyWorld
var pickup_world: PickupWorld


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_feedback_catalog()
	await _test_command_pipeline_and_geometry()
	await _test_zone_world()
	await _test_feedback_world()
	if failures == 0:
		print("ALVEOLUS_ABILITY_PIPELINE_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_ABILITY_PIPELINE_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _test_feedback_catalog() -> void:
	var catalog := AbilityFeedbackDefinition.catalog()
	_equal(catalog.size(), 9, "Six abilities and three treatments have feedback definitions")
	_equal(AbilityFeedbackDefinition.validate_catalog(), PackedStringArray(), "Feedback catalog is complete")
	_equal(catalog[&"ability_focus_field"].shape, AbilityFeedbackDefinition.Shape.FIELD, "Focus uses persistent field language")
	_true(catalog[&"ability_focus_field"].persistent, "Focus feedback remains for the complete gameplay duration")
	_equal(catalog[&"ability_defense_burst"].primary_color, Color("eab553"), "Defense burst uses gold")
	_equal(catalog[&"ability_treatment_line"].shape, AbilityFeedbackDefinition.Shape.LINE, "Treatment line is rendered as a beam")
	_true(catalog[&"ability_sample_pull"].inward, "Sample feedback moves inward")
	_equal(catalog[&"treatment_spread"].shape, AbilityFeedbackDefinition.Shape.TRACER, "Spread treatment owns visible fan tracers")
	_equal(catalog[&"treatment_pierce"].shape, AbilityFeedbackDefinition.Shape.LINE, "Piercing treatment owns a visible beam")
	for definition in AbilityDefinition.catalog().values():
		_equal(CombatTagCatalog.validate(definition.tags), PackedStringArray(), "Ability tags use the canonical vocabulary")
	for definition in TreatmentDefinition.catalog().values():
		_equal(CombatTagCatalog.validate(definition.tags), PackedStringArray(), "Treatment tags use the canonical vocabulary")


func _test_command_pipeline_and_geometry() -> void:
	var capacity := CombatCapacity.new().configure(8, 6, 6, 8, 8, 8)
	enemy_world = EnemyWorld.new().configure_enemy_world(capacity)
	pickup_world = PickupWorld.new().configure_pickup_world(capacity)
	var enemy := FakeEnemy.new()
	enemy.position = Vector2(-470.0, 0.0)
	get_root().add_child(enemy)
	var enemy_handle := enemy_world.register_enemy(enemy)
	var enemy_query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return (enemy_world.resolve(handle) as Node2D).global_position,
		func(handle: int) -> float: return (enemy_world.resolve(handle) as FakeEnemy).definition.radius,
		func(handle: int) -> bool: return enemy_world.resolve(handle) != null and (enemy_world.resolve(handle) as FakeEnemy).is_targetable(),
		enemy_world.resolve
	)
	enemy_query.rebuild(enemy_world.handles())
	var lazy_prepare_state := {"dirty": true, "rebuilds": 0}
	var lazy_query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return (enemy_world.resolve(handle) as Node2D).global_position,
		func(handle: int) -> float: return (enemy_world.resolve(handle) as FakeEnemy).definition.radius,
		func(handle: int) -> bool: return enemy_world.resolve(handle) != null,
		enemy_world.resolve
	)
	lazy_query.set_prepare_callback(func() -> void:
		if not bool(lazy_prepare_state.dirty):
			return
		lazy_prepare_state.dirty = false
		lazy_prepare_state.rebuilds = int(lazy_prepare_state.rebuilds) + 1
		lazy_query.rebuild(enemy_world.handles())
	)
	_equal(lazy_prepare_state.rebuilds, 0, "Lazy query does not rebuild before a consumer")
	lazy_query.circle(Vector2(-470.0, 0.0), 20.0)
	_equal(lazy_prepare_state.rebuilds, 1, "First spatial consumer prepares the query")
	lazy_query.line(Vector2(-490.0, 0.0), Vector2.RIGHT, 40.0, 20.0)
	_equal(lazy_prepare_state.rebuilds, 1, "Later consumers share the prepared fixed-tick query")
	lazy_prepare_state.dirty = true
	lazy_query.nearest(Vector2(-470.0, 0.0), 100.0)
	_equal(lazy_prepare_state.rebuilds, 2, "Invalidating the next tick rebuilds exactly once on demand")
	var pickup := FakePickup.new()
	pickup.position = Vector2(-455.0, 0.0)
	get_root().add_child(pickup)
	var pickup_handle := pickup_world.register_pickup(pickup)
	var pickup_query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return (pickup_world.resolve(handle) as Node2D).global_position,
		Callable(),
		func(handle: int) -> bool: return pickup_world.resolve(handle) != null,
		pickup_world.resolve
	)
	pickup_query.rebuild(pickup_world.handles())
	var avatar := FakeAvatar.new()
	avatar.position = Vector2(480.0, 0.0)
	get_root().add_child(avatar)
	var state := FakeRunState.new()
	var build := RunBuildState.new({
		RunBuildState.ACTIVE_COOLDOWN: 1.0,
		RunBuildState.SUPPORT_EFFECT: 1.0,
	})
	var controller := AbilityController.new()
	get_root().add_child(controller)
	controller.configure(build, topology, avatar, Callable(), Callable(), state)
	controller.configure_queries(enemy_query, pickup_query)
	controller.set_physics_process(false)
	var definitions := AbilityDefinition.catalog()

	var execution_order: Array[int] = []
	controller.execution_completed.connect(func(result: AbilityExecutionResult) -> void: execution_order.append(result.sequence))
	controller.equip(AbilityController.SLOT_Q, definitions[&"ability_defense_burst"])
	controller.equip(AbilityController.SLOT_E, definitions[&"ability_treatment_line"])
	enemy.treatment_line_geometry_multiplier = 2.0
	_true(controller.enqueue_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2(-480.0, 0.0), 20)), "Later command enters queue")
	_true(controller.enqueue_command(AbilityCommand.create(AbilityController.SLOT_E, Vector2(-450.0, 0.0), 10)), "Earlier command enters queue")
	_true(not controller.enqueue_command(AbilityCommand.create(AbilityController.SLOT_E, Vector2.ZERO, 10)), "Duplicate sequence is rejected")
	_equal(controller.queued_command_count(), 2, "Queue does not execute commands early")
	var queued_results := controller.process_command_queue()
	_equal(execution_order, [10, 20], "Commands execute in deterministic sequence order")
	_equal(queued_results.size(), 2, "Every queued command produces one result")
	_true(queued_results[0].success and queued_results[0].length > 600.0, "Line result publishes exact geometry")
	_true(queued_results[0].affected_handles.has(enemy_handle), "Line query returns generation-safe hit handle")
	_true(queued_results[1].affected_handles.has(enemy_handle), "Area query returns generation-safe hit handle")
	_near(enemy.health, 440.0, "Treatment line applies the target's geometry multiplier before damage resolution")
	_equal(enemy.shooting_locks, 1, "Stoß applies its shooting lock even while its damage remains zero")
	for index in range(AbilityController.MAX_QUEUED_COMMANDS):
		_true(controller.enqueue_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2.ZERO, 30 + index)), "Bounded queue accepts command %d" % index)
	_true(not controller.enqueue_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2.ZERO, 1000)), "Bounded queue rejects overflow without allocation")

	controller.clear()
	controller.configure(build, topology, avatar, Callable(), Callable(), state)
	controller.configure_queries(enemy_query, pickup_query)
	controller.set_physics_process(false)
	enemy.treatment_line_geometry_multiplier = 1.0
	controller.equip(AbilityController.SLOT_Q, definitions[&"ability_sample_pull"])
	_true(controller.enqueue_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2(-480.0, 0.0), 90)), "Sample command enters queue")
	controller.process_command_queue()
	controller.runtime(AbilityController.SLOT_Q).reset()
	var results: Dictionary = {}
	for ability_id in definitions:
		enemy.health = 500.0
		enemy.position = Vector2(-470.0, 0.0)
		enemy_query.rebuild(enemy_world.handles())
		pickup.guided_to_target = false
		controller.equip(AbilityController.SLOT_Q, definitions[ability_id])
		var result := controller.execute_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2(-480.0, 0.0), 100 + results.size()))
		results[ability_id] = result
		controller.runtime(AbilityController.SLOT_Q).reset()
	_true(results[&"ability_focus_field"].zone_handle != EntityHandle.INVALID, "Focus creates a generation-safe zone")
	_near(results[&"ability_focus_field"].duration, 7.0, "Focus result keeps full duration")
	_near(results[&"ability_emergency_support"].values.recovery, 14.0, "Emergency support reports applied recovery")
	_near(results[&"ability_defense_burst"].radius, 150.0, "Defense result reports exact radius")
	_near(results[&"ability_treatment_line"].width, 38.0, "Treatment line reports exact width")
	_near(results[&"ability_protection_field"].duration, 6.0, "Protection result keeps full duration")
	_true(results[&"ability_sample_pull"].affected_handles.has(pickup_handle), "Sample pull uses the pickup query")
	_true(pickup.guided_to_target, "Sample pull changes each queried pickup once")

	var unknown := AbilityDefinition.create(&"unknown", "Unknown", AbilityDefinition.TargetMode.SELF, 1.0, &"missing_handler", {})
	controller.equip(AbilityController.SLOT_Q, unknown)
	var unknown_result := controller.execute_command(AbilityCommand.create(AbilityController.SLOT_Q, Vector2.ZERO, 999))
	_equal(unknown_result.code, AbilityExecutionResult.Code.UNKNOWN_HANDLER, "Unknown handler fails explicitly")
	_true(controller.runtime(AbilityController.SLOT_Q).is_ready(), "Failed handler never starts cooldown")

	lazy_query.set_prepare_callback(Callable())
	controller.queue_free()
	avatar.queue_free()
	enemy_world.clear()
	pickup_world.clear()
	enemy.queue_free()
	pickup.queue_free()
	await process_frame


func _test_zone_world() -> void:
	var capacity := CombatCapacity.new().configure(4, 4, 4, 4, 4, 4)
	var world := EnemyWorld.new().configure_enemy_world(capacity)
	var enemy := FakeEnemy.new()
	enemy.position = Vector2(-480.0, 0.0)
	get_root().add_child(enemy)
	var handle := world.register_enemy(enemy)
	var query := CombatQuery.new().configure(
		topology,
		func(current: int) -> Vector2: return (world.resolve(current) as Node2D).global_position,
		func(_current: int) -> float: return 12.0,
		func(current: int) -> bool: return world.resolve(current) != null,
		world.resolve
	)
	query.rebuild(world.handles())
	var zones := GameplayZoneWorld.new().configure(topology, query, 2)
	var protection := zones.spawn(&"protective_field", Vector2(480.0, 0.0), 80.0, 2.0, {"speed_multiplier": 0.65, "contact_multiplier": 0.7})
	_true(EntityHandle.is_valid(protection), "Protection reserves a generation-safe zone handle")
	_true(zones.has_effect(&"protective_field"), "Zone world reports an active protective query consumer")
	zones.step_fixed(0.1)
	_near(enemy.movement_multiplier, 0.65, "Protection queries across the torus seam")
	_true(zones.release(protection), "Zone releases synchronously")
	_true(not zones.has_effect(&"protective_field"), "Released field no longer requests an enemy query")
	_near(enemy.movement_multiplier, 1.0, "Releasing protection clears status synchronously")
	var replacement := zones.spawn(&"focus_field", Vector2.ZERO, 30.0, 1.0, {"damage_multiplier": 1.25})
	_equal(EntityHandle.slot(replacement), EntityHandle.slot(protection), "Released zone slot is reused")
	_true(EntityHandle.generation(replacement) != EntityHandle.generation(protection), "Reused zone advances generation")
	_true(not zones.release(protection), "Stale zone handle cannot release replacement")
	_true(zones.resolve(replacement) != null, "Replacement survives stale release")
	var session := RunSession.new().configure(null, false)
	get_root().add_child(session)
	_true(session.register_system(zones, RunSession.Phase.COMBAT), "Zone world plugs into the fixed combat phase")
	_true(session.start(), "Zone pause test starts a run session")
	var remaining_before_step := zones.resolve(replacement).remaining
	session.step_fixed(0.1)
	_true(zones.resolve(replacement).remaining < remaining_before_step, "Running session advances zone lifetime")
	session.pause_session()
	var remaining_before_pause := zones.resolve(replacement).remaining
	_true(not session.step_fixed(0.5), "Paused run session refuses a combat tick")
	_near(zones.resolve(replacement).remaining, remaining_before_pause, "Paused session freezes zone lifetime")
	session.cancel()
	session.queue_free()
	zones.clear()
	world.clear()
	enemy.queue_free()
	await process_frame


func _test_feedback_world() -> void:
	var world := AbilityFeedbackWorld.new().configure(topology, 16, true)
	get_root().add_child(world)
	_equal(world.get_child_count(), 0, "Central renderer allocates no per-effect nodes")
	var shield_anchor := Node2D.new()
	get_root().add_child(shield_anchor)
	world.set_shield_anchor(shield_anchor)
	world.update_shield(5.0, 8.0)
	_true(world.shield_state().visible, "Emergency protection owns a persistent visible shield ring")
	_near(float(world.shield_state().current), 5.0, "Shield feedback follows the authoritative controller value")
	var line_result := AbilityExecutionResult.succeeded(
		AbilityCommand.create(0, Vector2(-450.0, 0.0), 1),
		AbilityDefinition.catalog()[&"ability_treatment_line"]
	)
	line_result.origin = Vector2(480.0, 0.0)
	line_result.target = Vector2(-450.0, 0.0)
	line_result.direction = topology.shortest_delta(line_result.origin, line_result.target).normalized()
	line_result.length = 620.0
	line_result.width = 38.0
	line_result.duration = 0.22
	var line_handle := world.spawn_from_result(line_result)
	_true(EntityHandle.is_valid(line_handle), "Execution result creates feedback without scene nodes")
	_equal(world.render_state(line_handle).shape, AbilityFeedbackDefinition.Shape.LINE, "Renderer preserves line geometry")
	_near(world.render_state(line_handle).width, 38.0, "Renderer preserves gameplay width")
	world.set_quality_tier(CosmeticBudgetController.Quality.MINIMAL)
	_true(world.render_state(line_handle).critical, "Minimal quality keeps gameplay geometry critical")
	_equal(world.active_count(), 1, "Quality reduction never removes active gameplay feedback")
	world.set_reduced_motion(true)
	_true(world.reduced_motion, "Reduced motion changes only presentation, not gameplay feedback lifetime")
	var focus_result := AbilityExecutionResult.succeeded(
		AbilityCommand.create(0, Vector2.ZERO, 2),
		AbilityDefinition.catalog()[&"ability_focus_field"]
	)
	focus_result.target = Vector2(120.0, 80.0)
	focus_result.radius = 165.0
	focus_result.duration = 7.0
	var focus_handle := world.spawn_from_result(focus_result)
	_near(world.render_state(focus_handle).duration, 7.0, "Persistent feedback uses the authoritative gameplay duration")
	_true(world.render_state(focus_handle).critical, "Persistent field remains visible on minimal quality")
	_equal(world.spawn(&"unknown_visual", Vector2.ZERO, Vector2.ZERO), EntityHandle.INVALID, "Unknown visual IDs fail instead of using misleading fallback geometry")

	var spread_definition: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_spread"]
	var shot_a := TreatmentShot.line(Vector2.ZERO, Vector2.RIGHT.rotated(-0.2), 8.0, 440.0, 1, spread_definition.id)
	var shot_b := TreatmentShot.line(Vector2.ZERO, Vector2.RIGHT, 8.0, 440.0, 1, spread_definition.id)
	var shot_c := TreatmentShot.line(Vector2.ZERO, Vector2.RIGHT.rotated(0.2), 8.0, 440.0, 1, spread_definition.id)
	var fan_handles := world.spawn_treatment_shots([shot_a, shot_b, shot_c])
	_equal(fan_handles.size(), 3, "Spread creates one visible tracer for every gameplay ray")
	_true(world.resolve(fan_handles[0]).direction != world.resolve(fan_handles[2]).direction, "Fan tracers preserve distinct directions")

	var bounded_topology := ArenaTopology.new(
		Rect2(-500.0, -500.0, 1000.0, 1000.0),
		ArenaTopology.BoundaryMode.BOUNDED
	)
	var preview := AbilityTargetPreview.new()
	preview.topology = bounded_topology
	_equal(preview._wrapped_points(Vector2(490.0, 0.0), 40.0).size(), 1, "Bounded target previews create no copy at the opposite edge")
	_near(preview._visible_line_length(Vector2(480.0, 0.0), Vector2.RIGHT, 80.0), 20.0, "Bounded direction previews stop at the hard edge")
	world.topology = bounded_topology
	_equal(world._wrapped_points(Vector2(490.0, 0.0), 40.0).size(), 1, "Bounded feedback fields create no opposite-edge copy")
	_equal(world._line_offsets().size(), 1, "Bounded feedback lines render only in their own arena position")
	_near(world._visible_line_length(Vector2(480.0, 0.0), Vector2.RIGHT, 80.0), 20.0, "Bounded feedback lines end at the hard edge")
	world.topology = topology
	_true(world._wrapped_points(Vector2(490.0, 0.0), 40.0).size() > 1, "The legacy wrapping preview contract remains available")
	_equal(world._line_offsets().size(), 9, "The legacy wrapping line copies remain available")
	preview.free()

	var paused_remaining := world.resolve(line_handle).remaining
	paused = true
	await process_frame
	await process_frame
	_near(world.resolve(line_handle).remaining, paused_remaining, "Pause freezes central feedback lifetime")
	paused = false
	world.step_fixed(1.0)
	_equal(world.active_count(), 1, "Short feedback expires while the persistent focus field remains")
	world.step_fixed(7.0)
	_equal(world.active_count(), 0, "Expired feedback returns every pooled slot")
	var replacement := world.spawn(&"ability_defense_burst", Vector2.ZERO, Vector2.ZERO, Vector2.RIGHT, 100.0)
	_true(EntityHandle.is_valid(replacement), "Renderer reuses returned capacity")
	_true(not world.release(line_handle), "Stale visual handle cannot clear replacement")
	world.clear()
	_true(not world.shield_state().visible, "Clearing the run removes persistent shield feedback")
	world.queue_free()
	shield_anchor.queue_free()
	await process_frame


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])


func _near(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (actual=%.4f expected=%.4f)" % [message, actual, expected])
