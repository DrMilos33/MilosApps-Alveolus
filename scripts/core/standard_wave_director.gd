class_name StandardWaveDirector
extends RefCounted

## Batches the established standard-spawn density into short, deterministic
## packets. The director owns only run-local wave state; Game remains the sole
## entity materialization adapter.

const SPAWN_DENSITY_MULTIPLIER := 1.10
const MAXIMUM_WAIT_SECONDS := 4.5
const MINIMUM_CLEAR_WAIT_SECONDS := 2.0
const CLEAR_DEFEATED_FRACTION := 0.70
const MAX_MATERIALIZATIONS_PER_TICK := 4
const MAX_PENDING_INTENTS := 64
const MINIMUM_OPEN_WEIGHT := 4
const WAVE_RANDOM_SALT := 0x57415645


class SpawnIntent extends RefCounted:
	var wave_ordinal: int
	var enemy_id: StringName
	var health_scale: float
	var weight: int


	func _init(
		wave_ordinal_value: int,
		enemy_id_value: StringName,
		health_scale_value: float,
		weight_value: int
	) -> void:
		wave_ordinal = wave_ordinal_value
		enemy_id = enemy_id_value
		health_scale = health_scale_value
		weight = maxi(weight_value, 1)


var _random := RandomNumberGenerator.new()
var _configured: bool = false
var _cancelled: bool = true
var _wave_ordinal: int = 0
var _wave_age_seconds: float = 0.0
var _seconds_until_forced_wave: float = MAXIMUM_WAIT_SECONDS
var _slot_credit: float = 0.0
var _current_handles := PackedInt64Array()
var _current_weights := PackedInt32Array()
var _current_total_weight: int = 0
var _current_alive_weight: int = 0
var _pending_intents: Array[SpawnIntent] = []
var _pending_cursor: int = 0


func configure(seed: int) -> StandardWaveDirector:
	_random.seed = seed ^ WAVE_RANDOM_SALT
	_configured = true
	_cancelled = false
	_wave_ordinal = 0
	_wave_age_seconds = 0.0
	_seconds_until_forced_wave = MAXIMUM_WAIT_SECONDS
	_slot_credit = 0.0
	_clear_current_wave()
	_pending_intents.clear()
	_pending_cursor = 0
	return self


func begin_initial_wave(handles: PackedInt64Array, weights: PackedInt32Array) -> void:
	_clear_current_wave()
	if not _configured or _cancelled:
		return
	var count := mini(handles.size(), weights.size())
	for index in range(count):
		var handle := int(handles[index])
		var weight := maxi(int(weights[index]), 1)
		if not EntityHandle.is_valid(handle):
			continue
		_current_handles.append(handle)
		_current_weights.append(weight)
		_current_total_weight += weight
		_current_alive_weight += weight


func advance_clock(delta: float, capacity_blocked: bool = false) -> bool:
	if not _configured or _cancelled or has_pending_intents() or capacity_blocked:
		return false
	var step := maxf(delta, 0.0)
	_wave_age_seconds += step
	_seconds_until_forced_wave = maxf(0.0, _seconds_until_forced_wave - step)
	if _seconds_until_forced_wave <= 0.0:
		return true
	if _wave_age_seconds < MINIMUM_CLEAR_WAIT_SECONDS or _current_total_weight <= 0:
		return false
	var defeated_weight := _current_total_weight - _current_alive_weight
	return defeated_weight >= ceili(float(_current_total_weight) * CLEAR_DEFEATED_FRACTION)


