class_name ProjectileRenderer
extends Node2D

## Stable, generation-bound visual owner for every gameplay projectile.
##
## TherapyProjectile nodes contain authoritative simulation state only. Their
## CanvasItem output stays hidden for the complete activation; this renderer
## owns one fixed MultiMesh slot matching the ProjectileWorld handle slot.
## Release clears that slot synchronously before either the world slot or the
## pooled node can be reused. Fixed ticks capture snapshots and the renderer
## manually interpolates one packed buffer, avoiding unstable engine-side 2D
## MultiMesh interpolation in Godot's Compatibility renderer.

const DEFAULT_TEXTURE: Texture2D = preload("res://assets/art/visual_restart/therapy_projectile.svg")
const HOSTILE_TEXTURE: Texture2D = preload("res://assets/art/visual_restart/enemy_projectile.svg")
const INVALID_SLOT := -1
const MULTIMESH_STRIDE_2D := 8
const PROJECTILE_EXTENT := Vector2(48.0, 24.0)
const QUAD_TEXTURE_ROTATION := PI

var _capacity: int = 0
var _batch: MultiMeshInstance2D
var _render_buffer := PackedFloat32Array()
var _projectiles: Array[TherapyProjectile] = []
var _handles := PackedInt64Array()
var _active := PackedByteArray()
var _detailed := PackedByteArray()
var _dense_index_by_slot := PackedInt32Array()
var _active_slots := PackedInt32Array()
var _previous_positions := PackedVector2Array()
var _current_positions := PackedVector2Array()
var _previous_angles := PackedFloat32Array()
var _current_angles := PackedFloat32Array()
var _snap_interpolation := PackedByteArray()
var _highest_active_slot: int = -1
var _debug_snapshots_enabled: bool = false
var _debug_states: Dictionary = {}
var _texture_rotation: float = QUAD_TEXTURE_ROTATION


func configure(projectile_capacity: int, texture: Texture2D = DEFAULT_TEXTURE, texture_rotation: float = QUAD_TEXTURE_ROTATION) -> ProjectileRenderer:
	_capacity = maxi(projectile_capacity, 1)
	_texture_rotation = texture_rotation
	_projectiles.resize(_capacity)
	_projectiles.fill(null)
	_handles.resize(_capacity)
	_handles.fill(EntityHandle.INVALID)
	_active.resize(_capacity)
	_active.fill(0)
	_detailed.resize(_capacity)
	_detailed.fill(0)
	_dense_index_by_slot.resize(_capacity)
	_dense_index_by_slot.fill(-1)
	_previous_positions.resize(_capacity)
	_current_positions.resize(_capacity)
	_previous_angles.resize(_capacity)
	_current_angles.resize(_capacity)
	_snap_interpolation.resize(_capacity)
	_snap_interpolation.fill(0)
	_active_slots.clear()
	_render_buffer.resize(_capacity * MULTIMESH_STRIDE_2D)
	_render_buffer.fill(0.0)
	_batch = _create_batch(texture)
	if _batch != null:
		_batch.multimesh.set_buffer(_render_buffer)
	set_process(true)
	return self


func _process(_delta: float) -> void:
	flush_render_state()


func register_projectile(projectile: TherapyProjectile, handle: int, force_detailed: bool = false) -> bool:
	if not is_instance_valid(projectile) or not EntityHandle.is_valid(handle):
		return false
	var slot := EntityHandle.slot(handle)
	if slot < 0 or slot >= _capacity or _batch == null:
		return false
	if _active[slot] != 0:
		if _handles[slot] == handle and _projectiles[slot] == projectile:
			if _detailed[slot] != 0:
				projectile.show()
			else:
				projectile.hide()
			return true
		push_error("ProjectileRenderer: occupied slot %d cannot accept handle %d" % [slot, handle])
		return false

	_projectiles[slot] = projectile
	_handles[slot] = handle
	_active[slot] = 1
	_detailed[slot] = 1 if force_detailed else 0
	_dense_index_by_slot[slot] = _active_slots.size()
	_active_slots.append(slot)
	_previous_positions[slot] = projectile.global_position
	_current_positions[slot] = projectile.global_position
	_previous_angles[slot] = projectile.rotation
	_current_angles[slot] = projectile.rotation
	_snap_interpolation[slot] = 1
	if not force_detailed:
		_highest_active_slot = maxi(_highest_active_slot, slot)
	_batch.multimesh.visible_instance_count = _highest_active_slot + 1
	_hide_slot(slot)
	if force_detailed:
		projectile.reset_physics_interpolation()
		if projectile.visual_body != null:
			projectile.visual_body.set_notify_transform(true)
		projectile.show()
	else:
		if projectile.visual_body != null:
			projectile.visual_body.set_notify_transform(false)
		projectile.hide()
	if _debug_snapshots_enabled:
		_debug_states[handle] = _hidden_debug_state(handle, slot)
	return true


