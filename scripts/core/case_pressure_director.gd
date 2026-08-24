class_name CasePressureDirector
extends RefCounted

## Pure run-clock scheduler for authored case-pressure events.
##
## Seed rolls and gate orientations are precomputed from a dedicated stream
## during configure(). A due event resolves that roll against the last emitted
## sector, so skipped target slots do not become phantom recent spawns. Fixed-
## tick size and player movement cannot alter a planned timestamp or seed roll.
## Intro or boss input cancels the remaining plan for that run; reset() re-arms
## the same deterministic plan.
##
## Returned event dictionaries contain kind, scheduled_time, sequence,
## spawn_sector, and gate_orientation. The two angular values use sector slots;
## target events carry NO_GATE_ORIENTATION.

signal event_due(kind: int, scheduled_time: float, spawn_sector: int, gate_orientation: int)

enum EventKind {
	TARGET_FOCUS,
	PROJECTILE_GATE,
}

const DEFAULT_SECTOR_COUNT := 12
const NO_GATE_ORIENTATION := -1
const TIME_EPSILON := 0.000001

var _target_focus_times := PackedFloat32Array()
var _projectile_gate_times := PackedFloat32Array()
var _max_active_targets: int = 0
var _sector_count: int = DEFAULT_SECTOR_COUNT
var _planned_events: Array[Dictionary] = []
var _event_cursor: int = 0
var _elapsed_seconds: float = 0.0
var _cancelled: bool = false
var _recent_spawn_sector: int = -1


func configure(
	plan: CasePressurePlan,
	run_seed: int,
	sector_count: int = DEFAULT_SECTOR_COUNT
) -> CasePressureDirector:
	_target_focus_times = plan.target_focus_times.duplicate() if plan != null else PackedFloat32Array()
	_projectile_gate_times = plan.projectile_gate_times.duplicate() if plan != null else PackedFloat32Array()
	_max_active_targets = maxi(plan.max_active_targets, 0) if plan != null else 0
	_sector_count = maxi(sector_count, 4)
	_build_planned_events(run_seed)
	reset()
	return self


func reset() -> void:
	_event_cursor = 0
	_elapsed_seconds = 0.0
	_cancelled = false
	_recent_spawn_sector = -1


func cancel() -> void:
	_event_cursor = _planned_events.size()
	_cancelled = true


func advance(
	elapsed_seconds: float,
	active_target_count: int,
	is_intro: bool,
	boss_active: bool
) -> Array[Dictionary]:
	var due_events: Array[Dictionary] = []
	if _cancelled:
		return due_events
	if is_intro or boss_active:
		cancel()
		return due_events
	if not is_finite(elapsed_seconds):
		return due_events

	_elapsed_seconds = maxf(_elapsed_seconds, maxf(elapsed_seconds, 0.0))
	var reserved_targets := maxi(active_target_count, 0)
	while _event_cursor < _planned_events.size():
		var planned_event := _planned_events[_event_cursor]
		if float(planned_event[&"scheduled_time"]) > _elapsed_seconds + TIME_EPSILON:
			break
		_event_cursor += 1
		var kind := int(planned_event[&"kind"])
		if kind == EventKind.TARGET_FOCUS:
			if _max_active_targets <= 0 or reserved_targets >= _max_active_targets:
				continue
			reserved_targets += 1
		var due_event := planned_event.duplicate(true)
		var spawn_sector := _sector_from_roll(int(due_event[&"sector_roll"]), _recent_spawn_sector)
		due_event.erase(&"sector_roll")
		due_event[&"spawn_sector"] = spawn_sector
		_recent_spawn_sector = spawn_sector
		due_events.append(due_event)
		event_due.emit(
			kind,
			float(due_event[&"scheduled_time"]),
			int(due_event[&"spawn_sector"]),
			int(due_event[&"gate_orientation"])
		)
	return due_events


func is_cancelled() -> bool:
	return _cancelled


func elapsed_seconds() -> float:
	return _elapsed_seconds


func pending_event_count() -> int:
	return _planned_events.size() - _event_cursor


func sector_count() -> int:
	return _sector_count


func _build_planned_events(run_seed: int) -> void:
	_planned_events.clear()
	for scheduled_time in _target_focus_times:
		_planned_events.append({
			&"kind": EventKind.TARGET_FOCUS,
			&"scheduled_time": scheduled_time,
		})
	for scheduled_time in _projectile_gate_times:
		_planned_events.append({
			&"kind": EventKind.PROJECTILE_GATE,
			&"scheduled_time": scheduled_time,
		})
	_planned_events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_time := float(left[&"scheduled_time"])
		var right_time := float(right[&"scheduled_time"])
		if left_time == right_time:
			return int(left[&"kind"]) < int(right[&"kind"])
		return left_time < right_time
	)

	var random := RandomNumberGenerator.new()
	random.seed = run_seed
	for sequence in range(_planned_events.size()):
		var planned_event := _planned_events[sequence]
		var kind := int(planned_event[&"kind"])
		planned_event[&"sequence"] = sequence
		planned_event[&"sector_roll"] = random.randi()
		planned_event[&"gate_orientation"] = (
			random.randi_range(0, _sector_count - 1)
			if kind == EventKind.PROJECTILE_GATE
			else NO_GATE_ORIENTATION
		)


func _sector_from_roll(sector_roll: int, recent_sector: int) -> int:
	if recent_sector < 0:
		return posmod(sector_roll, _sector_count)
	var allowed_sectors := PackedInt32Array()
	var previous_neighbor := posmod(recent_sector - 1, _sector_count)
	var next_neighbor := posmod(recent_sector + 1, _sector_count)
	for sector in range(_sector_count):
		if sector == previous_neighbor or sector == recent_sector or sector == next_neighbor:
			continue
		allowed_sectors.append(sector)
	return allowed_sectors[posmod(sector_roll, allowed_sectors.size())]
