class_name FeedbackRenderer
extends Node2D

## Central lifecycle and one MultiMesh draw path for every combat burst.

signal burst_finished(burst: VisualBurst)

const DEFAULT_TEXTURE: Texture2D = preload("res://assets/vendor/kenney_particles/circle_03.png")
const STRIDE := 12
const BASE_SIZE := 13.0
const GOLDEN_ANGLE := 2.399963229728653

var _capacity: int
var _particle_capacity: int
var _batch: MultiMeshInstance2D
var _buffer := PackedFloat32Array()
var _bursts: Array[VisualBurst] = []
var _generations := PackedInt64Array()
var _dense_index_by_slot := PackedInt32Array()
var _active_slots := PackedInt32Array()
var _free_slots := PackedInt32Array()
var _last_visible_particles: int = 0


func configure(effect_capacity: int, texture: Texture2D = DEFAULT_TEXTURE) -> FeedbackRenderer:
	_capacity = maxi(effect_capacity, 1)
	_particle_capacity = _capacity * VisualBurst.MAX_PARTICLES
	_bursts.resize(_capacity)
	_bursts.fill(null)
	_generations.resize(_capacity)
	_generations.fill(0)
	_dense_index_by_slot.resize(_capacity)
	_dense_index_by_slot.fill(-1)
	_active_slots.clear()
	_free_slots.resize(_capacity)
	for index in range(_capacity):
		_free_slots[_capacity - index - 1] = index
	_buffer.resize(_particle_capacity * STRIDE)
	_buffer.fill(0.0)
	_batch = _create_batch(texture)
	set_process(true)
	return self


func _process(delta: float) -> void:
	step_and_render(delta)


func register_burst(burst: VisualBurst) -> bool:
	if burst == null or not burst.active or _free_slots.is_empty() or _batch == null:
		return false
	var slot := int(_free_slots[-1])
	_free_slots.resize(_free_slots.size() - 1)
	_bursts[slot] = burst
	_generations[slot] = burst.activation_generation
	_dense_index_by_slot[slot] = _active_slots.size()
	_active_slots.append(slot)
	return true


## Generation checks prevent a pooled shell from releasing its replacement.
func release_burst(burst: VisualBurst, generation: int = -1) -> bool:
	if burst == null:
		return false
	var expected := burst.activation_generation if generation < 0 else generation
	var slot := _slot_for(burst, expected)
	if slot < 0:
		return false
	_release_slot(slot)
	# External releases are rare (cleanup/pool ownership changes) and must remove
	# the exact dense range now. Timed expiries are collected above and still use
	# one shared upload after all releases in that frame.
	flush_render_state()
	return true


func step_and_render(delta: float) -> void:
	var dense_index := 0
	while dense_index < _active_slots.size():
		var slot := int(_active_slots[dense_index])
		var burst := _bursts[slot]
		if burst == null or not burst.active or burst.activation_generation != _generations[slot]:
			_release_slot(slot)
			continue
		burst.remaining -= maxf(delta, 0.0)
		if burst.remaining <= 0.0:
			_release_slot(slot)
			burst_finished.emit(burst)
			continue
		dense_index += 1
	flush_render_state()


## Rebuilds dense particle instances and uploads once, regardless of event count.
func flush_render_state() -> void:
	if _batch == null:
		return
	var particle_index := 0
	for slot_value in _active_slots:
		var slot := int(slot_value)
		var burst := _bursts[slot]
		if burst == null or not burst.active or burst.activation_generation != _generations[slot]:
			continue
		var progress := burst.progress()
		var generation := int(_generations[slot])
		var seed_phase := float(posmod(slot * 37 + generation * 17, 997)) * 0.013
		for local_index in range(burst.particle_count):
			var angle := float(local_index) * GOLDEN_ANGLE + seed_phase
			var variance := 0.62 + 0.38 * _unit_hash(local_index, slot, generation)
			var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
			var origin := burst.global_position + Vector2.from_angle(angle) * burst.spread_radius * variance * eased
			origin.y += burst.spread_radius * 0.12 * progress * progress
			var size_variance := 0.72 + 0.34 * _unit_hash(local_index + 19, generation, slot)
			var size := BASE_SIZE * size_variance * lerpf(1.0, 0.38, progress)
			var alpha := burst.color.a * pow(1.0 - progress, 1.35)
			_write_instance(particle_index, origin, angle, size, Color(burst.color, alpha))
			particle_index += 1
	_last_visible_particles = particle_index
	_batch.multimesh.visible_instance_count = particle_index
	if particle_index > 0:
		_batch.multimesh.set_buffer(_buffer)


