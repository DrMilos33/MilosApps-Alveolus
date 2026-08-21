class_name CrowdRenderer
extends Node2D

## Stable visual owner for high-volume simulation entities.
##
## Ordinary enemies and pickups remain in one render path for their complete
## activation. A generation-bound record owns one stable MultiMesh slot until
## it is synchronously released. Fixed ticks publish immutable previous/current
## snapshots. The render callback interpolates those snapshots into one packed
## upload per visual batch. This avoids Godot 4.7's unstable Compatibility-path
## MultiMeshInstance2D physics interpolation while keeping motion render-smooth.

const UNIT_QUAD_SIZE := 1.0
const BATCH_TEXTURE_ROTATION := PI
const PICKUP_BASE_EXTENT := 28.0
const INVALID_SLOT := -1
const MULTIMESH_STRIDE_2D := 8
const MULTIMESH_STRIDE_2D_COLOR := 12
const STUN_ICON_TEXTURE := preload("res://assets/vendor/kenney_game_icons/star.png")


class EnemyRecord:
	extends RefCounted
	var instance_id: int
	var enemy: InfectionEnemy
	var generation: int
	var visual_id: StringName
	var batch: EnemyBatchState
	var slot: int = -1
	var detailed: bool = false
	var active_index: int = -1
	var telegraph_index: int = -1
	var health_bar_index: int = -1
	var stun_index: int = -1
	var health_callback: Callable
	var stun_callback: Callable
	var materialized_callback: Callable
	var previous_position: Vector2
	var current_position: Vector2
	var previous_size: Vector2
	var current_size: Vector2
	var previous_color: Color = Color.TRANSPARENT
	var current_color: Color = Color.TRANSPARENT
	var snap_interpolation: bool = true

	func public_snapshot() -> Dictionary:
		return {
			"enemy": enemy,
			"generation": generation,
			"visual_id": visual_id,
			"slot": slot,
			"detailed": detailed,
		}


class PickupRecord:
	extends RefCounted
	var instance_id: int
	var pickup: AnalysisPickup
	var slot: int = -1
	var detailed: bool = false
	var active_index: int = -1
	var previous_position: Vector2
	var current_position: Vector2
	var previous_size: Vector2
	var current_size: Vector2
	var snap_interpolation: bool = true

	func public_snapshot() -> Dictionary:
		return {
			"pickup": pickup,
			"slot": slot,
			"detailed": detailed,
			"previous_position": previous_position,
			"current_position": current_position,
		}


class EnemyBatchState:
	extends RefCounted
	var visual_id: StringName
	var node: MultiMeshInstance2D
	var render_buffer: PackedFloat32Array
	var free_slots: Array[int] = []
	var slot_owners: Dictionary = {}
	var next_slot: int = 0
	var highest_slot: int = -1


var _enemy_capacity: int = 0
var _pickup_capacity: int = 0
var _enemy_batches: Dictionary = {}
var _enemy_batch_list: Array[EnemyBatchState] = []
var _enemy_records: Dictionary = {}
var _enemy_record_list: Array[EnemyRecord] = []
var _enemy_telegraph_records: Array[EnemyRecord] = []
var _enemy_health_bar_records: Array[EnemyRecord] = []
var _enemy_stun_records: Array[EnemyRecord] = []
var _pickup_records: Dictionary = {}
var _pickup_record_list: Array[PickupRecord] = []
var _enemy_render_states: Dictionary = {}
var _pickup_render_states: Dictionary = {}
var _pickup_batch_node: MultiMeshInstance2D
var _pickup_render_buffer := PackedFloat32Array()
var _pickup_free_slots: Array[int] = []
var _pickup_slot_owners: Dictionary = {}
var _pickup_next_slot: int = 0
var _pickup_highest_slot: int = -1
var _debug_snapshots_enabled: bool = false
var _telegraph_was_visible: bool = false
var _unknown_visual_ids_reported: Dictionary = {}


func configure(enemy_capacity: int, pickup_capacity: int) -> void:
	_enemy_capacity = maxi(enemy_capacity, 1)
	_pickup_capacity = maxi(pickup_capacity, 1)
	_pickup_batch_node = _create_batch(VisualAssetCatalog.gameplay_batch_texture(&"analysis_pickup"), _pickup_capacity, 1, false)
	_pickup_render_buffer.resize(_pickup_capacity * MULTIMESH_STRIDE_2D)
	_pickup_render_buffer.fill(0.0)
	if _pickup_batch_node != null:
		_pickup_batch_node.multimesh.set_buffer(_pickup_render_buffer)
	set_process(true)


func _process(_delta: float) -> void:
	flush_render_state()
	# Telegraphs are lightweight draw commands and need render-rate redraws for
	# their pulse.
	if not _enemy_telegraph_records.is_empty():
		queue_redraw()
	if not _enemy_health_bar_records.is_empty():
		queue_redraw()
	if not _enemy_stun_records.is_empty():
		queue_redraw()


## Defensive registry reconciliation. Runtime lifecycle code should use the
## explicit register/release APIs; sync is intentionally outside the hot path.
func sync(enemies: Array[InfectionEnemy], pickups: Array[AnalysisPickup]) -> void:
	var active_enemy_ids: Dictionary = {}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var instance_id := enemy.get_instance_id()
		active_enemy_ids[instance_id] = true
		var record := _enemy_records.get(instance_id) as EnemyRecord
		if record == null or record.generation != enemy.activation_generation:
			register_enemy(enemy, enemy.requires_detailed_visual())
	var enemy_index := 0
	while enemy_index < _enemy_record_list.size():
		var record := _enemy_record_list[enemy_index]
		if not active_enemy_ids.has(record.instance_id):
			_release_enemy_record(record)
		else:
			enemy_index += 1

	var active_pickup_ids: Dictionary = {}
	for pickup in pickups:
		if not is_instance_valid(pickup):
			continue
		var instance_id := pickup.get_instance_id()
		active_pickup_ids[instance_id] = true
		if not _pickup_records.has(instance_id):
			register_pickup(pickup, pickup.guided_to_target)
	var pickup_index := 0
	while pickup_index < _pickup_record_list.size():
		var record := _pickup_record_list[pickup_index]
		if not active_pickup_ids.has(record.instance_id):
			_release_pickup_record(record)
		else:
			pickup_index += 1
	publish_snapshot()


