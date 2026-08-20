class_name AbilityFeedbackWorld
extends Node2D

## Central pooled renderer for gameplay-relevant ability geometry. It owns one
## CanvasItem and no per-effect Nodes. Fixed steps own lifetime; render frames
## only redraw the current snapshots.

signal feedback_started(handle: int, source_id: StringName)
signal feedback_finished(handle: int, source_id: StringName)

const DEFAULT_CAPACITY := 80

var topology: ArenaTopology
var capacity: int = DEFAULT_CAPACITY
var quality: CosmeticBudgetController.Quality = CosmeticBudgetController.Quality.FULL
var auto_step: bool = true
var definitions: Dictionary = {}
var reduced_motion: bool = false

var _states: Array[AbilityFeedbackState] = []
var _generations := PackedInt32Array()
var _dense_index_by_slot := PackedInt32Array()
var _active_slots := PackedInt32Array()
var _free_slots := PackedInt32Array()
var _shield_anchor: Node2D
var _shield_current: float = 0.0
var _shield_maximum: float = 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func configure(
	arena_topology: ArenaTopology,
	maximum_events: int = DEFAULT_CAPACITY,
	automatically_step: bool = true,
	visual_definitions: Dictionary = {}
) -> AbilityFeedbackWorld:
	clear()
	topology = arena_topology
	capacity = maxi(maximum_events, 1)
	auto_step = automatically_step
	definitions = visual_definitions.duplicate() if not visual_definitions.is_empty() else AbilityFeedbackDefinition.catalog()
	_states.resize(capacity)
	_states.fill(null)
	_generations.resize(capacity)
	_generations.fill(1)
	_dense_index_by_slot.resize(capacity)
	_dense_index_by_slot.fill(-1)
	_active_slots.clear()
	_free_slots.clear()
	for slot in range(capacity - 1, -1, -1):
		_free_slots.append(slot)
	set_physics_process(auto_step)
	# Visual state only changes on fixed simulation ticks. Redrawing again on
	# every render frame produced identical CanvasItem commands and wasted time
	# even when no ability feedback was active.
	set_process(false)
	queue_redraw()
	return self


func _physics_process(delta: float) -> void:
	if auto_step:
		step_fixed(delta)


func spawn_from_result(result: AbilityExecutionResult) -> int:
	if result == null or not result.success:
		return EntityHandle.INVALID
	return spawn(
		result.ability_id,
		result.origin,
		result.target,
		result.direction,
		result.radius,
		result.length,
		result.width,
		result.duration,
		result.visual_points
	)


func spawn_treatment_shot(shot: TreatmentShot) -> int:
	if shot == null:
		return EntityHandle.INVALID
	var target := shot.origin + shot.direction * shot.range_value
	if shot.mode == TreatmentShot.Mode.TRACKING and is_instance_valid(shot.target):
		target = shot.target.global_position
	var direction := topology.shortest_delta(shot.origin, target).normalized() if topology != null else (target - shot.origin).normalized()
	return spawn(
		shot.source_id,
		shot.origin,
		target,
		direction,
		0.0,
		shot.range_value if shot.mode == TreatmentShot.Mode.LINE else shot.origin.distance_to(target),
		shot.hit_radius * 2.0,
		0.0
	)


func spawn_treatment_shots(shots: Array[TreatmentShot]) -> PackedInt64Array:
	var handles := PackedInt64Array()
	for shot in shots:
		var handle := spawn_treatment_shot(shot)
		if EntityHandle.is_valid(handle):
			handles.append(handle)
	return handles


func spawn(
	source_id: StringName,
	origin: Vector2,
	target: Vector2,
	direction: Vector2 = Vector2.RIGHT,
	radius: float = 0.0,
	length: float = 0.0,
	width: float = 0.0,
	duration_override: float = 0.0,
	points: PackedVector2Array = PackedVector2Array()
) -> int:
	if _free_slots.is_empty() or not definitions.has(source_id):
		return EntityHandle.INVALID
	var definition := definitions[source_id] as AbilityFeedbackDefinition
	if definition == null:
		return EntityHandle.INVALID
	var slot := int(_free_slots[-1])
	_free_slots.resize(_free_slots.size() - 1)
	var handle := EntityHandle.make(slot, _generations[slot])
	var visual_duration := duration_override if duration_override > 0.0 else definition.duration
	if definition.persistent and duration_override <= 0.0:
		visual_duration = definition.duration
	var resolved_width := width if width > 0.0 else definition.line_width
	var state := AbilityFeedbackState.new().configure(
		handle, definition, origin, target, direction, radius, length,
		resolved_width, visual_duration, points
	)
	_states[slot] = state
	_dense_index_by_slot[slot] = _active_slots.size()
	_active_slots.append(slot)
	feedback_started.emit(handle, source_id)
	queue_redraw()
	return handle