func clear() -> void:
	while not _active_slots.is_empty():
		_release_slot(int(_active_slots[-1]))
	_last_visible_particles = 0
	if _batch != null:
		_batch.multimesh.visible_instance_count = 0


func active_count() -> int:
	return _active_slots.size()


func active_particle_count() -> int:
	var count := 0
	for slot_value in _active_slots:
		var burst := _bursts[int(slot_value)]
		if burst != null and burst.active:
			count += burst.particle_count
	return count


func available_count() -> int:
	return _free_slots.size()


func batch() -> MultiMeshInstance2D:
	return _batch


func owns(burst: VisualBurst, generation: int = -1) -> bool:
	if burst == null:
		return false
	var expected := burst.activation_generation if generation < 0 else generation
	return _slot_for(burst, expected) >= 0


func _slot_for(burst: VisualBurst, generation: int) -> int:
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _bursts[slot] == burst and _generations[slot] == generation:
			return slot
	return -1


func _release_slot(slot: int) -> void:
	var dense_index := _dense_index_by_slot[slot]
	if dense_index < 0 or dense_index >= _active_slots.size():
		return
	var last_slot := int(_active_slots[-1])
	_active_slots[dense_index] = last_slot
	_dense_index_by_slot[last_slot] = dense_index
	_active_slots.resize(_active_slots.size() - 1)
	_dense_index_by_slot[slot] = -1
	_bursts[slot] = null
	_generations[slot] = 0
	_free_slots.append(slot)


func _write_instance(index: int, origin: Vector2, angle: float, size: float, color: Color) -> void:
	var offset := index * STRIDE
	var cosine := cos(angle)
	var sine := sin(angle)
	_buffer[offset] = cosine * size
	_buffer[offset + 1] = -sine * size
	_buffer[offset + 2] = 0.0
	_buffer[offset + 3] = origin.x
	_buffer[offset + 4] = sine * size
	_buffer[offset + 5] = cosine * size
	_buffer[offset + 6] = 0.0
	_buffer[offset + 7] = origin.y
	_buffer[offset + 8] = color.r
	_buffer[offset + 9] = color.g
	_buffer[offset + 10] = color.b
	_buffer[offset + 11] = color.a


func _create_batch(texture: Texture2D) -> MultiMeshInstance2D:
	if texture == null:
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	multimesh.instance_count = _particle_capacity
	multimesh.visible_instance_count = 0
	# Cosmetic particles are evaluated directly for the rendered frame; engine
	# MultiMesh physics interpolation would duplicate that responsibility.
	RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)
	var instance := MultiMeshInstance2D.new()
	instance.name = "CombatFeedback"
	# Feedback evaluates its cosmetic motion in render time. Keep both the
	# CanvasItem and its MultiMesh out of the engine's fixed-step interpolation
	# path; entering the SceneTree may otherwise re-enable interpolation.
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.multimesh = multimesh
	instance.texture = texture
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	instance.z_index = 6
	add_child(instance)
	RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)
	return instance


static func _unit_hash(a: int, b: int, c: int) -> float:
	var value := posmod(a * 15731 + b * 789221 + c * 1376312589, 104729)
	return float(value) / 104728.0
