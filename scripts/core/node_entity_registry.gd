class_name NodeEntityRegistry
extends RefCounted

## Fixed-capacity, generation-safe registry for the current Node-based runtime.
## Automatic physics processing is disabled on registration; one world invokes
## all entity steps in deterministic dense-list order.

signal entity_registered(entity: Node, handle: int)
signal entity_released(entity: Node, handle: int)

var capacity: int = 1
var step_method: StringName = &"step_fixed"

var _nodes: Array[Node] = []
var _step_callables: Array[Callable] = []
var _generations: PackedInt32Array = PackedInt32Array()
var _dense_index_by_slot: PackedInt32Array = PackedInt32Array()
var _active_slots: PackedInt32Array = PackedInt32Array()
var _free_slots: PackedInt32Array = PackedInt32Array()
var _retiring: PackedByteArray = PackedByteArray()
var _pending_release: PackedInt64Array = PackedInt64Array()
var _node_handles: Dictionary = {}
var _handles_cache: PackedInt64Array = PackedInt64Array()
var _handles_cache_dirty: bool = false

func configure(maximum_entities: int, entity_step_method: StringName = &"step_fixed") -> NodeEntityRegistry:
	capacity = maxi(maximum_entities, 1)
	step_method = entity_step_method
	_nodes.resize(capacity)
	_nodes.fill(null)
	_step_callables.resize(capacity)
	for slot in range(capacity):
		_step_callables[slot] = Callable()
	_generations.resize(capacity)
	_generations.fill(1)
	_dense_index_by_slot.resize(capacity)
	_dense_index_by_slot.fill(-1)
	_retiring.resize(capacity)
	_retiring.fill(0)
	_active_slots.clear()
	_free_slots.clear()
	for slot in range(capacity - 1, -1, -1):
		_free_slots.append(slot)
	_pending_release.clear()
	_node_handles.clear()
	_handles_cache.clear()
	_handles_cache_dirty = false
	return self

func register_entity(entity: Node, disable_automatic_physics: bool = true) -> int:
	if not is_instance_valid(entity):
		return EntityHandle.INVALID
	var previous_handle := allocated_handle_for(entity)
	if previous_handle != EntityHandle.INVALID:
		# A retiring entity still owns its physical slot until flush_deferred().
		# Refuse a second lease instead of aliasing one Node into two slots.
		return previous_handle if is_active(previous_handle) else EntityHandle.INVALID
	return _register_new_entity(entity, disable_automatic_physics)

func _register_new_entity(entity: Node, disable_automatic_physics: bool = true) -> int:
	if _free_slots.is_empty():
		return EntityHandle.INVALID
	var instance_id := entity.get_instance_id()
	var slot := int(_free_slots[-1])
	_free_slots.resize(_free_slots.size() - 1)
	var handle := EntityHandle.make(slot, _generations[slot])
	_nodes[slot] = entity
	_step_callables[slot] = Callable(entity, step_method) if not step_method.is_empty() and entity.has_method(step_method) else Callable()
	_retiring[slot] = 0
	_dense_index_by_slot[slot] = _active_slots.size()
	_active_slots.append(slot)
	_node_handles[instance_id] = handle
	_handles_cache_dirty = true
	if disable_automatic_physics:
		entity.set_physics_process(false)
	entity_registered.emit(entity, handle)
	return handle

## Invalidates resolution immediately and removes the slot after the current
## fixed-step iteration (or on explicit flush_deferred()).
func release(handle: int, deferred: bool = true) -> bool:
	var slot := _slot_for_allocated_handle(handle)
	if slot < 0:
		return false
	if _retiring[slot] != 0:
		return false
	_retiring[slot] = 1
	_pending_release.append(handle)
	_handles_cache_dirty = true
	if not deferred:
		flush_deferred()
	return true

func resolve(handle: int, include_retiring: bool = false) -> Node:
	var slot := _slot_for_allocated_handle(handle)
	if slot < 0:
		return null
	if not include_retiring and _retiring[slot] != 0:
		return null
	var entity := _nodes[slot]
	return entity if is_instance_valid(entity) else null

func handle_for(entity: Node) -> int:
	if not is_instance_valid(entity):
		return EntityHandle.INVALID
	return _active_handle_for_instance(entity)

## Returns the physical lease for an entity, including a lease that has
## already been logically retired but not yet flushed. Pooling code must use
## this query: handle_for() intentionally hides retiring entities from combat.
func allocated_handle_for(entity: Node) -> int:
	if not is_instance_valid(entity):
		return EntityHandle.INVALID
	var handle := int(_node_handles.get(entity.get_instance_id(), EntityHandle.INVALID))
	return handle if _slot_for_allocated_handle(handle) >= 0 else EntityHandle.INVALID