## Clears the visual immediately. A stale generation or a different pooled
## node can never release the current slot owner.
func release_projectile(projectile: TherapyProjectile, handle: int) -> bool:
	if not EntityHandle.is_valid(handle):
		return false
	var slot := EntityHandle.slot(handle)
	if not _owns(slot, projectile, handle):
		return false
	_hide_slot(slot)
	_remove_active_slot(slot)
	_projectiles[slot] = null
	_handles[slot] = EntityHandle.INVALID
	_active[slot] = 0
	_detailed[slot] = 0
	_previous_positions[slot] = Vector2.ZERO
	_current_positions[slot] = Vector2.ZERO
	_previous_angles[slot] = 0.0
	_current_angles[slot] = 0.0
	_snap_interpolation[slot] = 0
	if is_instance_valid(projectile):
		if projectile.visual_body != null:
			projectile.visual_body.set_notify_transform(false)
		projectile.hide()
	if _debug_snapshots_enabled:
		_debug_states[handle] = _hidden_debug_state(handle, slot)
	while _highest_active_slot >= 0 and (_active[_highest_active_slot] == 0 or _detailed[_highest_active_slot] != 0):
		_highest_active_slot -= 1
	if _batch != null:
		_batch.multimesh.visible_instance_count = _highest_active_slot + 1
	return true


func release_handle(handle: int) -> bool:
	if not EntityHandle.is_valid(handle):
		return false
	var slot := EntityHandle.slot(handle)
	if slot < 0 or slot >= _capacity:
		return false
	return release_projectile(_projectiles[slot], handle)


## Captures the completed fixed tick. Torus crossings collapse the previous
## position to avoid interpolation streaks across the entire arena.
func publish_snapshot() -> void:
	# Normal runtime snapshots are written by TherapyProjectile during its world
	# tick. The renderer only scans on publication when debug mirrors are active;
	# this preserves explicit-publish semantics for regression tests without a
	# redundant 512-projectile production pass.
	if not _debug_snapshots_enabled:
		return
	var dense_index := 0
	while dense_index < _active_slots.size():
		var slot := int(_active_slots[dense_index])
		var projectile := _projectiles[slot]
		if not is_instance_valid(projectile):
			release_handle(_handles[slot])
			continue
		var previous := _current_positions[slot]
		var current := projectile.global_position
		var crossed_torus := false
		if projectile.topology != null:
			var raw_delta := current - previous
			var shortest := projectile.topology.shortest_delta(previous, current)
			crossed_torus = not raw_delta.is_equal_approx(shortest)
		if crossed_torus:
			_snap_interpolation[slot] = 1
		_previous_positions[slot] = current if crossed_torus else previous
		_current_positions[slot] = current
		_previous_angles[slot] = _current_angles[slot]
		_current_angles[slot] = projectile.rotation
		if _snap_interpolation[slot] != 0:
			_previous_positions[slot] = _current_positions[slot]
			_previous_angles[slot] = _current_angles[slot]
			_snap_interpolation[slot] = 0
		dense_index += 1
	_refresh_debug_snapshots(1.0)


## Publishes the manually interpolated visual buffer. Fixed tick state remains
## authoritative and is never modified by this render callback.
func flush_render_state(interpolation_fraction: float = -1.0) -> void:
	var fraction := Engine.get_physics_interpolation_fraction() if interpolation_fraction < 0.0 else clampf(interpolation_fraction, 0.0, 1.0)
	_upload_interpolated_buffer(fraction)
	_refresh_debug_snapshots(fraction)


func _upload_interpolated_buffer(fraction: float) -> void:
	if _batch == null:
		return
	for slot_value in _active_slots:
		var slot := int(slot_value)
		if _detailed[slot] != 0:
			continue
		var position: Vector2
		var angle: float
		if _debug_snapshots_enabled:
			position = _previous_positions[slot].lerp(_current_positions[slot], fraction)
			angle = lerp_angle(_previous_angles[slot], _current_angles[slot], fraction)
		else:
			var projectile := _projectiles[slot]
			if projectile == null:
				continue
			position = projectile.visual_previous_position.lerp(projectile.visual_current_position, fraction)
			angle = lerp_angle(projectile.visual_previous_angle, projectile.visual_current_angle, fraction)
		_write_instance(_render_buffer, slot, position, angle + _texture_rotation)
	_batch.multimesh.set_buffer(_render_buffer)


