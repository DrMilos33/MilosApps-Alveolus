extends SceneTree

## Regression for capacity-deferred hidden nests. Spawn metadata must survive
## the queue so the mobile nest still releases exactly one four-enemy wave.

var assertions := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = game.levels[1]
	game.start_run()
	game.set_physics_process(false)

	var occupied_regular_slots: int = game.enemy_world.regular_count
	game.combat_capacity.max_regular_enemies = occupied_regular_slots
	game.combat_capacity.critical_enemy_reserve = game.combat_capacity.max_enemies - occupied_regular_slots
	game._spawn_hidden_nests(1)

	_equal(game.deferred_spawn_requests.size() - game.deferred_spawn_cursor, 1, "A full regular budget defers the hidden nest")
	_equal(game.hidden_nest_timers.size(), 0, "No timer is attached before the deferred entity exists")
	var request: EnemySpawnRequest = game.deferred_spawn_requests[game.deferred_spawn_cursor]
	_equal(request.definition_id, &"minor_focus", "The deferred request retains the nest definition")
	_equal(request.source_id, &"hidden_nest", "The deferred request retains its lifecycle source")
	_near(float(request.metadata.get("release_after_seconds", 0.0)), 20.0, "The deferred request retains its release timer")
	_near(request.movement_scale, game.config.enemy_speed_multiplier, "The deferred request retains case movement scaling")
	_near(request.contact_scale, game.config.contact_damage_multiplier, "The deferred request retains case damage scaling")

	game.combat_capacity.max_regular_enemies = CombatCapacity.DEFAULT_REGULAR_ENEMIES
	game.combat_capacity.critical_enemy_reserve = CombatCapacity.DEFAULT_CRITICAL_RESERVE
	game._drain_deferred_spawns(1)
	_equal(game.deferred_spawn_requests.size(), 0, "The queued request is consumed when capacity returns")
	_equal(game.hidden_nest_timers.size(), 1, "The materialized deferred nest receives its timer")

	var nest: InfectionEnemy = game.hidden_nest_timers.keys()[0]
	_equal(nest.definition.id, &"minor_focus", "The timer belongs to the spawned minor focus")
	_near(nest.definition.speed, 20.0, "The blue minor focus uses the current intentional movement speed")
	_near(nest.definition.base_damage, 0.0, "The moving nest itself deals no damage")
	var before_movement := nest.global_position
	nest.step_fixed(1.0)
	nest.step_fixed(0.5)
	_true(nest.global_position.distance_to(before_movement) > 0.1, "The minor focus moves after materialization")

	var enemies_before_release: int = game.enemies.size()
	game._case_mechanics_step(20.0)
	_equal(game.hidden_nest_timers.size(), 0, "The release timer is consumed exactly once")
	_equal(game.enemies.size(), enemies_before_release + 4, "The deferred nest releases exactly four bacteria")
	game._case_mechanics_step(20.0)
	_equal(game.enemies.size(), enemies_before_release + 4, "A consumed nest timer cannot release a second wave")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALVEOLUS_HIDDEN_NEST_SPAWN_CONTRACT_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		printerr("ALVEOLUS_HIDDEN_NEST_SPAWN_CONTRACT_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
		quit(1)


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])


func _near(actual: float, expected: float, message: String, epsilon := 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (actual=%.4f expected=%.4f)" % [message, actual, expected])