func is_retiring(handle: int) -> bool:
	var slot := _slot_for_allocated_handle(handle)
	return slot >= 0 and _retiring[slot] != 0

func is_active(handle: int) -> bool:
	var slot := _slot_for_allocated_handle(handle)
	return slot >= 0 and _retiring[slot] == 0

func handles(output: PackedInt64Array = PackedInt64Array()) -> PackedInt64Array:
	_refresh_handles_cache()
	# Never expose the internal cache. Packed arrays can share their backing
	# storage after assignment; feeding a previously returned value back as the
	# reusable output would then clear the registry cache itself. Always copy
	# into caller-owned storage so handle visibility remains deterministic.
	output.clear()
	output.append_array(_handles_cache)
	return output

func active_count() -> int:
	_refresh_handles_cache()
	return _handles_cache.size()

func allocated_count() -> int:
	return _active_slots.size()

func available_count() -> int:
	return _free_slots.size()

func step_fixed(delta: float, _session: RunSession = null) -> void:
	if delta <= 0.0:
		flush_deferred()
		return
	var count_at_start := _active_slots.size()
	for dense_index in range(count_at_start):
		if dense_index >= _active_slots.size():
			break
		var slot := int(_active_slots[dense_index])
		if _retiring[slot] != 0:
			continue
		var entity := _nodes[slot]
		if not is_instance_valid(entity) or entity.is_queued_for_deletion():
			release(EntityHandle.make(slot, _generations[slot]))
			continue
		var step_callable := _step_callables[slot]
		if step_callable.is_valid():
			step_callable.call(delta)
	flush_deferred()

func flush_deferred() -> int:
	if _pending_release.is_empty():
		return 0
	var pending := _pending_release
	_pending_release = PackedInt64Array()
	var released := 0
	for handle in pending:
		if _release_now(handle):
			released += 1
	return released

func clear() -> void:
	var current := handles()
	for handle in current:
		release(handle)
	flush_deferred()

func _release_now(handle: int) -> bool:
	var slot := _slot_for_allocated_handle(handle)
	if slot < 0:
		return false
	var entity := _nodes[slot]
	_before_slot_released(slot, entity, handle)
	var dense_index := _dense_index_by_slot[slot]
	var last_dense_index := _active_slots.size() - 1
	var last_slot := int(_active_slots[last_dense_index])
	if dense_index != last_dense_index:
		_active_slots[dense_index] = last_slot
		_dense_index_by_slot[last_slot] = dense_index
	_active_slots.resize(last_dense_index)
	_dense_index_by_slot[slot] = -1
	_retiring[slot] = 0
	_nodes[slot] = null
	_step_callables[slot] = Callable()
	if is_instance_valid(entity):
		var instance_id := entity.get_instance_id()
		# Generation-safe even under misuse: releasing an old lease must never
		# erase a newer instance mapping.
		if int(_node_handles.get(instance_id, EntityHandle.INVALID)) == handle:
			_node_handles.erase(instance_id)
		entity.set_physics_process(false)
	_generations[slot] = EntityHandle.next_generation(_generations[slot])
	_free_slots.append(slot)
	_handles_cache_dirty = true
	entity_released.emit(entity, handle)
	return true

func _before_slot_released(_slot: int, _entity: Node, _handle: int) -> void:
	pass

func _matches_allocated_handle(handle: int) -> bool:
	return _slot_for_allocated_handle(handle) >= 0

func _slot_for_allocated_handle(handle: int) -> int:
	if handle == EntityHandle.INVALID:
		return -1
	var stored_slot := int(handle & EntityHandle.SLOT_MASK)
	if stored_slot == 0:
		return -1
	var slot := stored_slot - 1
	if slot < 0 or slot >= capacity or _dense_index_by_slot[slot] < 0:
		return -1
	if _generations[slot] != int((handle >> 32) & EntityHandle.GENERATION_MASK):
		return -1
	return slot if is_instance_valid(_nodes[slot]) else -1

func _active_handle_for_instance(entity: Node) -> int:
	var handle := allocated_handle_for(entity)
	var slot := _slot_for_allocated_handle(handle)
	return handle if slot >= 0 and _retiring[slot] == 0 else EntityHandle.INVALID

func _refresh_handles_cache() -> void:
	if not _handles_cache_dirty:
		return
	_handles_cache.clear()
	for slot in _active_slots:
		if _retiring[slot] == 0 and is_instance_valid(_nodes[slot]):
			_handles_cache.append(EntityHandle.make(slot, _generations[slot]))
	_handles_cache_dirty = false
