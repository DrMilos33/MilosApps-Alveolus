extends SceneTree

const GameScript = preload("res://scripts/game.gd")

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var telemetry := RenderStressTelemetry.new().configure(_snapshot, 0.02, 0.25)
	telemetry.begin()
	for _index in range(30):
		telemetry.sample_frame(0.01)
	var report := telemetry.latest_report()
	_assert_equal(report.get("schema"), RenderStressTelemetry.SCHEMA, "Report uses the stable schema")
	_assert_true(telemetry.completed, "Requested render window completes")
	_assert_equal(telemetry.frame_count(), 25, "Warm-up frames are excluded from the measurement")
	var timing: Dictionary = report.get("timing_ms", {})
	_assert_near(float(timing.get("p50", 0.0)), 10.0, "p50 is calculated from rendered frame deltas")
	_assert_near(float(timing.get("p95", 0.0)), 10.0, "p95 is calculated from rendered frame deltas")
	_assert_near(float(timing.get("p99", 0.0)), 10.0, "p99 is calculated from rendered frame deltas")
	_assert_near(float(timing.get("max", 0.0)), 10.0, "maximum frame time is reported")
	_assert_equal((report.get("entities", {}) as Dictionary).get("enemies"), 600, "Entity counts come from the game snapshot")
	_assert_equal(RenderStressTelemetry.EXPECTED_ENTITIES.projectiles, GameScript.REGULAR_PROJECTILE_LIMIT, "Stress telemetry follows the regular projectile lane and preserves the critical reserve")
	_assert_equal((report.get("quality", {}) as Dictionary).get("current"), "FULL", "Quality tier comes from the game snapshot")
	var acceptance: Dictionary = report.get("acceptance", {})
	_assert_true(bool(acceptance.get("valid", false)), "Exact flow, entity and renderer load remains valid across every telemetry snapshot")
	var continuous: Dictionary = acceptance.get("continuous", {})
	_assert_true(bool(continuous.get("valid", false)), "Periodic exact-load acceptance remains valid for the complete measurement")
	_assert_true(int(continuous.get("sample_count", 0)) >= 2, "Continuous acceptance includes start and final samples")
	_assert_equal(((continuous.get("entity_ranges", {}) as Dictionary).get("enemies", {}) as Dictionary).get("min"), 600, "Continuous telemetry records the minimum enemy load")
	_assert_true(bool(RenderStressTelemetry.validate_acceptance_snapshot(_snapshot()).get("valid", false)), "The canonical exact-load snapshot is accepted")
	var stopped := _snapshot()
	(stopped["flow"] as Dictionary)["running_active"] = false
	_assert_true(not bool(RenderStressTelemetry.validate_acceptance_snapshot(stopped).get("valid", true)), "A stopped run is rejected even when raw entity counts still match")
	var missing_projectile_visual := _snapshot()
	(missing_projectile_visual["render"] as Dictionary)["projectile_visuals"] = GameScript.REGULAR_PROJECTILE_LIMIT - 1
	_assert_true(not bool(RenderStressTelemetry.validate_acceptance_snapshot(missing_projectile_visual).get("valid", true)), "A missing projectile visual rejects the stress load")
	var wrong_enemy_load := _snapshot()
	(wrong_enemy_load["entities"] as Dictionary)["enemies"] = 599
	_assert_true(not bool(RenderStressTelemetry.validate_acceptance_snapshot(wrong_enemy_load).get("valid", true)), "Approximate enemy load cannot pass exact-load telemetry")
	var development: Dictionary = report.get("development", {})
	_assert_true(development.has("snapshots") and development.has("delta"), "Resource development contains snapshots and deltas")
	if failures == 0:
		print("ALVEOLUS_RENDER_STRESS_TELEMETRY_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_RENDER_STRESS_TELEMETRY_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _snapshot() -> Dictionary:
	return {
		"quality": "FULL",
		"flow": {"state": int(GameFlowState.State.RUNNING), "running": true, "run_active": true, "running_active": true},
		"entities": {"enemies": 600, "pickups": 360, "projectiles": GameScript.REGULAR_PROJECTILE_LIMIT, "feedback": 80},
		"pools": {"enemies": {"active": 600, "capacity": 640}},
		"render": {
			"draw_calls_in_frame": 7,
			"crowd_enemy_visuals": 600,
			"crowd_pickup_visuals": 360,
			"crowd_visuals": 960,
			"projectile_visuals": GameScript.REGULAR_PROJECTILE_LIMIT,
			"feedback_visuals": 80,
		},
	}

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])

func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(is_equal_approx(actual, expected), "%s (expected %.3f, got %.3f)" % [message, expected, actual])
