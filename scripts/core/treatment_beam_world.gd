class_name TreatmentBeamWorld
extends RefCounted

## Fixed-capacity, fixed-step owner for persistent treatment beams. It has no
## autonomous process loop: RunSession (or a registered callable) advances it,
## so pause freezes ticks, phases and snapshots together.

signal tick_resolved(handle: int, enemy_handles: PackedInt64Array, is_return: bool)
signal snapshot_changed
signal beam_finished(handle: int)

const DEFAULT_CAPACITY := 16
const TIME_EPSILON := 0.00001

var capacity: int = DEFAULT_CAPACITY
var topology: ArenaTopology

var _states: Array[TreatmentBeamState] = []
var _generations := PackedInt32Array()
var _dense_index_by_slot := PackedInt32Array()
var _active_slots := PackedInt32Array()
var _free_slots := PackedInt32Array()


func configure(maximum_beams: int = DEFAULT_CAPACITY, arena_topology: ArenaTopology = null) -> TreatmentBeamWorld:
	var previous_generations := _generations.duplicate()
	capacity = maxi(1, maximum_beams)
	topology = arena_topology
	_states.resize(capacity)
	_states.fill(null)
	_generations.resize(capacity)
	for slot in range(capacity):
		_generations[slot] = EntityHandle.next_generation(previous_generations[slot]) if slot < previous_generations.size() else 1
	_dense_index_by_slot.resize(capacity)
	_dense_index_by_slot.fill(-1)
	_active_slots.clear()
	_free_slots.clear()
	for slot in range(capacity - 1, -1, -1):
		_free_slots.append(slot)
	return self


func spawn(
	origin: Vector2,
	direction: Vector2,
	length: float,
	width: float,
	damage: float,
	duration: float,
	tick_interval: float,
	return_enabled: bool,
	source_id: StringName
) -> int:
	if _states.is_empty():
		configure(capacity, topology)
	if length <= 0.0 or width < 0.0 or damage < 0.0 or duration <= 0.0 or tick_interval <= 0.0 or source_id.is_empty() or _free_slots.is_empty():
		return EntityHandle.INVALID
	var slot := int(_free_slots[-1])
	_free_slots.resize(_free_slots.size() - 1)
	var handle := EntityHandle.make(slot, _generations[slot])
	var state := TreatmentBeamState.new().configure(
		handle,
		origin,
		direction,
		length,
		width,
		damage,
		duration,
		tick_interval,
		return_enabled,
		source_id
	)
	state.resolve_topology(topology)
	_states[slot] = state
	_dense_index_by_slot[slot] = _active_slots.size()
	_active_slots.append(slot)
	snapshot_changed.emit()
	return handle


func release(handle: int) -> bool:
	var slot := _slot_for(handle)
	if slot < 0:
		return false
	beam_finished.emit(handle)
	_release_slot(slot)
	snapshot_changed.emit()
	return true


func resolve(handle: int) -> TreatmentBeamState:
	var slot := _slot_for(handle)
	return _states[slot] if slot >= 0 else null


func active_handles(output: PackedInt64Array = PackedInt64Array()) -> PackedInt64Array:
	output.clear()
	for slot in _active_slots:
		output.append(EntityHandle.make(slot, _generations[slot]))
	return output


func active_count() -> int:
	return _active_slots.size()


func available_count() -> int:
	return _free_slots.size()


func snapshots(topology: ArenaTopology = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _active_slots:
		var state := _states[slot]
		if state != null:
			result.append(state.snapshot(topology))
	return result


func step_fixed(delta: float, query: CombatQuery) -> void:
	if delta <= 0.0 or query == null or _active_slots.is_empty():
		return
	var changed := false
	# A stable handle snapshot makes signal callbacks re-entrant: a listener may
	# release a beam or spawn another one without skipping or double-stepping it.
	var handles_at_start := active_handles()
	for handle in handles_at_start:
		var state := resolve(handle)
		if state == null:
			continue
		state.resolve_topology(query.topology)
		var still_active := _advance_state(state, delta, query)
		changed = true
		if not still_active and resolve(handle) == state:
			beam_finished.emit(handle)
			_release_slot(EntityHandle.slot(handle))
	if changed:
		snapshot_changed.emit()


func clear() -> void:
	if _active_slots.is_empty():
		return
	while not _active_slots.is_empty():
		var slot := int(_active_slots[-1])
		beam_finished.emit(EntityHandle.make(slot, _generations[slot]))
		_release_slot(slot)
	snapshot_changed.emit()


func _advance_state(state: TreatmentBeamState, delta: float, query: CombatQuery) -> bool:
	var unconsumed := maxf(delta, 0.0)
	while true:
		var phase_remaining := maxf(0.0, state.duration - state.phase_elapsed)
		var advance := minf(unconsumed, phase_remaining)
		var end_elapsed := state.phase_elapsed + advance
		# Tick instants form a half-open phase [0, duration). This gives a 0.5 s
		# phase exact ticks at 0.00 and 0.25 without double-hitting at its end.
		while state.next_tick_at < state.duration - TIME_EPSILON and state.next_tick_at <= end_elapsed + TIME_EPSILON:
			_resolve_tick(state, query)
			state.next_tick_at += state.tick_interval
		state.phase_elapsed = end_elapsed
		unconsumed = maxf(0.0, unconsumed - advance)
		if state.phase_elapsed < state.duration - TIME_EPSILON:
			return true
		if state.begin_return():
			# Even if the fixed tick ends exactly at the turn, the new return phase
			# starts at t=0 and therefore resolves its first tick immediately.
			continue
		return false
	return false


func _resolve_tick(state: TreatmentBeamState, query: CombatQuery) -> void:
	var topology := query.topology
	var handles := query.line(
		state.phase_origin(topology),
		state.phase_direction(),
		state.length,
		state.width * 0.5
	)
	handles.sort()
	tick_resolved.emit(state.handle, handles, state.is_return)


func _release_slot(slot: int) -> void:
	var dense_index := int(_dense_index_by_slot[slot])
	var last_slot := int(_active_slots[-1])
	_active_slots[dense_index] = last_slot
	_dense_index_by_slot[last_slot] = dense_index
	_active_slots.resize(_active_slots.size() - 1)
	_dense_index_by_slot[slot] = -1
	_states[slot] = null
	_generations[slot] = EntityHandle.next_generation(_generations[slot])
	_free_slots.append(slot)


func _slot_for(handle: int) -> int:
	if not EntityHandle.is_valid(handle):
		return -1
	var slot := EntityHandle.slot(handle)
	if slot < 0 or slot >= capacity or _dense_index_by_slot[slot] < 0:
		return -1
	return slot if _generations[slot] == EntityHandle.generation(handle) else -1