## Captures the completed fixed simulation tick. Enemy motion is already
## captured by InfectionEnemy.step_fixed(); pickups are snapshotted here.
func publish_snapshot(_interpolation_fraction: float = -1.0) -> void:
	# Runtime entities own their previous/current visual snapshots and update
	# them inside the same deterministic world tick as their simulation. Avoid a
	# second 960-entity scan here. Debug regressions deliberately retain the
	# defensive capture path so direct test mutations only become visible after
	# an explicit publication.
	if not _debug_snapshots_enabled:
		_prune_materialized_telegraphs()
		var runtime_telegraph_visible := not _enemy_telegraph_records.is_empty()
		if runtime_telegraph_visible or _telegraph_was_visible:
			queue_redraw()
		_telegraph_was_visible = runtime_telegraph_visible
		return
	var enemy_index := 0
	while enemy_index < _enemy_record_list.size():
		var record := _enemy_record_list[enemy_index]
		var enemy := record.enemy
		if not is_instance_valid(enemy) or not enemy.is_generation_valid(record.generation):
			_release_enemy_record(record)
			continue
		if not record.detailed:
			_capture_enemy_snapshot(record, enemy)
		enemy_index += 1

	for record in _pickup_record_list:
		var pickup := record.pickup
		if not is_instance_valid(pickup):
			continue
		var previous := record.current_position
		var current := pickup.position
		var crossed_torus := false
		if pickup.topology != null:
			var raw_delta := current - previous
			var shortest := pickup.topology.shortest_delta(previous, current)
			crossed_torus = not raw_delta.is_equal_approx(shortest)
		if crossed_torus:
			record.snap_interpolation = true
		record.previous_position = current if crossed_torus else previous
		record.current_position = current
		if not record.detailed:
			_capture_pickup_visual_snapshot(record, pickup)

	_prune_materialized_telegraphs()
	var telegraph_visible := not _enemy_telegraph_records.is_empty()
	if telegraph_visible or _telegraph_was_visible:
		queue_redraw()
	_telegraph_was_visible = telegraph_visible
	_refresh_debug_snapshots(1.0)


func register_enemy(enemy: InfectionEnemy, force_detailed: bool = false) -> Dictionary:
	if not is_instance_valid(enemy) or enemy.definition == null or not enemy.activation_active:
		return {}
	var instance_id := enemy.get_instance_id()
	var existing := _enemy_records.get(instance_id) as EnemyRecord
	if existing != null:
		if existing.generation == enemy.activation_generation:
			return existing.public_snapshot()
		_release_enemy_record(existing)

	enemy.set_detailed_visual_required(force_detailed)
	var callback := Callable(self, "_on_enemy_visual_release_requested")
	if not enemy.visual_release_requested.is_connected(callback):
		enemy.visual_release_requested.connect(callback)

	var record := EnemyRecord.new()
	record.instance_id = instance_id
	record.enemy = enemy
	record.generation = enemy.activation_generation
	record.visual_id = enemy.definition.visual_id
	record.detailed = enemy.requires_detailed_visual()
	record.previous_position = enemy.global_position
	record.current_position = enemy.global_position
	var initial_enemy_visual := _enemy_visual_snapshot(enemy)
	record.previous_size = initial_enemy_visual.size
	record.current_size = initial_enemy_visual.size
	record.previous_color = initial_enemy_visual.color
	record.current_color = initial_enemy_visual.color
	record.health_callback = Callable(self, "_on_enemy_health_changed").bind(enemy, record.generation)
	if not enemy.health_changed.is_connected(record.health_callback):
		enemy.health_changed.connect(record.health_callback)
	record.stun_callback = Callable(self, "_on_enemy_stun_changed").bind(enemy, record.generation)
	if not enemy.stun_changed.is_connected(record.stun_callback):
		enemy.stun_changed.connect(record.stun_callback)
	record.materialized_callback = Callable(self, "_on_enemy_materialized").bind(record.generation)
	if not enemy.materialized.is_connected(record.materialized_callback):
		enemy.materialized.connect(record.materialized_callback)
	if enemy.is_stunned():
		_add_stun_record(record)
	if not VisualAssetCatalog.has_gameplay_visual(record.visual_id):
		record.detailed = true
		_report_unknown_enemy_visual(record.visual_id)
	if not record.detailed:
		var batch_state := _ensure_enemy_batch(record.visual_id)
		if batch_state == null:
			record.detailed = true
		else:
			record.batch = batch_state
			record.slot = _allocate_enemy_slot(batch_state, instance_id)
			if record.slot == INVALID_SLOT:
				record.detailed = true

	record.active_index = _enemy_record_list.size()
	_enemy_record_list.append(record)
	_enemy_records[instance_id] = record
	if not record.detailed and enemy.spawn_timer > 0.0:
		_add_telegraph_record(record)
	_initialize_enemy_debug_state(record)
	if record.detailed:
		enemy.reset_physics_interpolation()
		enemy.show()
	else:
		enemy.hide()
		_hide_enemy_slot(record.visual_id, record.slot)
	return record.public_snapshot()


