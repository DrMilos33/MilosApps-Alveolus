extends SceneTree

## Deterministic regression coverage for the exact class of one-frame spawn
## ghosts caused by pooled entities retaining active or interpolation state.

const POSITION_EPSILON := 0.01
const REUSE_CYCLES := 96
const SIMULTANEOUS_COUNT := 32

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	paused = false
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.quick_run = true
	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = game.levels[1]
	game.start_run()
	game.spawn_accumulator = 9999.0
	game.treatment_controller.enabled = false

	_test_single_pool_reactivation(game)
	await _test_repeated_reactivation(game)
	_test_simultaneous_recycle(game)
	await _test_pause_mid_materialization(game)
	_test_torus_interpolation_boundary(game)

	game.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_SPAWN_LIFECYCLE_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_SPAWN_LIFECYCLE_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _test_single_pool_reactivation(game: Node) -> void:
	var enemy: InfectionEnemy = game.enemies[0]
	enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var old_position := Vector2(-711.0, 283.0)
	enemy.global_position = old_position
	enemy.reset_physics_interpolation()
	game.enemies.erase(enemy)
	game._store_enemy(enemy)
	_assert_true(not enemy.visible, "Recycled enemy is hidden")
	_assert_true(not enemy.is_physics_processing(), "Recycled enemy no longer simulates")
	_assert_true(not enemy.is_targetable(), "Recycled live enemy cannot be targeted through a stale handle")
	var pool_size: int = game.enemy_pool.size()
	game._store_enemy(enemy)
	_assert_equal(game.enemy_pool.size(), pool_size, "Duplicate recycle cannot duplicate a pool entry")

	var new_position := Vector2(517.0, -229.0)
	var reused: InfectionEnemy = game._spawn_enemy(&"bacterial_cluster", new_position)
	_assert_true(reused == enemy, "The lifecycle check exercises the reused instance")
	_assert_vector(reused.global_position, new_position, "Reused enemy commits its new position before returning")
	_assert_true(reused.definition.id == &"bacterial_cluster", "Reused enemy commits its new definition")
	_assert_near(reused.spawn_timer, InfectionEnemy.SPAWN_TOTAL_SECONDS, "Reused enemy restarts the complete spawn lifecycle")
	_assert_true(not reused.is_targetable(), "Reused enemy stays non-targetable during telegraph")

func _test_repeated_reactivation(game: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xA17E0
	var enemy: InfectionEnemy = game.enemies.back()
	for cycle in range(REUSE_CYCLES):
		enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		game.enemies.erase(enemy)
		game._store_enemy(enemy)
		var requested := Vector2(rng.randf_range(-850.0, 850.0), rng.randf_range(-500.0, 500.0))
		var expected: Vector2 = game.topology.wrap_position(requested)
		var type: StringName = &"pneumococcus" if cycle % 2 == 0 else &"bacterial_cluster"
		enemy = game._spawn_enemy(type, requested)
		_assert_vector(enemy.global_position, expected, "Cycle %d has no old logical transform" % cycle)
		_assert_near(enemy.spawn_timer, InfectionEnemy.SPAWN_TOTAL_SECONDS, "Cycle %d resets spawn time" % cycle)
		_assert_true(not enemy.is_targetable(), "Cycle %d cannot target the pooled spawn early" % cycle)
		await process_frame
		_assert_vector(enemy.global_position, expected, "Cycle %d remains at the committed position for its first render frame" % cycle)

func _test_simultaneous_recycle(game: Node) -> void:
	var spawned: Array[InfectionEnemy] = []
	var expected_positions: Array[Vector2] = []
	for index in range(SIMULTANEOUS_COUNT):
		var angle := TAU * float(index) / float(SIMULTANEOUS_COUNT)
		var position: Vector2 = game.topology.wrap_position(Vector2.from_angle(angle) * (260.0 + float(index % 4) * 37.0))
		var enemy: InfectionEnemy = game._spawn_enemy(&"pneumococcus", position)
		enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		spawned.append(enemy)
		expected_positions.append(position)
	var ids := {}
	for enemy in spawned:
		ids[enemy.get_instance_id()] = true
		game.enemies.erase(enemy)
		game._store_enemy(enemy)
	_assert_equal(ids.size(), SIMULTANEOUS_COUNT, "Simultaneous recycle starts with unique entity instances")
	for index in range(SIMULTANEOUS_COUNT):
		var replacement_position := expected_positions[SIMULTANEOUS_COUNT - 1 - index] + Vector2(31.0, -19.0)
		var replacement: InfectionEnemy = game._spawn_enemy(&"pneumococcus", replacement_position)
		_assert_true(ids.has(replacement.get_instance_id()), "Simultaneous churn reuses a known pool instance")
		_assert_vector(replacement.global_position, game.topology.wrap_position(replacement_position), "Simultaneous churn never exposes the previous slot position")
		ids.erase(replacement.get_instance_id())
	_assert_true(ids.is_empty(), "Every simultaneously recycled instance is leased at most once")

func _test_pause_mid_materialization(game: Node) -> void:
	var enemy: InfectionEnemy = game._spawn_enemy(&"pneumococcus", Vector2(403.0, 171.0))
	enemy._physics_process(InfectionEnemy.SPAWN_TELEGRAPH_SECONDS * 0.5)
	var timer_before := enemy.spawn_timer
	var position_before := enemy.global_position
	paused = true
	for _frame in range(8):
		await process_frame
	_assert_near(enemy.spawn_timer, timer_before, "Pause freezes the materialization timer")
	_assert_vector(enemy.global_position, position_before, "Pause freezes the materializing enemy transform")
	_assert_true(not enemy.is_targetable(), "Paused telegraph cannot become targetable")
	paused = false

func _test_torus_interpolation_boundary(game: Node) -> void:
	var bounds: Rect2 = game.topology.bounds
	var enemy: InfectionEnemy = game._spawn_enemy(&"pneumococcus", Vector2(bounds.end.x - 0.1, 0.0))
	enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	game.avatar.global_position = Vector2(bounds.position.x + 2.0, 0.0)
	var before_distance: float = game.topology.distance(enemy.global_position, game.avatar.global_position)
	enemy._physics_process(0.02)
	var after_distance: float = game.topology.distance(enemy.global_position, game.avatar.global_position)
	_assert_true(bounds.has_point(enemy.global_position) or is_equal_approx(enemy.global_position.x, bounds.end.x), "Torus movement leaves the enemy inside arena bounds")
	_assert_true(after_distance <= before_distance + POSITION_EPSILON, "Torus movement follows the shortest seam-aware path")

func _assert_vector(actual: Vector2, expected: Vector2, message: String) -> void:
	_assert_true(actual.distance_to(expected) <= POSITION_EPSILON, "%s (%s != %s)" % [message, actual, expected])

func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= POSITION_EPSILON, "%s (%.4f != %.4f)" % [message, actual, expected])

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)
