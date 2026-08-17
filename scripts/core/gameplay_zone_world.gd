class_name GameplayZoneWorld
extends RefCounted

## Fixed-capacity owner for persistent gameplay areas. It uses generation-safe
## handles and CombatQuery results, so an expired field cannot modify a pooled
## enemy that later reuses the same slot.

signal zone_spawned(handle: int, zone: GameplayZoneState)
signal zone_released(handle: int, effect_id: StringName)

const DEFAULT_CAPACITY := 32
const PROTECTIVE_STATUS := &"active_protective_field"

var topology: ArenaTopology
var combat_query: CombatQuery
var capacity: int = DEFAULT_CAPACITY

var _zones: Array[GameplayZoneState] = []
var _generations := PackedInt32Array()
var _dense_index_by_slot := PackedInt32Array()
var _active_slots := PackedInt32Array()
var _free_slots := PackedInt32Array()
var _protected: Dictionary = {}


func configure(
	arena_topology: ArenaTopology,
	enemy_query: CombatQuery = null,
	maximum_zones: int = DEFAULT_CAPACITY
) -> GameplayZoneWorld:
	clear()
	topology = arena_topology
	combat_query = enemy_query
	capacity = maxi(maximum_zones, 1)
	_zones.resize(capacity)
	_zones.fill(null)
	_generations.resize(capacity)
	_generations.fill(1)
	_dense_index_by_slot.resize(capacity)
	_dense_index_by_slot.fill(-1)
	_active_slots.clear()
	_free_slots.clear()
	for slot in range(capacity - 1, -1, -1):
		_free_slots.append(slot)
	return self


func set_combat_query(enemy_query: CombatQuery) -> void:
	_clear_protected_statuses()
	combat_query = enemy_query


func spawn(
	effect_id: StringName,
	center: Vector2,
	radius: float,
	duration: float,
	parameters: Dictionary = {},
	tags: PackedStringArray = PackedStringArray()
) -> int:
	if effect_id.is_empty() or topology == null or duration <= 0.0 or _free_slots.is_empty():
		return EntityHandle.INVALID
	var slot := int(_free_slots[-1])
	_free_slots.resize(_free_slots.size() - 1)
	var handle := EntityHandle.make(slot, _generations[slot])
	var zone := GameplayZoneState.new().configure(
		handle,
		effect_id,
		topology.wrap_position(center),
		radius,
		duration,
		parameters,
		tags
	)
	_zones[slot] = zone
	_dense_index_by_slot[slot] = _active_slots.size()
	_active_slots.append(slot)
	zone_spawned.emit(handle, zone)
	return handle


func release(handle: int) -> bool:
	var slot := _slot_for(handle)
	if slot < 0:
		return false
	var zone := _zones[slot]
	var effect_id := zone.effect_id if zone != null else &""
	var dense_index := _dense_index_by_slot[slot]
	var last_slot := int(_active_slots[-1])
	_active_slots[dense_index] = last_slot
	_dense_index_by_slot[last_slot] = dense_index
	_active_slots.resize(_active_slots.size() - 1)
	_dense_index_by_slot[slot] = -1
	_zones[slot] = null
	_generations[slot] = EntityHandle.next_generation(_generations[slot])
	_free_slots.append(slot)
	zone_released.emit(handle, effect_id)
	if effect_id == &"protective_field":
		_sync_protective_statuses()
	return true


func resolve(handle: int) -> GameplayZoneState:
	var slot := _slot_for(handle)
	return _zones[slot] if slot >= 0 else null


func active_handles(output: PackedInt64Array = PackedInt64Array()) -> PackedInt64Array:
	output.clear()
	for slot in _active_slots:
		output.append(EntityHandle.make(slot, _generations[slot]))
	return output


func active_count() -> int:
	return _active_slots.size()


func available_count() -> int:
	return _free_slots.size()


func has_effect(effect_id: StringName) -> bool:
	for slot in _active_slots:
		var zone := _zones[slot]
		if zone != null and zone.effect_id == effect_id:
			return true
	return false


func step_fixed(delta: float, _session: RunSession = null) -> void:
	if delta <= 0.0:
		return
	var dense_index := 0
	while dense_index < _active_slots.size():
		var slot := int(_active_slots[dense_index])
		var zone := _zones[slot]
		if zone == null:
			release(EntityHandle.make(slot, _generations[slot]))
			continue
		zone.remaining = maxf(0.0, zone.remaining - delta)
		if zone.remaining <= 0.0:
			release(zone.handle)
			continue
		dense_index += 1
	_sync_protective_statuses()


func focus_priority_bonus(position: Vector2) -> float:
	for slot in _active_slots:
		var zone := _zones[slot]
		if zone != null and zone.effect_id == &"focus_field" and zone.contains(position, topology):
			return 1000000000.0
	return 0.0


func focus_damage_multiplier(position: Vector2) -> float:
	var multiplier := 1.0
	for slot in _active_slots:
		var zone := _zones[slot]
		if zone != null and zone.effect_id == &"focus_field" and zone.contains(position, topology):
			multiplier = maxf(multiplier, float(zone.parameters.get("damage_multiplier", 1.25)))
	return multiplier


func zones_for_effect(effect_id: StringName) -> Array[GameplayZoneState]:
	var result: Array[GameplayZoneState] = []
	for slot in _active_slots:
		var zone := _zones[slot]
		if zone != null and zone.effect_id == effect_id:
			result.append(zone)
	return result


func clear() -> void:
	_clear_protected_statuses()
	while not _active_slots.is_empty():
		var slot := int(_active_slots[-1])
		release(EntityHandle.make(slot, _generations[slot]))


func _sync_protective_statuses() -> void:
	if combat_query == null:
		return
	var current: Dictionary = {}
	for slot in _active_slots:
		var zone := _zones[slot]
		if zone == null or zone.effect_id != &"protective_field":
			continue
		for handle in combat_query.circle(zone.center, zone.radius):
			var movement := float(zone.parameters.get("speed_multiplier", 0.65))
			var contact := float(zone.parameters.get("contact_multiplier", 0.65))
			if current.has(handle):
				var previous: Vector2 = current[handle]
				movement = minf(movement, previous.x)
				contact = minf(contact, previous.y)
			current[handle] = Vector2(movement, contact)
	for old_handle in _protected:
		if current.has(old_handle):
			continue
		var old_enemy: Variant = combat_query.resolve(int(old_handle))
		if is_instance_valid(old_enemy) and old_enemy.has_method("clear_status_modifier"):
			old_enemy.clear_status_modifier(PROTECTIVE_STATUS)
	for handle in current:
		var enemy: Variant = combat_query.resolve(int(handle))
		if not is_instance_valid(enemy) or not enemy.has_method("set_status_modifier"):
			continue
		var modifiers: Vector2 = current[handle]
		enemy.set_status_modifier(PROTECTIVE_STATUS, modifiers.x, modifiers.y)
	_protected = current


func _clear_protected_statuses() -> void:
	if combat_query != null:
		for handle in _protected:
			var enemy: Variant = combat_query.resolve(int(handle))
			if is_instance_valid(enemy) and enemy.has_method("clear_status_modifier"):
				enemy.clear_status_modifier(PROTECTIVE_STATUS)
	_protected.clear()


func _slot_for(handle: int) -> int:
	if not EntityHandle.is_valid(handle):
		return -1
	var slot := EntityHandle.slot(handle)
	if slot < 0 or slot >= capacity or _dense_index_by_slot[slot] < 0:
		return -1
	return slot if _generations[slot] == EntityHandle.generation(handle) else -1