func _refresh_debug_snapshots(interpolation_fraction: float) -> void:
	if not _debug_snapshots_enabled:
		return
	var fraction := clampf(interpolation_fraction, 0.0, 1.0)
	for slot_value in _active_slots:
		var slot := int(slot_value)
		var projectile := _projectiles[slot]
		if not is_instance_valid(projectile):
			continue
		if _detailed[slot] != 0:
			_debug_states[_handles[slot]] = {
				"active": true,
				"hidden": false,
				"detailed": true,
				"handle": _handles[slot],
				"slot": slot,
				"transform": projectile.global_transform,
				"color": Color.WHITE,
			}
			continue
		var render_position := _previous_positions[slot].lerp(_current_positions[slot], fraction)
		var angle := lerp_angle(_previous_angles[slot], _current_angles[slot], fraction) + QUAD_TEXTURE_ROTATION
		_debug_states[_handles[slot]] = {
			"active": true,
			"hidden": false,
			"detailed": false,
			"handle": _handles[slot],
			"slot": slot,
			"transform": Transform2D(angle, PROJECTILE_EXTENT, 0.0, render_position),
			"color": Color.WHITE,
		}


func clear() -> void:
	while not _active_slots.is_empty():
		var slot := int(_active_slots[-1])
		release_projectile(_projectiles[slot], _handles[slot])
	if _batch != null:
		_batch.multimesh.visible_instance_count = 0


func active_count() -> int:
	return _active_slots.size()


func batch() -> MultiMeshInstance2D:
	return _batch


func handle_for(projectile: TherapyProjectile) -> int:
	if not is_instance_valid(projectile):
		return EntityHandle.INVALID
	for slot in _active_slots:
		if _projectiles[slot] == projectile:
			return _handles[slot]
	return EntityHandle.INVALID


func set_debug_snapshots_enabled(enabled: bool) -> void:
	_debug_snapshots_enabled = enabled
	_debug_states.clear()


func render_state(handle: int) -> Dictionary:
	if not _debug_snapshots_enabled:
		return {}
	return (_debug_states.get(handle, {}) as Dictionary).duplicate(true)


func _owns(slot: int, projectile: TherapyProjectile, handle: int) -> bool:
	return (
		slot >= 0
		and slot < _capacity
		and _active[slot] != 0
		and _handles[slot] == handle
		and _projectiles[slot] == projectile
	)


func _remove_active_slot(slot: int) -> void:
	var dense_index := _dense_index_by_slot[slot]
	if dense_index < 0 or dense_index >= _active_slots.size():
		return
	var last_slot := int(_active_slots[-1])
	_active_slots[dense_index] = last_slot
	_dense_index_by_slot[last_slot] = dense_index
	_active_slots.resize(_active_slots.size() - 1)
	_dense_index_by_slot[slot] = -1


func _write_instance(buffer: PackedFloat32Array, slot: int, origin: Vector2, angle: float) -> void:
	var offset := slot * MULTIMESH_STRIDE_2D
	var cosine := cos(angle)
	var sine := sin(angle)
	buffer[offset] = cosine * PROJECTILE_EXTENT.x
	buffer[offset + 1] = -sine * PROJECTILE_EXTENT.y
	buffer[offset + 2] = 0.0
	buffer[offset + 3] = origin.x
	buffer[offset + 4] = sine * PROJECTILE_EXTENT.x
	buffer[offset + 5] = cosine * PROJECTILE_EXTENT.y
	buffer[offset + 6] = 0.0
	buffer[offset + 7] = origin.y


func _hide_slot(slot: int) -> void:
	if slot < 0 or slot >= _capacity or _batch == null:
		return
	var offset := slot * MULTIMESH_STRIDE_2D
	for index in range(MULTIMESH_STRIDE_2D):
		_render_buffer[offset + index] = 0.0
	# Release visibility is synchronous; ordinary updates stay bulk-only.
	_batch.multimesh.set_instance_transform_2d(slot, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))


func _hidden_debug_state(handle: int, slot: int) -> Dictionary:
	return {
		"active": false,
		"hidden": true,
		"detailed": false,
		"handle": handle,
		"slot": slot,
		"transform": Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO),
		"color": Color.TRANSPARENT,
	}


func _create_batch(texture: Texture2D) -> MultiMeshInstance2D:
	if texture == null:
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	multimesh.instance_count = _capacity
	multimesh.visible_instance_count = 0
	# Projectile slots remain coherent until their generation is released, so
	# the ordinary bulk buffer lets RenderingServer retain the previous tick and
	# interpolate it safely. Atomic teleports still reset their individual slot.
	RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)
	var instance := MultiMeshInstance2D.new()
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.name = "GameplayProjectiles"
	instance.multimesh = multimesh
	instance.texture = texture
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	instance.z_index = 6
	add_child(instance)
	# Tree insertion may reapply the global interpolation mode to the RID. Keep
	# engine-side MultiMesh interpolation off; this renderer interpolates its CPU
	# snapshots explicitly and uploads one coherent buffer per render frame.
	RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)
	return instance