func open_wave(
	config: RunConfig,
	progress: float,
	available_weight: int,
	clusters_enabled: bool,
	cluster_chance_bonus: float = 0.0,
	interval_factor: float = 1.0
) -> int:
	if not _configured or _cancelled or config == null or available_weight < MINIMUM_OPEN_WEIGHT:
		return 0
	var accrued_packet_seconds := _wave_age_seconds * SPAWN_DENSITY_MULTIPLIER
	_clear_current_wave()
	_pending_intents.clear()
	_pending_cursor = 0
	_wave_ordinal += 1
	_wave_age_seconds = 0.0
	_seconds_until_forced_wave = MAXIMUM_WAIT_SECONDS

	var resolved_progress := clampf(progress, 0.0, 1.0)
	var interval := maxf(
		config.regular_spawn_interval(resolved_progress) * maxf(interval_factor, 0.01),
		0.01
	)
	_slot_credit += accrued_packet_seconds / interval
	var slot_count := maxi(1, floori(_slot_credit))
	_slot_credit -= float(slot_count)
	var body_count := 0
	for _slot_index in range(slot_count):
		body_count += 1
		if resolved_progress > 0.58 and _random.randf() < 0.22:
			body_count += 1
	body_count = mini(body_count, MAX_PENDING_INTENTS)

	var health_scale := config.regular_enemy_health_scale()
	var cluster_chance := clampf(
		lerpf(config.cluster_chance_start, config.cluster_chance_end, resolved_progress) + cluster_chance_bonus,
		0.0,
		0.85
	)
	var remaining_weight := available_weight
	for _body_index in range(body_count):
		if remaining_weight <= 0:
			break
		var enemy_id := &"pneumococcus"
		var weight := 1
		if clusters_enabled and remaining_weight >= 2 and _random.randf() < cluster_chance:
			enemy_id = &"bacterial_cluster"
			weight = 2
		_pending_intents.append(SpawnIntent.new(_wave_ordinal, enemy_id, health_scale, weight))
		remaining_weight -= weight
	return _pending_intents.size()


func take_spawn_intents(maximum: int = MAX_MATERIALIZATIONS_PER_TICK) -> Array[SpawnIntent]:
	var result: Array[SpawnIntent] = []
	if maximum <= 0 or not has_pending_intents():
		return result
	var count := mini(maximum, _pending_intents.size() - _pending_cursor)
	for index in range(count):
		result.append(_pending_intents[_pending_cursor + index])
	_pending_cursor += count
	if _pending_cursor >= _pending_intents.size():
		_pending_intents.clear()
		_pending_cursor = 0
	return result


func commit_spawn(intent: SpawnIntent, handle: int) -> bool:
	if intent == null or intent.wave_ordinal != _wave_ordinal or not EntityHandle.is_valid(handle):
		return false
	_current_handles.append(handle)
	_current_weights.append(intent.weight)
	_current_total_weight += intent.weight
	_current_alive_weight += intent.weight
	return true


func retire(handle: int) -> bool:
	if not EntityHandle.is_valid(handle):
		return false
	for index in range(_current_handles.size()):
		if int(_current_handles[index]) != handle:
			continue
		_current_handles[index] = EntityHandle.INVALID
		_current_alive_weight = maxi(0, _current_alive_weight - int(_current_weights[index]))
		return true
	return false


func force_next_wave() -> void:
	if _configured and not _cancelled:
		_seconds_until_forced_wave = 0.0


func discard_pending_intents() -> void:
	_pending_intents.clear()
	_pending_cursor = 0


func cancel() -> void:
	_cancelled = true
	_clear_current_wave()
	_pending_intents.clear()
	_pending_cursor = 0


func has_pending_intents() -> bool:
	return _pending_cursor < _pending_intents.size()


func pending_intent_count() -> int:
	return maxi(0, _pending_intents.size() - _pending_cursor)


func snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"cancelled": _cancelled,
		"wave_ordinal": _wave_ordinal,
		"wave_age_seconds": _wave_age_seconds,
		"seconds_until_forced_wave": _seconds_until_forced_wave,
		"slot_credit": _slot_credit,
		"current_total_weight": _current_total_weight,
		"current_alive_weight": _current_alive_weight,
		"pending_intents": pending_intent_count(),
		"random_state": _random.state,
	}


func _clear_current_wave() -> void:
	_current_handles.clear()
	_current_weights.clear()
	_current_total_weight = 0
	_current_alive_weight = 0
