class_name PerformanceMetrics
extends RefCounted

## Shared, deterministic reporting helpers for native, headless and browser
## performance contracts. Reports intentionally use plain Dictionaries so
## external runners can consume each `*_JSON=` log line without Godot types.

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
	var index := clampi(ceili(clampf(fraction, 0.0, 1.0) * float(sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]

static func monitor_snapshot() -> Dictionary:
	return {
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"memory_peak": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	}

static func machine_metadata() -> Dictionary:
	return {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"platform": OS.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
	}