func release_enemy(enemy: InfectionEnemy, expected_generation: int = -1) -> void:
	if not is_instance_valid(enemy):
		return
	var record := _enemy_records.get(enemy.get_instance_id()) as EnemyRecord
	if record == null:
		return
	if expected_generation >= 0 and record.generation != expected_generation:
		return
	_release_enemy_record(record)


func register_pickup(pickup: AnalysisPickup, force_detailed: bool = false) -> Dictionary:
	if not is_instance_valid(pickup):
		return {}
	var instance_id := pickup.get_instance_id()
	var existing := _pickup_records.get(instance_id) as PickupRecord
	if existing != null:
		return existing.public_snapshot()
	var record := PickupRecord.new()
	record.instance_id = instance_id
	record.pickup = pickup
	record.detailed = force_detailed or pickup.guided_to_target or _pickup_batch_node == null
	record.previous_position = pickup.position
	record.current_position = pickup.position
	var initial_pickup_size := _pickup_visual_size(pickup)
	record.previous_size = initial_pickup_size
	record.current_size = initial_pickup_size
	if not record.detailed:
		record.slot = _allocate_pickup_slot(instance_id)
		if record.slot == INVALID_SLOT:
			record.detailed = true
	record.active_index = _pickup_record_list.size()
	_pickup_record_list.append(record)
	_pickup_records[instance_id] = record
	_initialize_pickup_debug_state(record)
	if record.detailed:
		pickup.reset_physics_interpolation()
		pickup.show()
	else:
		pickup.hide()
		_hide_pickup_slot(record.slot)
	return record.public_snapshot()


func release_pickup(pickup: AnalysisPickup) -> void:
	if not is_instance_valid(pickup):
		return
	var record := _pickup_records.get(pickup.get_instance_id()) as PickupRecord
	if record != null:
		_release_pickup_record(record)


func mark_enemy_teleported(enemy: InfectionEnemy) -> void:
	if is_instance_valid(enemy):
		enemy.reset_visual_motion()


## Publishes one manually interpolated packed buffer per visual batch. Tests may
## pass an explicit fraction; runtime uses Godot's render interpolation fraction.
func flush_render_state(interpolation_fraction: float = -1.0) -> void:
	var fraction := Engine.get_physics_interpolation_fraction() if interpolation_fraction < 0.0 else clampf(interpolation_fraction, 0.0, 1.0)
	_upload_interpolated_buffers(fraction)
	_refresh_debug_snapshots(fraction)


func clear() -> void:
	while not _enemy_record_list.is_empty():
		_release_enemy_record(_enemy_record_list.back())
	while not _pickup_record_list.is_empty():
		_release_pickup_record(_pickup_record_list.back())
	for state in _enemy_batch_list:
		if state.node != null:
			state.node.multimesh.visible_instance_count = 0
	if _pickup_batch_node != null:
		_pickup_batch_node.multimesh.visible_instance_count = 0
	_enemy_telegraph_records.clear()
	_enemy_health_bar_records.clear()
	_enemy_stun_records.clear()
	_telegraph_was_visible = false
	queue_redraw()


func is_batching() -> bool:
	for record in _enemy_record_list:
		if not record.detailed:
			return true
	for record in _pickup_record_list:
		if not record.detailed:
			return true
	return false


func active_enemy_visual_count() -> int:
	return _enemy_record_list.size()


func active_pickup_visual_count() -> int:
	return _pickup_record_list.size()


func active_visual_count() -> int:
	return active_enemy_visual_count() + active_pickup_visual_count()


func enemy_slot_for(enemy: InfectionEnemy) -> int:
	if not is_instance_valid(enemy):
		return INVALID_SLOT
	var record := _enemy_records.get(enemy.get_instance_id()) as EnemyRecord
	return record.slot if record != null else INVALID_SLOT


func pickup_slot_for(pickup: AnalysisPickup) -> int:
	if not is_instance_valid(pickup):
		return INVALID_SLOT
	var record := _pickup_records.get(pickup.get_instance_id()) as PickupRecord
	return record.slot if record != null else INVALID_SLOT


func batch_for_visual_id(visual_id: StringName) -> MultiMeshInstance2D:
	var state := _enemy_batches.get(visual_id) as EnemyBatchState
	return state.node if state != null else null


func pickup_batch() -> MultiMeshInstance2D:
	return _pickup_batch_node


func active_telegraph_count() -> int:
	return _enemy_telegraph_records.size()


func active_enemy_health_bar_count() -> int:
	return _enemy_health_bar_records.size()


func enemy_health_bar_fraction(enemy: InfectionEnemy) -> float:
	if not is_instance_valid(enemy) or enemy.max_health <= 0.0:
		return 0.0
	return clampf(enemy.health / enemy.max_health, 0.0, 1.0)


func enemy_health_bar_rect(enemy: InfectionEnemy, interpolation_fraction: float = 1.0) -> Rect2:
	if not is_instance_valid(enemy) or enemy.definition == null:
		return Rect2()
	var position := to_local(enemy.visual_interpolated_position(interpolation_fraction))
	var width := maxf(24.0, enemy.definition.radius * 2.0)
	return Rect2(position + Vector2(-width * 0.5, -enemy.definition.radius - 17.0), Vector2(width, 6.0))


func set_debug_snapshots_enabled(enabled: bool) -> void:
	_debug_snapshots_enabled = enabled
	_enemy_render_states.clear()
	_pickup_render_states.clear()
	if enabled:
		for record in _enemy_record_list:
			_initialize_enemy_debug_state(record)
		for record in _pickup_record_list:
			_initialize_pickup_debug_state(record)