func release(handle: int) -> bool:
	var slot := _slot_for(handle)
	if slot < 0:
		return false
	var source_id := _states[slot].definition.source_id
	var dense_index := _dense_index_by_slot[slot]
	var last_slot := int(_active_slots[-1])
	_active_slots[dense_index] = last_slot
	_dense_index_by_slot[last_slot] = dense_index
	_active_slots.resize(_active_slots.size() - 1)
	_dense_index_by_slot[slot] = -1
	_states[slot] = null
	_generations[slot] = EntityHandle.next_generation(_generations[slot])
	_free_slots.append(slot)
	feedback_finished.emit(handle, source_id)
	queue_redraw()
	return true


func step_fixed(delta: float, _session: RunSession = null) -> void:
	if delta <= 0.0:
		return
	var dense_index := 0
	while dense_index < _active_slots.size():
		var slot := int(_active_slots[dense_index])
		var state := _states[slot]
		if state == null:
			release(EntityHandle.make(slot, _generations[slot]))
			continue
		state.remaining = maxf(0.0, state.remaining - delta)
		if state.remaining <= 0.0:
			release(state.handle)
			continue
		dense_index += 1
	queue_redraw()


func publish_snapshot() -> void:
	queue_redraw()


func set_quality_tier(next_quality: CosmeticBudgetController.Quality) -> void:
	quality = next_quality
	queue_redraw()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	queue_redraw()


func set_shield_anchor(anchor: Node2D) -> void:
	_shield_anchor = anchor
	queue_redraw()


func update_shield(current: float, maximum: float) -> void:
	_shield_current = maxf(current, 0.0)
	_shield_maximum = maxf(maximum, 0.0)
	queue_redraw()


func active_count() -> int:
	return _active_slots.size()


func shield_state() -> Dictionary:
	return {
		"current": _shield_current,
		"maximum": _shield_maximum,
		"visible": _shield_current > 0.0 and _shield_maximum > 0.0 and is_instance_valid(_shield_anchor),
	}


func available_count() -> int:
	return _free_slots.size()


func resolve(handle: int) -> AbilityFeedbackState:
	var slot := _slot_for(handle)
	return _states[slot] if slot >= 0 else null


func render_state(handle: int) -> Dictionary:
	var state := resolve(handle)
	if state == null:
		return {}
	return {
		"source_id": state.definition.source_id,
		"shape": state.definition.shape,
		"origin": state.origin,
		"target": state.target,
		"direction": state.direction,
		"radius": state.radius,
		"length": state.length,
		"width": state.width,
		"duration": state.duration,
		"remaining": state.remaining,
		"critical": state.definition.effect_priority == CosmeticBudgetController.EffectPriority.CRITICAL,
	}


func clear() -> void:
	while not _active_slots.is_empty():
		var slot := int(_active_slots[-1])
		release(EntityHandle.make(slot, _generations[slot]))
	_shield_current = 0.0
	_shield_maximum = 0.0
	queue_redraw()


func _draw() -> void:
	for slot in _active_slots:
		var state := _states[slot]
		if state == null or state.definition == null:
			continue
		_draw_state(state)
	_draw_shield_ring()


func _draw_shield_ring() -> void:
	if _shield_current <= 0.0 or _shield_maximum <= 0.0 or not is_instance_valid(_shield_anchor):
		return
	var fraction := clampf(_shield_current / _shield_maximum, 0.0, 1.0)
	var radius := 35.0
	for center in _wrapped_points(_shield_anchor.global_position, radius + 6.0):
		var local_center := to_local(center)
		draw_arc(local_center, radius, 0.0, TAU, 48, Color("dcebf0", 0.38), 5.0, true)
		draw_arc(local_center, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 48, Color("3777c8", 0.95), 5.0, true)
		draw_arc(local_center, radius + 5.0, 0.0, TAU, 48, Color("83b8f2", 0.34), 2.0, true)


