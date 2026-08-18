extends SceneTree

class FakeEnemyDefinition:
	extends RefCounted
	var radius: float = 10.0

class FakeEnemy:
	extends Node2D
	var definition := FakeEnemyDefinition.new()
	var targetable: bool = true

	func is_targetable() -> bool:
		return targetable

class FakeAvatar:
	extends Node2D
	var last_facing: Vector2 = Vector2.DOWN

var assertions: int = 0
var failures: int = 0
var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
var enemies: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_manual_strategies()
	await _test_controller_sampling()
	_test_spread_resolution()
	_test_packed_query_records()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.free()
	enemies.clear()
	if failures == 0:
		print("ALVEOLUS_TREATMENT_AIM_RESOLUTION_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_TREATMENT_AIM_RESOLUTION_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _test_manual_strategies() -> void:
	var definitions := TreatmentDefinition.catalog()
	var precise: TreatmentDefinition = definitions[&"treatment_precision"]
	var precise_build := RunBuildState.from_treatment(precise)
	var precise_shots := PreciseTreatmentStrategy.new().create_shots(
		Vector2.ZERO, Vector2.UP, [], topology, precise, precise_build, null, true
	)
	_assert_equal(precise_shots.size(), 1, "Manual precise treatment fires without an auto target")
	_assert_equal(precise_shots[0].mode, TreatmentShot.Mode.DIRECTIONAL, "Manual precise treatment uses a fixed directional projectile")
	_assert_true(precise_shots[0].direction.is_equal_approx(Vector2.UP), "Manual precise heading preserves the fixed-tick aim")

	var piercing: TreatmentDefinition = definitions[&"treatment_pierce"]
	var piercing_shots := PiercingTreatmentStrategy.new().create_shots(
		Vector2.ZERO, Vector2.LEFT, [], topology, piercing, RunBuildState.from_treatment(piercing), null, true
	)
	_assert_equal(piercing_shots.size(), 1, "Manual piercing treatment fires without an auto target")
	_assert_true(piercing_shots[0].direction.is_equal_approx(Vector2.LEFT), "Manual piercing treatment uses the sampled heading")

func _test_controller_sampling() -> void:
	var avatar := FakeAvatar.new()
	avatar.position = Vector2(20.0, 30.0)
	get_root().add_child(avatar)
	var definition: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var build := RunBuildState.from_treatment(definition)
	build.set_base(RunBuildState.TREATMENT_MANUAL_AIM, 1.0)
	var counter := {"calls": 0}
	var controller := TreatmentController.new()
	get_root().add_child(controller)
	controller.configure(
		definition,
		build,
		topology,
		avatar,
		func() -> Array: return [],
		null,
		func() -> Vector2:
			counter.calls = int(counter.calls) + 1
			return avatar.global_position + Vector2(120.0, 0.0)
	)
	var shots := controller.step(0.2)
	_assert_equal(int(counter.calls), 1, "Aim provider is sampled exactly once on the firing tick")
	_assert_equal(shots.size(), 1, "Controller forwards manual aim into its strategy")
	_assert_true(shots[0].direction.is_equal_approx(Vector2.RIGHT), "World target is converted to a deterministic torus-aware heading")
	controller.queue_free()
	avatar.queue_free()
	await process_frame

func _test_spread_resolution() -> void:
	var first := FakeEnemy.new()
	first.position = Vector2(100.0, 0.0)
	get_root().add_child(first)
	var second := FakeEnemy.new()
	second.position = Vector2(200.0, 0.0)
	get_root().add_child(second)
	enemies.append_array([first, second])
	var spread: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_spread"]
	var build := RunBuildState.from_treatment(spread)
	build.set_base(RunBuildState.TREATMENT_MAX_HITS, 1.0)
	var shots := SpreadTreatmentStrategy.new().create_shots(
		Vector2.ZERO, Vector2.RIGHT, enemies, topology, spread, build, null, true
	)
	var center: TreatmentShot = shots[1]
	_assert_equal(center.resolved_targets.size(), 1, "Every spread ray owns its resolved target snapshot")
	_assert_equal(center.resolved_targets[0], first, "Base spread ray stops at its first target")
	_assert_near(center.requested_range_value, spread.base_range, "Shot retains its uncut gameplay range")
	_assert_near(center.range_value, 77.0, "Visible ray ends at the first body-surface contact")
	_assert_near(shots[0].range_value, spread.base_range, "A neighboring ray without a hit keeps its full range")

	build.set_base(RunBuildState.TREATMENT_MAX_HITS, 2.0)
	shots = SpreadTreatmentStrategy.new().create_shots(
		Vector2.ZERO, Vector2.RIGHT, enemies, topology, spread, build, null, true
	)
	center = shots[1]
	_assert_equal(center.resolved_targets.size(), 2, "Spread penetration rank raises the per-ray hit limit")
	_assert_near(center.range_value, 177.0, "Penetrating spread ray ends at its last allowed collision")

func _test_packed_query_records() -> void:
	var first := EntityHandle.make(0, 1)
	var second := EntityHandle.make(1, 1)
	var handles := PackedInt64Array([second, first])
	var positions := {
		first: Vector2(100.0, 0.0),
		second: Vector2(200.0, 0.0),
	}
	var query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return positions[handle],
		func(_handle: int) -> float: return 10.0,
		func(_handle: int) -> bool: return true,
		func(handle: int) -> Variant: return positions[handle],
		64.0,
		10.0
	)
	query.rebuild(handles)
	var records := query.line_hits(Vector2.ZERO, Vector2.RIGHT, 300.0, 13.0, 2)
	_assert_equal(records.size(), 2, "Packed query returns the requested ordered contacts")
	_assert_equal(int(records[0].handle), first, "Packed contacts are ordered front to back")
	_assert_near(float(records[0].entry_distance), 77.0, "Packed contact exposes body-surface entry distance")
	_assert_equal(query.line(Vector2.ZERO, Vector2.RIGHT, 300.0, 13.0, 1)[0], first, "Legacy handle facade uses the same contact ordering")

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_near(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (%.3f != %.3f)" % [message, actual, expected])