## CPU mirrors of the last render commands. MultiMesh getters are deferred in
## headless Godot, so regression tests enable these mirrors explicitly.
func enemy_render_state(enemy: InfectionEnemy) -> Dictionary:
	if not _debug_snapshots_enabled or not is_instance_valid(enemy):
		return {}
	return (_enemy_render_states.get(enemy.get_instance_id(), {}) as Dictionary).duplicate(true)


func pickup_render_state(pickup: AnalysisPickup) -> Dictionary:
	if not _debug_snapshots_enabled or not is_instance_valid(pickup):
		return {}
	return (_pickup_render_states.get(pickup.get_instance_id(), {}) as Dictionary).duplicate(true)


func _on_enemy_visual_release_requested(enemy: InfectionEnemy, generation: int) -> void:
	release_enemy(enemy, generation)


func _on_enemy_health_changed(
	current: float,
	maximum: float,
	enemy: InfectionEnemy,
	generation: int
) -> void:
	if not is_instance_valid(enemy):
		return
	var record := _enemy_records.get(enemy.get_instance_id()) as EnemyRecord
	if record == null or record.generation != generation:
		return
	if record.detailed or current <= 0.0 or maximum <= 0.0 or current >= maximum:
		_remove_health_bar_record(record)
	else:
		_add_health_bar_record(record)
	queue_redraw()


func _on_enemy_stun_changed(
	_stunned_enemy: InfectionEnemy,
	stunned: bool,
	enemy: InfectionEnemy,
	generation: int
) -> void:
	if not is_instance_valid(enemy):
		return
	var record := _enemy_records.get(enemy.get_instance_id()) as EnemyRecord
	if record == null or record.generation != generation:
		return
	if stunned:
		_add_stun_record(record)
	else:
		_remove_stun_record(record)
	queue_redraw()


func _on_enemy_materialized(enemy: InfectionEnemy, generation: int) -> void:
	if not is_instance_valid(enemy):
		return
	var record := _enemy_records.get(enemy.get_instance_id()) as EnemyRecord
	if record == null or record.generation != generation or not enemy.is_generation_valid(generation):
		return
	_remove_telegraph_record(record)
	if record.detailed or record.slot < 0 or record.batch == null or record.batch.node == null:
		queue_redraw()
		return
	# Materialization happens inside the fixed enemy tick. Publish this one slot
	# immediately so a pooled cluster cannot spend an extra render frame hidden
	# between its telegraph ending and the next whole-batch upload.
	record.previous_position = enemy.visual_current_position
	record.current_position = enemy.visual_current_position
	record.previous_size = enemy.visual_current_size
	record.current_size = enemy.visual_current_size
	record.previous_color = enemy.visual_current_color
	record.current_color = enemy.visual_current_color
	record.snap_interpolation = false
	_write_buffer_instance(
		record.batch.render_buffer,
		record.slot,
		record.current_size,
		record.current_position,
		record.current_color
	)
	record.batch.node.multimesh.set_buffer(record.batch.render_buffer)
	if _debug_snapshots_enabled:
		_enemy_render_states[record.instance_id] = {
			"generation": record.generation,
			"slot": record.slot,
			"visual_id": record.visual_id,
			"detailed": false,
			"active": true,
			"hidden": false,
			"transform": Transform2D(BATCH_TEXTURE_ROTATION, record.current_size, 0.0, record.current_position),
			"color": record.current_color,
		}
	queue_redraw()


func _release_enemy_record(record: EnemyRecord) -> void:
	if record == null or _enemy_records.get(record.instance_id) != record:
		return
	_remove_telegraph_record(record)
	_remove_health_bar_record(record)
	_remove_stun_record(record)
	if is_instance_valid(record.enemy) and record.health_callback.is_valid() and record.enemy.health_changed.is_connected(record.health_callback):
		record.enemy.health_changed.disconnect(record.health_callback)
	if is_instance_valid(record.enemy) and record.stun_callback.is_valid() and record.enemy.stun_changed.is_connected(record.stun_callback):
		record.enemy.stun_changed.disconnect(record.stun_callback)
	if is_instance_valid(record.enemy) and record.materialized_callback.is_valid() and record.enemy.materialized.is_connected(record.materialized_callback):
		record.enemy.materialized.disconnect(record.materialized_callback)
	if not record.detailed:
		var state := record.batch
		if state != null:
			_free_enemy_slot(state, record.slot)
	if _debug_snapshots_enabled:
		_enemy_render_states[record.instance_id] = {
			"generation": record.generation,
			"slot": record.slot,
			"visual_id": record.visual_id,
			"detailed": record.detailed,
			"active": false,
			"hidden": true,
			"transform": Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO),
			"color": Color.TRANSPARENT,
		}
	_enemy_records.erase(record.instance_id)
	_remove_enemy_active_record(record)


func _release_pickup_record(record: PickupRecord) -> void:
	if record == null or _pickup_records.get(record.instance_id) != record:
		return
	if not record.detailed:
		_free_pickup_slot(record.slot)
	if _debug_snapshots_enabled:
		_pickup_render_states[record.instance_id] = {
			"slot": record.slot,
			"detailed": record.detailed,
			"active": false,
			"hidden": true,
			"transform": Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO),
			"color": Color.TRANSPARENT,
		}
	_pickup_records.erase(record.instance_id)
	_remove_pickup_active_record(record)


func _remove_enemy_active_record(record: EnemyRecord) -> void:
	var index := record.active_index
	if index < 0 or index >= _enemy_record_list.size():
		return
	var last: EnemyRecord = _enemy_record_list.back()
	_enemy_record_list.pop_back()
	if index < _enemy_record_list.size():
		_enemy_record_list[index] = last
		last.active_index = index
	record.active_index = -1


