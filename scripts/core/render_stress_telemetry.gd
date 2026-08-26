class_name RenderStressTelemetry
extends RefCounted

## Render-frame telemetry for the explicit --stress-test / ?stress=1 path.
##
## This observer never drives simulation or quality. The game calls
## sample_frame() once from its rendered _process() callback and supplies a
## read-only snapshot provider. That keeps instrumentation out of combat and
## renderer ownership while still measuring whole presented-frame intervals.

const SCHEMA := "alveolus.render_stress.v1"
const LOG_PREFIX := "ALVEOLUS_RENDER_STRESS_JSON="
const DEFAULT_WARMUP_SECONDS := 2.0
const DEFAULT_MEASUREMENT_SECONDS := 3.0
const MIN_DURATION_SECONDS := 0.25
const ACCEPTANCE_SAMPLE_SECONDS := 1.0
const MAX_REPORTED_ACCEPTANCE_VIOLATIONS := 32
const EXPECTED_ENTITIES := {
	"enemies": 600,
	"pickups": 360,
	# The regular lane leaves 48 of 512 runtime slots available for critical
	# case-pressure projectiles, including in the explicit stress fixture.
	"projectiles": 464,
	"feedback": 80,
}
const EXPECTED_RENDER_VISUALS := {
	"crowd_enemy_visuals": 600,
	"crowd_pickup_visuals": 360,
	"crowd_visuals": 960,
	"projectile_visuals": 464,
	"feedback_visuals": 80,
}

var warmup_seconds: float = DEFAULT_WARMUP_SECONDS
var measurement_seconds: float = DEFAULT_MEASUREMENT_SECONDS
var snapshot_provider: Callable

var active: bool = false
var completed: bool = false
var total_elapsed_seconds: float = 0.0
var measured_elapsed_seconds: float = 0.0

var _frame_times_ms: Array[float] = []
var _start_snapshot: Dictionary = {}
var _warmup_snapshot: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _quality_timeline: Array[Dictionary] = []
var _last_quality: String = ""
var _report: Dictionary = {}
var _next_acceptance_sample_seconds: float = ACCEPTANCE_SAMPLE_SECONDS
var _last_acceptance_sample_seconds: float = -1.0
var _continuous_sample_count: int = 0
var _continuous_violation_count: int = 0
var _continuous_violations: Array[Dictionary] = []
var _entity_ranges: Dictionary = {}
var _render_ranges: Dictionary = {}

func configure(
	provider: Callable,
	warmup_duration_seconds: float = DEFAULT_WARMUP_SECONDS,
	measurement_duration_seconds: float = DEFAULT_MEASUREMENT_SECONDS
) -> RenderStressTelemetry:
	snapshot_provider = provider
	warmup_seconds = maxf(warmup_duration_seconds, 0.0)
	measurement_seconds = maxf(measurement_duration_seconds, MIN_DURATION_SECONDS)
	return self

func begin() -> void:
	active = true
	completed = false
	total_elapsed_seconds = 0.0
	measured_elapsed_seconds = 0.0
	_frame_times_ms.clear()
	_quality_timeline.clear()
	_last_quality = ""
	_report.clear()
	_next_acceptance_sample_seconds = ACCEPTANCE_SAMPLE_SECONDS
	_last_acceptance_sample_seconds = -1.0
	_continuous_sample_count = 0
	_continuous_violation_count = 0
	_continuous_violations.clear()
	_entity_ranges.clear()
	_render_ranges.clear()
	_start_snapshot = _capture_snapshot()
	_warmup_snapshot.clear()
	_last_snapshot = _start_snapshot
	_track_quality(_start_snapshot)
	_record_continuous_acceptance(_start_snapshot, 0.0)
	_publish_browser_event("alveolus.render_stress.ready", {
		"schema": SCHEMA,
		"warmup_seconds": warmup_seconds,
		"measurement_seconds": measurement_seconds,
	})

func sample_frame(delta: float) -> bool:
	if not active or completed or delta <= 0.0:
		return false
	var previous_elapsed := total_elapsed_seconds
	total_elapsed_seconds += delta
	if _warmup_snapshot.is_empty() and total_elapsed_seconds >= warmup_seconds:
		_warmup_snapshot = _capture_snapshot()
		_track_quality(_warmup_snapshot)
	if total_elapsed_seconds + 0.000001 >= _next_acceptance_sample_seconds:
		var periodic_snapshot := _capture_snapshot()
		_last_snapshot = periodic_snapshot
		_track_quality(periodic_snapshot)
		_record_continuous_acceptance(periodic_snapshot, total_elapsed_seconds)
		_next_acceptance_sample_seconds = total_elapsed_seconds + ACCEPTANCE_SAMPLE_SECONDS
	# A frame crossing the warm-up boundary is excluded rather than partially
	# counted. This prevents startup/import work from contaminating render p95.
	if previous_elapsed >= warmup_seconds:
		_frame_times_ms.append(delta * 1000.0)
		measured_elapsed_seconds += delta
	if measured_elapsed_seconds + 0.000001 < measurement_seconds:
		return false
	_finish()
	return true

