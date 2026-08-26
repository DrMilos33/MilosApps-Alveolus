extends SceneTree

var assertions := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var file := FileAccess.open("res://tests/browser_soak_harness.html", FileAccess.READ)
	_assert_true(file != null, "Browser soak harness can be opened")
	if file == null:
		_finish()
		return
	var source := file.get_as_text()
	_assert_contains(source, "width: 1280px;", "Harness keeps a fixed 1280-pixel CSS surface")
	_assert_contains(source, "height: 720px;", "Harness keeps a fixed 720-pixel CSS surface")
	_assert_contains(source, "width=\"1280\" height=\"720\"", "Iframe backing attributes define 1280 by 720")
	_assert_contains(source, "new Float64Array(capacity)", "rAF samples use a preallocated typed buffer")
	_assert_true(not source.contains("samples.push("), "rAF measurement never grows a dynamic sample array")
	_assert_contains(source, "function onAnimationFrame(timestamp)", "Measurement is callback-driven by requestAnimationFrame")
	_assert_contains(source, "visibility_focus_timeline", "Report contains the visibility and focus timeline")
	_assert_contains(source, "document_was_hidden", "A hidden harness is a hard acceptance failure")
	_assert_contains(source, "alveolus_soak_run_id", "Every navigation carries an explicit run identifier")
	_assert_contains(source, "protocol.duplicate_result", "Duplicate game telemetry is rejected")
	_assert_contains(source, "iframe.error", "Iframe exceptions are captured")
	_assert_contains(source, "parent.unhandledrejection", "Parent promise failures are captured")
	_assert_contains(source, "canvas_backing_scale", "Canvas CSS and backing-store scale are validated")
	_assert_contains(source, "telemetry_rendered", "Rendered telemetry is mandatory")
	_assert_contains(source, "telemetry_web", "A Web runtime is mandatory")
	_assert_contains(source, "telemetry_acceptance", "In-game acceptance is mandatory")
	_assert_contains(source, "projectiles: 464", "Browser soak follows the regular projectile lane and preserves the 48-slot critical reserve")
	_assert_contains(source, "projectile_visuals: 464", "Browser soak validates the exact regular projectile render load")
	_assert_true(not source.contains("game_performance_not_passed"), "Web exact-load validation does not reuse native timing gates")
	_assert_true(not source.contains("if (game?.passed !== true)"), "Web hard acceptance uses the browser performance budget")
	_assert_contains(source, "summary.timing.p95 <= 22.2", "Browser acceptance keeps the explicit p95 budget")
	_assert_contains(source, "window.__ALVEOLUS_SOAK__ = { done: true, report }", "Automation receives a stable completion API")
	_assert_contains(source, "schema: \"alveolus.browser_performance.v1\"", "Hardened reports preserve the stable browser schema")
	_finish()

func _finish() -> void:
	if failures == 0:
		print("ALVEOLUS_BROWSER_SOAK_HARNESS_STATIC_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_BROWSER_SOAK_HARNESS_STATIC_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _assert_contains(source: String, needle: String, message: String) -> void:
	_assert_true(source.contains(needle), message)

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