func _remove_pickup_active_record(record: PickupRecord) -> void:
	var index := record.active_index
	if index < 0 or index >= _pickup_record_list.size():
		return
	var last: PickupRecord = _pickup_record_list.back()
	_pickup_record_list.pop_back()
	if index < _pickup_record_list.size():
		_pickup_record_list[index] = last
		last.active_index = index
	record.active_index = -1


func _add_telegraph_record(record: EnemyRecord) -> void:
	if record.telegraph_index >= 0:
		return
	record.telegraph_index = _enemy_telegraph_records.size()
	_enemy_telegraph_records.append(record)


func _remove_telegraph_record(record: EnemyRecord) -> void:
	var index := record.telegraph_index
	if index < 0 or index >= _enemy_telegraph_records.size():
		return
	var last: EnemyRecord = _enemy_telegraph_records.back()
	_enemy_telegraph_records.pop_back()
	if index < _enemy_telegraph_records.size():
		_enemy_telegraph_records[index] = last
		last.telegraph_index = index
	record.telegraph_index = -1


func _add_health_bar_record(record: EnemyRecord) -> void:
	if record == null or record.health_bar_index >= 0 or record.detailed:
		return
	record.health_bar_index = _enemy_health_bar_records.size()
	_enemy_health_bar_records.append(record)


func _remove_health_bar_record(record: EnemyRecord) -> void:
	if record == null:
		return
	var index := record.health_bar_index
	if index < 0 or index >= _enemy_health_bar_records.size():
		record.health_bar_index = -1
		return
	var last: EnemyRecord = _enemy_health_bar_records.back()
	_enemy_health_bar_records.pop_back()
	if index < _enemy_health_bar_records.size():
		_enemy_health_bar_records[index] = last
		last.health_bar_index = index
	record.health_bar_index = -1


func _add_stun_record(record: EnemyRecord) -> void:
	if record == null or record.stun_index >= 0:
		return
	record.stun_index = _enemy_stun_records.size()
	_enemy_stun_records.append(record)


func _remove_stun_record(record: EnemyRecord) -> void:
	if record == null:
		return
	var index := record.stun_index
	if index < 0 or index >= _enemy_stun_records.size():
		record.stun_index = -1
		return
	var last: EnemyRecord = _enemy_stun_records.back()
	_enemy_stun_records.pop_back()
	if index < _enemy_stun_records.size():
		_enemy_stun_records[index] = last
		last.stun_index = index
	record.stun_index = -1


func _prune_materialized_telegraphs() -> void:
	var index := 0
	while index < _enemy_telegraph_records.size():
		var record := _enemy_telegraph_records[index]
		var enemy := record.enemy
		if not is_instance_valid(enemy) or not enemy.is_generation_valid(record.generation) or enemy.spawn_timer <= 0.0:
			_remove_telegraph_record(record)
		else:
			index += 1


func _ensure_enemy_batch(visual_id: StringName) -> EnemyBatchState:
	if not VisualAssetCatalog.has_gameplay_visual(visual_id):
		_report_unknown_enemy_visual(visual_id)
		return null
	var existing := _enemy_batches.get(visual_id) as EnemyBatchState
	if existing != null:
		return existing
	var texture := VisualAssetCatalog.gameplay_batch_texture(visual_id)
	if texture == null:
		return null
	var state := EnemyBatchState.new()
	state.visual_id = visual_id
	state.node = _create_batch(texture, _enemy_capacity, 2)
	if state.node == null:
		return null
	state.render_buffer.resize(_enemy_capacity * MULTIMESH_STRIDE_2D_COLOR)
	state.render_buffer.fill(0.0)
	state.node.multimesh.set_buffer(state.render_buffer)
	_enemy_batches[visual_id] = state
	_enemy_batch_list.append(state)
	return state


func _report_unknown_enemy_visual(visual_id: StringName) -> void:
	var key := String(visual_id)
	if _unknown_visual_ids_reported.has(key):
		return
	_unknown_visual_ids_reported[key] = true
	push_warning("CrowdRenderer: unknown gameplay visual_id '%s'; using the explicit detailed fallback." % ("<empty>" if key.is_empty() else key))


func _allocate_enemy_slot(state: EnemyBatchState, instance_id: int) -> int:
	var slot := INVALID_SLOT
	if not state.free_slots.is_empty():
		slot = state.free_slots.pop_back()
	else:
		slot = state.next_slot
		if slot >= _enemy_capacity:
			return INVALID_SLOT
		state.next_slot += 1
	state.slot_owners[slot] = instance_id
	state.highest_slot = maxi(state.highest_slot, slot)
	state.node.multimesh.visible_instance_count = state.highest_slot + 1
	return slot


func _free_enemy_slot(state: EnemyBatchState, slot: int) -> void:
	if slot < 0:
		return
	_hide_enemy_slot(state.visual_id, slot)
	state.slot_owners.erase(slot)
	if not state.free_slots.has(slot):
		state.free_slots.append(slot)
	while state.highest_slot >= 0 and not state.slot_owners.has(state.highest_slot):
		state.highest_slot -= 1
	state.node.multimesh.visible_instance_count = state.highest_slot + 1


func _allocate_pickup_slot(instance_id: int) -> int:
	if _pickup_batch_node == null:
		return INVALID_SLOT
	var slot := INVALID_SLOT
	if not _pickup_free_slots.is_empty():
		slot = _pickup_free_slots.pop_back()
	else:
		slot = _pickup_next_slot
		if slot >= _pickup_capacity:
			return INVALID_SLOT
		_pickup_next_slot += 1
	_pickup_slot_owners[slot] = instance_id
	_pickup_highest_slot = maxi(_pickup_highest_slot, slot)
	_pickup_batch_node.multimesh.visible_instance_count = _pickup_highest_slot + 1
	return slot