func _draw_state(state: AbilityFeedbackState) -> void:
	var definition := state.definition
	var progress := state.progress()
	var remaining_alpha := 1.0 if definition.persistent else pow(1.0 - progress, 0.7)
	if definition.persistent and state.remaining < 0.24:
		remaining_alpha *= state.remaining / 0.24
	match definition.shape:
		AbilityFeedbackDefinition.Shape.FIELD:
			var pulse := 1.0 if reduced_motion else 0.93 + sin(progress * TAU * maxf(state.duration, 1.0) * 1.4) * 0.025
			for center in _wrapped_points(state.target, state.radius):
				var local_center := to_local(center)
				draw_circle(local_center, state.radius, Color(definition.primary_color, definition.fill_alpha * remaining_alpha), true)
				draw_arc(local_center, state.radius * pulse, 0.0, TAU, 64, Color(definition.primary_color, 0.9 * remaining_alpha), definition.line_width, true)
				if quality == CosmeticBudgetController.Quality.FULL:
					draw_arc(local_center, state.radius * 0.72, progress * TAU, progress * TAU + PI * 1.45, 40, Color(definition.secondary_color, 0.55 * remaining_alpha), maxf(2.0, definition.line_width * 0.45), true)
		AbilityFeedbackDefinition.Shape.RING:
			var ring_radius := state.radius if reduced_motion else state.radius * (1.0 - progress if definition.inward else (0.12 + 0.88 * progress))
			for center in _wrapped_points(state.target, ring_radius):
				draw_arc(to_local(center), ring_radius, 0.0, TAU, 56, Color(definition.primary_color, remaining_alpha), definition.line_width, true)
				if quality == CosmeticBudgetController.Quality.FULL:
					draw_arc(to_local(center), maxf(4.0, ring_radius - 10.0), 0.0, TAU, 48, Color(definition.secondary_color, remaining_alpha * 0.55), 2.0, true)
		AbilityFeedbackDefinition.Shape.LINE:
			_draw_line_feedback(state, remaining_alpha, true)
		AbilityFeedbackDefinition.Shape.TRACER:
			_draw_line_feedback(state, remaining_alpha, false)
		AbilityFeedbackDefinition.Shape.PULL:
			var pull_radius := state.radius if reduced_motion else state.radius * (1.0 - 0.82 * progress)
			for center in _wrapped_points(state.target, pull_radius):
				draw_arc(to_local(center), maxf(pull_radius, 3.0), 0.0, TAU, 56, Color(definition.primary_color, remaining_alpha), definition.line_width, true)
			for point in state.points:
				var delta := topology.shortest_delta(point, state.target) if topology != null else state.target - point
				var moving_start := point if reduced_motion else point + delta * progress * 0.72
				draw_line(to_local(moving_start), to_local(moving_start + delta.normalized() * minf(28.0, delta.length())), Color(definition.secondary_color, remaining_alpha * 0.82), maxf(2.0, definition.line_width * 0.55), true)


func _draw_line_feedback(state: AbilityFeedbackState, alpha: float, broad: bool) -> void:
	var definition := state.definition
	var actual_length := state.length
	if actual_length <= 0.0:
		actual_length = topology.shortest_delta(state.origin, state.target).length() if topology != null else state.origin.distance_to(state.target)
	actual_length = _visible_line_length(state.origin, state.direction, actual_length)
	var endpoint := state.origin + state.direction * actual_length
	var offsets := _line_offsets()
	for offset in offsets:
		var start := to_local(state.origin + offset)
		var finish := to_local(endpoint + offset)
		var width := maxf(definition.line_width, state.width) if broad else definition.line_width
		draw_line(start, finish, Color(definition.primary_color, alpha), width, true)
		if quality == CosmeticBudgetController.Quality.FULL:
			draw_line(start, finish, Color(definition.secondary_color, alpha * 0.62), maxf(1.5, width * 0.34), true)


func _wrapped_points(position: Vector2, extent: float) -> PackedVector2Array:
	var result := PackedVector2Array([position])
	if topology == null or topology.is_bounded() or topology.bounds.size.x <= 0.0 or topology.bounds.size.y <= 0.0:
		return result
	var x_offsets := PackedFloat32Array([0.0])
	var y_offsets := PackedFloat32Array([0.0])
	if position.x - extent < topology.bounds.position.x:
		x_offsets.append(topology.bounds.size.x)
	if position.x + extent > topology.bounds.end.x:
		x_offsets.append(-topology.bounds.size.x)
	if position.y - extent < topology.bounds.position.y:
		y_offsets.append(topology.bounds.size.y)
	if position.y + extent > topology.bounds.end.y:
		y_offsets.append(-topology.bounds.size.y)
	result.clear()
	for x in x_offsets:
		for y in y_offsets:
			result.append(position + Vector2(x, y))
	return result


func _line_offsets() -> PackedVector2Array:
	if topology == null or topology.is_bounded() or topology.bounds.size.x <= 0.0 or topology.bounds.size.y <= 0.0:
		return PackedVector2Array([Vector2.ZERO])
	var result := PackedVector2Array()
	for x in [-topology.bounds.size.x, 0.0, topology.bounds.size.x]:
		for y in [-topology.bounds.size.y, 0.0, topology.bounds.size.y]:
			result.append(Vector2(x, y))
	return result


func _visible_line_length(start: Vector2, direction: Vector2, requested_length: float) -> float:
	return topology.limit_ray_length(start, direction, requested_length) if topology != null else maxf(requested_length, 0.0)


func _slot_for(handle: int) -> int:
	if not EntityHandle.is_valid(handle):
		return -1
	var slot := EntityHandle.slot(handle)
	if slot < 0 or slot >= capacity or _dense_index_by_slot[slot] < 0:
		return -1
	return slot if _generations[slot] == EntityHandle.generation(handle) else -1