func latest_report() -> Dictionary:
	return _report.duplicate(true)

func frame_count() -> int:
	return _frame_times_ms.size()

static func summarize_ms(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values:
		total += value
	return {
		"avg": total / float(values.size()),
		"p50": percentile_sorted(sorted, 0.50),
		"p95": percentile_sorted(sorted, 0.95),
		"p99": percentile_sorted(sorted, 0.99),
		"max": sorted[-1],
	}

static func percentile_sorted(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		ceili(clampf(fraction, 0.0, 1.0) * float(sorted_values.size())) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]

static func validate_acceptance_snapshot(snapshot: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var flow: Dictionary = snapshot.get("flow", {})
	if not bool(flow.get("running_active", false)):
		failures.append("flow.running_active must remain true")
	if not bool(flow.get("running", false)):
		failures.append("flow.running must remain true")
	if not bool(flow.get("run_active", false)):
		failures.append("flow.run_active must remain true")

	var entities: Dictionary = snapshot.get("entities", {})
	for key in EXPECTED_ENTITIES:
		var expected := int(EXPECTED_ENTITIES[key])
		var actual := int(entities.get(key, -1))
		if actual != expected:
			failures.append("entities.%s expected %d, got %d" % [key, expected, actual])

	var render: Dictionary = snapshot.get("render", {})
	for key in EXPECTED_RENDER_VISUALS:
		var expected := int(EXPECTED_RENDER_VISUALS[key])
		var actual := int(render.get(key, -1))
		if actual != expected:
			failures.append("render.%s expected %d, got %d" % [key, expected, actual])

	return {
		"valid": failures.is_empty(),
		"failures": failures,
		"observed": {
			"running_active": bool(flow.get("running_active", false)),
			"entities": entities.duplicate(true),
			"render": render.duplicate(true),
		},
	}

func _finish() -> void:
	active = false
	completed = true
	if _warmup_snapshot.is_empty():
		_warmup_snapshot = _capture_snapshot()
	_last_snapshot = _capture_snapshot()
	_track_quality(_last_snapshot)
	_record_continuous_acceptance(_last_snapshot, total_elapsed_seconds)
	var timing := summarize_ms(_frame_times_ms)
	var warmup_resources: Dictionary = _warmup_snapshot.get("resources", {})
	var final_resources: Dictionary = _last_snapshot.get("resources", {})
	var start_resources: Dictionary = _start_snapshot.get("resources", {})
	var p95 := float(timing.get("p95", 0.0))
	var p99 := float(timing.get("p99", 0.0))
	var maximum := float(timing.get("max", 0.0))
	var rendered := DisplayServer.get_name() != "headless"
	var start_acceptance := validate_acceptance_snapshot(_start_snapshot)
	var warmup_acceptance := validate_acceptance_snapshot(_warmup_snapshot)
	var final_acceptance := validate_acceptance_snapshot(_last_snapshot)
	var acceptance_held := (
		bool(start_acceptance.get("valid", false))
		and bool(warmup_acceptance.get("valid", false))
		and bool(final_acceptance.get("valid", false))
		and _continuous_sample_count > 0
		and _continuous_violation_count == 0
	)
	_report = {
		"schema": SCHEMA,
		"rendered": rendered,
		"passed": rendered and acceptance_held and not _frame_times_ms.is_empty() and p95 <= 16.7 and p99 <= 20.0 and maximum <= 33.3,
		"machine": _machine_metadata(),
		"warmup_seconds": warmup_seconds,
		"measured_seconds": measured_elapsed_seconds,
		"frames": _frame_times_ms.size(),
		"timing_ms": timing,
		"fps": {
			"effective": float(_frame_times_ms.size()) / maxf(measured_elapsed_seconds, 0.000001),
			"one_percent_low": 1000.0 / maxf(p99, 0.001),
		},
		"quality": {
			"current": str(_last_snapshot.get("quality", "unknown")),
			"timeline": _quality_timeline,
		},
		"entities": (_last_snapshot.get("entities", {}) as Dictionary).duplicate(true),
		"pools": (_last_snapshot.get("pools", {}) as Dictionary).duplicate(true),
		"render": (_last_snapshot.get("render", {}) as Dictionary).duplicate(true),
		"acceptance": {
			"valid": acceptance_held,
			"expected_entities": EXPECTED_ENTITIES.duplicate(true),
			"expected_render_visuals": EXPECTED_RENDER_VISUALS.duplicate(true),
			"snapshots": {
				"start": start_acceptance,
				"after_warmup": warmup_acceptance,
				"end": final_acceptance,
			},
			"continuous": {
				"valid": _continuous_sample_count > 0 and _continuous_violation_count == 0,
				"interval_seconds": ACCEPTANCE_SAMPLE_SECONDS,
				"sample_count": _continuous_sample_count,
				"violation_count": _continuous_violation_count,
				"violations": _continuous_violations.duplicate(true),
				"entity_ranges": _entity_ranges.duplicate(true),
				"render_ranges": _render_ranges.duplicate(true),
			},
		},
		"development": {
			"snapshots": {
				"start": start_resources,
				"after_warmup": warmup_resources,
				"end": final_resources,
			},
			"delta": {
				"since_start": _resource_delta(start_resources, final_resources),
				"after_warmup": _resource_delta(warmup_resources, final_resources),
			},
		},
	}
	var encoded := JSON.stringify(_report)
	print(LOG_PREFIX + encoded)
	_publish_browser_event("alveolus.render_stress.result", _report)

func _record_continuous_acceptance(snapshot: Dictionary, elapsed_seconds: float) -> void:
	if is_equal_approx(elapsed_seconds, _last_acceptance_sample_seconds):
		return
	_last_acceptance_sample_seconds = elapsed_seconds
	_continuous_sample_count += 1
	var validation := validate_acceptance_snapshot(snapshot)
	var entities: Dictionary = snapshot.get("entities", {})
	var render: Dictionary = snapshot.get("render", {})
	for key in EXPECTED_ENTITIES:
		_update_observed_range(_entity_ranges, str(key), int(entities.get(key, -1)))
	for key in EXPECTED_RENDER_VISUALS:
		_update_observed_range(_render_ranges, str(key), int(render.get(key, -1)))
	if bool(validation.get("valid", false)):
		return
	_continuous_violation_count += 1
	if _continuous_violations.size() < MAX_REPORTED_ACCEPTANCE_VIOLATIONS:
		_continuous_violations.append({
			"elapsed_seconds": elapsed_seconds,
			"failures": (validation.get("failures", []) as Array).duplicate(),
		})

static func _update_observed_range(ranges: Dictionary, key: String, value: int) -> void:
	var observed: Dictionary = ranges.get(key, {"min": value, "max": value})
	observed["min"] = mini(int(observed.get("min", value)), value)
	observed["max"] = maxi(int(observed.get("max", value)), value)
	ranges[key] = observed

func _capture_snapshot() -> Dictionary:
	var gameplay: Dictionary = {}
	if snapshot_provider.is_valid():
		var supplied: Variant = snapshot_provider.call()
		if supplied is Dictionary:
			gameplay = supplied
	var snapshot := gameplay.duplicate(true)
	snapshot["resources"] = {
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"memory_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}
	return snapshot

func _track_quality(snapshot: Dictionary) -> void:
	var current := str(snapshot.get("quality", "unknown"))
	if current == _last_quality:
		return
	_last_quality = current
	_quality_timeline.append({
		"elapsed_seconds": total_elapsed_seconds,
		"tier": current,
	})

static func _resource_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in after:
		var after_value: Variant = after[key]
		var before_value: Variant = before.get(key, 0)
		if (after_value is int or after_value is float) and (before_value is int or before_value is float):
			result[key] = after_value - before_value
	return result

static func _machine_metadata() -> Dictionary:
	return {
		"engine": str(Engine.get_version_info().get("string", "unknown")),
		"platform": OS.get_name(),
		"web": OS.has_feature("web"),
		"display_server": DisplayServer.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
	}

func _publish_browser_event(event_type: String, payload: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	# JSON.stringify produces a safe JavaScript object expression: telemetry
	# strings cannot break out into executable source. parent.postMessage makes
	# the same-origin soak harness independent from Godot's console formatting.
	var script := "window.parent.postMessage({type:%s,payload:%s}, '*');" % [
		JSON.stringify(event_type),
		JSON.stringify(payload),
	]
	JavaScriptBridge.eval(script, true)