func _free_pickup_slot(slot: int) -> void:
	if slot < 0 or _pickup_batch_node == null:
		return
	_hide_pickup_slot(slot)
	_pickup_slot_owners.erase(slot)
	if not _pickup_free_slots.has(slot):
		_pickup_free_slots.append(slot)
	while _pickup_highest_slot >= 0 and not _pickup_slot_owners.has(_pickup_highest_slot):
		_pickup_highest_slot -= 1
	_pickup_batch_node.multimesh.visible_instance_count = _pickup_highest_slot + 1


func _capture_enemy_snapshot(record: EnemyRecord, enemy: InfectionEnemy) -> void:
	var fixed_previous := enemy.visual_previous_position if enemy.visual_motion_initialized else enemy.global_position
	if not fixed_previous.is_equal_approx(record.current_position):
		record.snap_interpolation = true
	record.previous_position = fixed_previous
	record.current_position = enemy.visual_current_position if enemy.visual_motion_initialized else enemy.global_position
	record.previous_size = record.current_size
	record.previous_color = record.current_color
	var visual_scale := 1.0
	var alpha := 1.0
	if enemy.spawn_timer > 0.0:
		var progress := 1.0 - enemy.spawn_timer / InfectionEnemy.SPAWN_TOTAL_SECONDS
		visual_scale = lerpf(0.55, 1.0, clampf(progress, 0.0, 1.0))
		alpha = 0.0 if enemy.spawn_timer > InfectionEnemy.SPAWN_MATERIALIZE_SECONDS else clampf(1.0 - enemy.spawn_timer / InfectionEnemy.SPAWN_MATERIALIZE_SECONDS, 0.0, 1.0)
	var reaction := enemy.hit_reaction_amount()
	var extent := enemy.visual_extent() * visual_scale
	record.current_size = Vector2(extent * (1.0 + reaction * 0.055), extent * (1.0 - reaction * 0.035))
	record.current_color = Color.WHITE.lerp(Color(1.0, 0.39, 0.33), reaction * 0.68)
	record.current_color.a = alpha
	# Records are the authoritative fixed-tick snapshots. A spawn or torus
	# teleport collapses both endpoints atomically so interpolation can never
	# expose the previous activation's position.
	if record.snap_interpolation:
		record.previous_position = record.current_position
		record.previous_size = record.current_size
		record.previous_color = record.current_color
		record.snap_interpolation = false


func _enemy_visual_snapshot(enemy: InfectionEnemy) -> Dictionary:
	var visual_scale := 1.0
	var alpha := 1.0
	if enemy.spawn_timer > 0.0:
		var progress := 1.0 - enemy.spawn_timer / InfectionEnemy.SPAWN_TOTAL_SECONDS
		visual_scale = lerpf(0.55, 1.0, clampf(progress, 0.0, 1.0))
		alpha = 0.0 if enemy.spawn_timer > InfectionEnemy.SPAWN_MATERIALIZE_SECONDS else clampf(1.0 - enemy.spawn_timer / InfectionEnemy.SPAWN_MATERIALIZE_SECONDS, 0.0, 1.0)
	var reaction := enemy.hit_reaction_amount()
	var extent := enemy.visual_extent() * visual_scale
	var size := Vector2(extent * (1.0 + reaction * 0.055), extent * (1.0 - reaction * 0.035))
	var color := Color.WHITE.lerp(Color(1.0, 0.39, 0.33), reaction * 0.68)
	color.a = alpha
	return {"size": size, "color": color}


func _capture_pickup_visual_snapshot(record: PickupRecord, pickup: AnalysisPickup) -> void:
	record.previous_size = record.current_size
	record.current_size = _pickup_visual_size(pickup)
	if record.snap_interpolation:
		record.previous_position = record.current_position
		record.previous_size = record.current_size
		record.snap_interpolation = false


func _pickup_visual_size(pickup: AnalysisPickup) -> Vector2:
	var stack_scale := 1.0 + minf(log(maxf(float(pickup.analysis_value), 1.0)) * 0.13, 0.65)
	var pulse := 1.0 + sin(pickup.phase) * 0.06
	return Vector2.ONE * PICKUP_BASE_EXTENT * stack_scale * pulse


func _upload_interpolated_buffers(fraction: float) -> void:
	if not _debug_snapshots_enabled:
		_upload_entity_owned_buffers(fraction)
		return
	for record in _enemy_record_list:
		if record.detailed or record.slot < 0:
			continue
		var state := record.batch
		if state == null or state.node == null:
			continue
		var position := record.previous_position.lerp(record.current_position, fraction)
		var size := record.previous_size.lerp(record.current_size, fraction)
		var color := record.previous_color.lerp(record.current_color, fraction)
		_write_buffer_instance(state.render_buffer, record.slot, size, position, color)
	for state in _enemy_batch_list:
		if state.node != null:
			state.node.multimesh.set_buffer(state.render_buffer)

	if _pickup_batch_node == null:
		return
	for record in _pickup_record_list:
		if record.detailed or record.slot < 0:
			continue
		var position := record.previous_position.lerp(record.current_position, fraction)
		var size := record.previous_size.lerp(record.current_size, fraction)
		_write_buffer_transform(_pickup_render_buffer, record.slot, size, position, MULTIMESH_STRIDE_2D)
	_pickup_batch_node.multimesh.set_buffer(_pickup_render_buffer)


func _upload_entity_owned_buffers(fraction: float) -> void:
	# Registry and renderer leases are released synchronously before pooled Nodes
	# can be recycled, so every record here owns one live generation. Reading the
	# entity-owned snapshots avoids copying the same state during fixed publish.
	for record in _enemy_record_list:
		if record.detailed or record.slot < 0:
			continue
		var state := _enemy_batches.get(record.visual_id) as EnemyBatchState
		if state == null or state.node == null:
			continue
		var enemy := record.enemy
		if enemy == null:
			continue
		var position := enemy.visual_previous_position.lerp(enemy.visual_current_position, fraction)
		var size := enemy.visual_previous_size.lerp(enemy.visual_current_size, fraction)
		var color := enemy.visual_previous_color.lerp(enemy.visual_current_color, fraction)
		_write_buffer_instance(
			state.render_buffer,
			record.slot,
			size,
			position,
			color
		)
	for state in _enemy_batch_list:
		if state.node != null:
			state.node.multimesh.set_buffer(state.render_buffer)

	if _pickup_batch_node == null:
		return
	for record in _pickup_record_list:
		if record.detailed or record.slot < 0:
			continue
		var pickup := record.pickup
		if pickup == null:
			continue
		var position := pickup.visual_previous_position.lerp(pickup.visual_current_position, fraction)
		var size := pickup.visual_previous_size.lerp(pickup.visual_current_size, fraction)
		_write_buffer_transform(
			_pickup_render_buffer,
			record.slot,
			size,
			position,
			MULTIMESH_STRIDE_2D
		)
	_pickup_batch_node.multimesh.set_buffer(_pickup_render_buffer)


func _refresh_debug_snapshots(interpolation_fraction: float) -> void:
	if not _debug_snapshots_enabled:
		return
	var fraction := clampf(interpolation_fraction, 0.0, 1.0)
	for record in _enemy_record_list:
		var enemy := record.enemy
		if not is_instance_valid(enemy) or not enemy.is_generation_valid(record.generation):
			continue
		if record.detailed:
			_enemy_render_states[record.instance_id] = {
				"generation": record.generation,
				"slot": record.slot,
				"visual_id": record.visual_id,
				"detailed": true,
				"active": true,
				"hidden": false,
				"transform": enemy.global_transform,
				"color": Color.WHITE,
			}
			continue
		var position := record.previous_position.lerp(record.current_position, fraction)
		var size := record.previous_size.lerp(record.current_size, fraction)
		var color := record.previous_color.lerp(record.current_color, fraction)
		_enemy_render_states[record.instance_id] = {
			"generation": record.generation,
			"slot": record.slot,
			"visual_id": record.visual_id,
			"detailed": false,
			"active": true,
			# The slot is owned and active even while materialization alpha is 0.
			"hidden": false,
			"transform": Transform2D(BATCH_TEXTURE_ROTATION, size, 0.0, position),
			"color": color,
		}
	for record in _pickup_record_list:
		var pickup := record.pickup
		if not is_instance_valid(pickup):
			continue
		if record.detailed:
			_pickup_render_states[record.instance_id] = {
				"slot": record.slot,
				"detailed": true,
				"active": true,
				"hidden": false,
				"transform": pickup.global_transform,
				"color": Color.WHITE,
			}
			continue
		var position := record.previous_position.lerp(record.current_position, fraction)
		var size := record.previous_size.lerp(record.current_size, fraction)
		_pickup_render_states[record.instance_id] = {
			"slot": record.slot,
			"detailed": false,
			"active": true,
			"hidden": false,
			"transform": Transform2D(BATCH_TEXTURE_ROTATION, size, 0.0, position),
			"color": Color.WHITE,
		}


func _write_buffer_instance(buffer: PackedFloat32Array, slot: int, instance_size: Vector2, origin: Vector2, color: Color) -> void:
	var offset := _write_buffer_transform(buffer, slot, instance_size, origin, MULTIMESH_STRIDE_2D_COLOR)
	buffer[offset + 8] = color.r
	buffer[offset + 9] = color.g
	buffer[offset + 10] = color.b
	buffer[offset + 11] = color.a


func _write_buffer_transform(buffer: PackedFloat32Array, slot: int, instance_size: Vector2, origin: Vector2, stride: int) -> int:
	var offset := slot * stride
	# Transform2D row-major: x.x, y.x, pad, origin.x, x.y, y.y, pad, origin.y.
	# The PI rotation matches Sprite2D orientation for the QuadMesh UV layout.
	buffer[offset] = -instance_size.x
	buffer[offset + 1] = 0.0
	buffer[offset + 2] = 0.0
	buffer[offset + 3] = origin.x
	buffer[offset + 4] = 0.0
	buffer[offset + 5] = -instance_size.y
	buffer[offset + 6] = 0.0
	buffer[offset + 7] = origin.y
	return offset


func _hide_enemy_slot(visual_id: StringName, slot: int) -> void:
	var state := _enemy_batches.get(visual_id) as EnemyBatchState
	if state == null or slot < 0:
		return
	_write_hidden_buffer_slot(state.render_buffer, slot)
	# Release must be visible to RenderingServer before a pooled node can be
	# reconfigured. Resetting interpolation makes both server snapshots hidden;
	# the ordinary fixed-tick path still uses one bulk publication per batch.
	_hide_slot(state.node.multimesh, slot)


func _hide_pickup_slot(slot: int) -> void:
	if _pickup_batch_node == null or slot < 0:
		return
	_write_hidden_buffer_slot(_pickup_render_buffer, slot, MULTIMESH_STRIDE_2D)
	_hide_slot(_pickup_batch_node.multimesh, slot, false)


func _write_hidden_buffer_slot(buffer: PackedFloat32Array, slot: int, stride: int = MULTIMESH_STRIDE_2D_COLOR) -> void:
	var offset := slot * stride
	for index in range(stride):
		buffer[offset + index] = 0.0


func _hide_slot(multimesh: MultiMesh, slot: int, uses_colors: bool = true) -> void:
	multimesh.set_instance_transform_2d(slot, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
	if uses_colors:
		multimesh.set_instance_color(slot, Color.TRANSPARENT)


func _initialize_enemy_debug_state(record: EnemyRecord) -> void:
	if not _debug_snapshots_enabled:
		return
	_enemy_render_states[record.instance_id] = {
		"generation": record.generation,
		"slot": record.slot,
		"visual_id": record.visual_id,
		"detailed": record.detailed,
		"active": record.detailed,
		"hidden": not record.detailed,
		"transform": Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO),
		"color": Color.TRANSPARENT,
	}


func _initialize_pickup_debug_state(record: PickupRecord) -> void:
	if not _debug_snapshots_enabled:
		return
	_pickup_render_states[record.instance_id] = {
		"slot": record.slot,
		"detailed": record.detailed,
		"active": record.detailed,
		"hidden": not record.detailed,
		"transform": Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO),
		"color": Color.TRANSPARENT,
	}


static func enemy_instance_transform(
	enemy: InfectionEnemy,
	visual_scale: float = 1.0,
	reaction_scale: Vector2 = Vector2.ONE,
	interpolation_fraction: float = 1.0
) -> Transform2D:
	var instance_size := reaction_scale * visual_scale * enemy.visual_extent()
	return Transform2D(BATCH_TEXTURE_ROTATION, instance_size, 0.0, enemy.visual_interpolated_position(interpolation_fraction))


static func pickup_instance_transform(pickup: AnalysisPickup) -> Transform2D:
	return pickup_instance_transform_at(pickup, pickup.position)


static func pickup_instance_transform_at(pickup: AnalysisPickup, render_position: Vector2) -> Transform2D:
	var stack_scale := 1.0 + minf(log(maxf(float(pickup.analysis_value), 1.0)) * 0.13, 0.65)
	var pulse := 1.0 + sin(pickup.phase) * 0.06
	var instance_size := Vector2.ONE * PICKUP_BASE_EXTENT * stack_scale * pulse
	return Transform2D(BATCH_TEXTURE_ROTATION, instance_size, 0.0, render_position)


func _draw() -> void:
	var fraction := Engine.get_physics_interpolation_fraction()
	for record in _enemy_telegraph_records:
		var enemy := record.enemy
		if not is_instance_valid(enemy) or enemy.definition == null or enemy.spawn_timer <= 0.0:
			continue
		var position := to_local(enemy.visual_interpolated_position(fraction))
		var elapsed := InfectionEnemy.SPAWN_TOTAL_SECONDS - enemy.spawn_timer
		var pulse_progress := clampf(elapsed / InfectionEnemy.SPAWN_TELEGRAPH_SECONDS, 0.0, 1.0)
		var pulse_radius := lerpf(enemy.definition.radius * 2.1, enemy.definition.radius * 0.9, pulse_progress)
		draw_circle(position, pulse_radius, Color(enemy.definition.color, 0.06 + pulse_progress * 0.10))
		draw_arc(position, pulse_radius, 0.0, TAU, 28, Color(enemy.definition.color, 0.58 * (1.0 - pulse_progress * 0.45)), 2.0, true)
	for record in _enemy_health_bar_records:
		var enemy := record.enemy
		if not is_instance_valid(enemy) or not enemy.is_generation_valid(record.generation) or enemy.definition == null:
			continue
		var bar_rect := enemy_health_bar_rect(enemy, fraction)
		var health_fraction := enemy_health_bar_fraction(enemy)
		var alpha := clampf(enemy.visual_interpolated_color(fraction).a, 0.0, 1.0)
		# Damaged enemies need a stable status cue without scattering bright white
		# UI tiles across the arena. A dark translucent rail keeps the coral loss
		# signal readable while visually belonging to the battlefield.
		draw_rect(bar_rect, Color(AlveolusVisualTheme.PETROL_DEEP, 0.78 * alpha), true)
		var fill_rect := bar_rect
		fill_rect.size.x *= health_fraction
		draw_rect(fill_rect, Color(AlveolusVisualTheme.CORAL, 0.92 * alpha), true)
		draw_rect(bar_rect, Color(AlveolusVisualTheme.SKY_DEEP, 0.48 * alpha), false, 1.0)
	for record in _enemy_stun_records:
		var enemy := record.enemy
		if not is_instance_valid(enemy) or not enemy.is_generation_valid(record.generation) or not enemy.is_stunned() or enemy.definition == null:
			continue
		var position := to_local(enemy.visual_interpolated_position(fraction))
		var icon_size := Vector2.ONE * 10.0
		var icon_position := position + Vector2(-5.0, -enemy.definition.radius - 19.0)
		if STUN_ICON_TEXTURE != null:
			draw_texture_rect(STUN_ICON_TEXTURE, Rect2(icon_position, icon_size), false, Color(AlveolusVisualTheme.GOLD, 0.96))
		else:
			draw_circle(icon_position + icon_size * 0.5, 4.0, AlveolusVisualTheme.GOLD)


func _create_batch(texture: Texture2D, capacity: int, layer: int, uses_colors: bool = true) -> MultiMeshInstance2D:
	if texture == null:
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = uses_colors
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * UNIT_QUAD_SIZE
	multimesh.mesh = quad
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	# Slot order is stable for an entity's complete activation, so Godot's
	# coherent-buffer path can retain the previous snapshot internally. This is
	# equivalent to per-instance interpolation without the unstable 2D
	# set_buffer_interpolated path in the Compatibility renderer.
	RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)
	var batch := MultiMeshInstance2D.new()
	batch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	batch.multimesh = multimesh
	batch.texture = texture
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	batch.z_index = layer
	add_child(batch)
	# Adding a CanvasItem can propagate the project's interpolation setting back
	# to its MultiMesh RID. Reassert OFF after tree insertion; Godot 4.7.1's GL
	# Compatibility path corrupts memory when dynamic 2D MultiMeshes interpolate.
	RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)
	return batch
