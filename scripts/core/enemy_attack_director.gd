class_name EnemyAttackDirector
extends RefCounted

## Fixed-capacity, generation-safe scheduler for ranged enemy attacks.
##
## Enemies remain owned by EnemyWorld and projectiles remain owned by
## ProjectileWorld. This director stores only handles and timers, so a pooled
## enemy can never inherit an old shooting cadence or reinforcement schedule.

signal projectile_requested(source_handle: int, pattern: int, phase: float, role: int)
signal reinforcements_requested(source_handle: int, count: int)

enum Role {
	NONE,
	BOSS,
	MINOR_FOCUS,
	PHASE_ADD,
}

enum Pattern {
	NORMAL,
	DIAMOND,
	DOUBLE_TURN,
}

const PHASE_ADD_INTERVAL := 2.8
const REINFORCEMENT_INTERVAL := 20.0
const REINFORCEMENT_COUNT := 4

var _capacity: int = 0
var _resolver: Callable
var _generation := PackedInt32Array()
var _roles := PackedByteArray()
var _shot_timers := PackedFloat32Array()
var _shot_sequences := PackedInt32Array()
var _reinforcement_timers := PackedFloat32Array()
var _boss_phases := PackedByteArray()
var _projectile_enabled := PackedByteArray()
var _reinforcement_intervals := PackedFloat32Array()
var _reinforcement_counts := PackedInt32Array()
var _reinforcement_minimum_phases := PackedByteArray()
var _dense_index_by_slot := PackedInt32Array()
var _active_slots := PackedInt32Array()


func configure(capacity: int, resolver: Callable) -> EnemyAttackDirector:
	_capacity = maxi(1, capacity)
	_resolver = resolver
	_generation.resize(_capacity)
	_generation.fill(0)
	_roles.resize(_capacity)
	_roles.fill(Role.NONE)
	_shot_timers.resize(_capacity)
	_shot_timers.fill(0.0)
	_shot_sequences.resize(_capacity)
	_shot_sequences.fill(0)
	_reinforcement_timers.resize(_capacity)
	_reinforcement_timers.fill(0.0)
	_boss_phases.resize(_capacity)
	_boss_phases.fill(0)
	_projectile_enabled.resize(_capacity)
	_projectile_enabled.fill(0)
	_reinforcement_intervals.resize(_capacity)
	_reinforcement_intervals.fill(0.0)
	_reinforcement_counts.resize(_capacity)
	_reinforcement_counts.fill(0)
	_reinforcement_minimum_phases.resize(_capacity)
	_reinforcement_minimum_phases.fill(0)
	_dense_index_by_slot.resize(_capacity)
	_dense_index_by_slot.fill(-1)
	_active_slots.clear()
	return self


func register_enemy(handle: int, role: int) -> bool:
	if not EntityHandle.is_valid(handle) or role == Role.NONE:
		return false
	var slot := EntityHandle.slot(handle)
	if slot < 0 or slot >= _capacity:
		return false
	if _roles[slot] != Role.NONE:
		if _generation[slot] == EntityHandle.generation(handle) and _roles[slot] == role:
			return true
		_release_slot(slot)
	_generation[slot] = EntityHandle.generation(handle)
	_roles[slot] = role
	_shot_timers[slot] = _initial_delay(role)
	_shot_sequences[slot] = 0
	_reinforcement_timers[slot] = 0.0
	_boss_phases[slot] = 0
	_projectile_enabled[slot] = 1
	_reinforcement_intervals[slot] = REINFORCEMENT_INTERVAL if role == Role.BOSS else 0.0
	_reinforcement_counts[slot] = REINFORCEMENT_COUNT if role == Role.BOSS else 0
	_reinforcement_minimum_phases[slot] = 2 if role == Role.BOSS else 0
	_dense_index_by_slot[slot] = _active_slots.size()
	_active_slots.append(slot)
	return true


func release(handle: int) -> bool:
	if not _owns(handle):
		return false
	_release_slot(EntityHandle.slot(handle))
	return true


func set_boss_phase(handle: int, phase: int) -> bool:
	if not _owns(handle) or role_for(handle) != Role.BOSS:
		return false
	var slot := EntityHandle.slot(handle)
	var resolved_phase := clampi(phase, 0, 2)
	if resolved_phase <= int(_boss_phases[slot]):
		return true
	_boss_phases[slot] = resolved_phase
	if _boss_reinforcements_enabled(slot) and _reinforcement_timers[slot] <= 0.0:
		_reinforcement_timers[slot] = _reinforcement_intervals[slot]
	return true


func configure_boss_contract(
	handle: int,
	projectile_enabled: bool,
	reinforcement_interval: float,
	reinforcement_count: int,
	minimum_phase: int
) -> bool:
	if not _owns(handle) or role_for(handle) != Role.BOSS:
		return false
	var slot := EntityHandle.slot(handle)
	_set_projectile_enabled_for_slot(slot, projectile_enabled)
	_reinforcement_intervals[slot] = maxf(reinforcement_interval, 0.0)
	_reinforcement_counts[slot] = maxi(reinforcement_count, 0)
	_reinforcement_minimum_phases[slot] = clampi(minimum_phase, 0, 2)
	_reinforcement_timers[slot] = (
		_reinforcement_intervals[slot]
		if _boss_reinforcements_enabled(slot)
		else 0.0
	)
	return true


func set_projectile_enabled(handle: int, enabled: bool) -> bool:
	if not _owns(handle):
		return false
	_set_projectile_enabled_for_slot(EntityHandle.slot(handle), enabled)
	return true


func role_for(handle: int) -> int:
	return int(_roles[EntityHandle.slot(handle)]) if _owns(handle) else Role.NONE


func active_count() -> int:
	return _active_slots.size()


func step_fixed(delta: float, _session: RunSession = null) -> void:
	if delta <= 0.0:
		return
	var dense_index := 0
	while dense_index < _active_slots.size():
		var slot := int(_active_slots[dense_index])
		var handle := EntityHandle.make(slot, int(_generation[slot]))
		var enemy := _resolver.call(handle) as InfectionEnemy if _resolver.is_valid() else null
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			_release_slot(slot)
			continue
		if not enemy.is_targetable() or enemy.is_stunned():
			dense_index += 1
			continue
		if _projectile_enabled[slot] != 0 and not enemy.projectiles_suppressed():
			_shot_timers[slot] -= delta
			if _shot_timers[slot] <= 0.0:
				var interval := _shot_interval(enemy, int(_roles[slot]))
				_shot_timers[slot] += maxf(interval, 0.1)
				_emit_attack(handle, int(_roles[slot]), enemy)
		if _roles[slot] == Role.BOSS and _boss_reinforcements_enabled(slot):
			_reinforcement_timers[slot] -= delta
			if _reinforcement_timers[slot] <= 0.0:
				_reinforcement_timers[slot] += _reinforcement_intervals[slot]
				reinforcements_requested.emit(handle, int(_reinforcement_counts[slot]))
		dense_index += 1


func clear() -> void:
	_generation.fill(0)
	_roles.fill(Role.NONE)
	_shot_timers.fill(0.0)
	_shot_sequences.fill(0)
	_reinforcement_timers.fill(0.0)
	_boss_phases.fill(0)
	_projectile_enabled.fill(0)
	_reinforcement_intervals.fill(0.0)
	_reinforcement_counts.fill(0)
	_reinforcement_minimum_phases.fill(0)
	_dense_index_by_slot.fill(-1)
	_active_slots.clear()


func _emit_attack(handle: int, role: int, enemy: InfectionEnemy) -> void:
	var pattern := enemy.definition.projectile_pattern if enemy != null and enemy.definition != null else &""
	if role == Role.BOSS and pattern == &"diamond":
		projectile_requested.emit(handle, Pattern.DIAMOND, 0.25, role)
		projectile_requested.emit(handle, Pattern.DIAMOND, 0.75, role)
		return
	if role == Role.BOSS and pattern == &"double_turn":
		var slot := EntityHandle.slot(handle)
		var turn_side := 0.5 * float((int(_shot_sequences[slot]) + slot) & 1)
		_shot_sequences[slot] += 1
		projectile_requested.emit(handle, Pattern.DOUBLE_TURN, turn_side, role)
		return
	projectile_requested.emit(handle, Pattern.NORMAL, 0.0, role)


func _shot_interval(enemy: InfectionEnemy, role: int) -> float:
	if role == Role.PHASE_ADD:
		return PHASE_ADD_INTERVAL / maxf(enemy.projectile_attack_speed_multiplier, 0.01)
	if enemy.definition != null and enemy.definition.projectile_interval > 0.0:
		return enemy.resolved_projectile_interval()
	return PHASE_ADD_INTERVAL


func _initial_delay(role: int) -> float:
	match role:
		Role.BOSS:
			return 0.65
		Role.MINOR_FOCUS:
			return 0.9
		Role.PHASE_ADD:
			return 1.1
	return 1.0


func _boss_reinforcements_enabled(slot: int) -> bool:
	return (
		_roles[slot] == Role.BOSS
		and _reinforcement_intervals[slot] > 0.0
		and _reinforcement_counts[slot] > 0
		and _boss_phases[slot] >= _reinforcement_minimum_phases[slot]
	)


func _set_projectile_enabled_for_slot(slot: int, enabled: bool) -> void:
	var was_enabled := _projectile_enabled[slot] != 0
	_projectile_enabled[slot] = 1 if enabled else 0
	if enabled and not was_enabled:
		_shot_timers[slot] = _initial_delay(int(_roles[slot]))
	elif not enabled:
		_shot_timers[slot] = 0.0


func _owns(handle: int) -> bool:
	if not EntityHandle.is_valid(handle):
		return false
	var slot := EntityHandle.slot(handle)
	return (
		slot >= 0
		and slot < _capacity
		and _roles[slot] != Role.NONE
		and _generation[slot] == EntityHandle.generation(handle)
	)


func _release_slot(slot: int) -> void:
	var dense_index := int(_dense_index_by_slot[slot])
	if dense_index >= 0:
		var last_index := _active_slots.size() - 1
		var moved_slot := int(_active_slots[last_index])
		_active_slots[dense_index] = moved_slot
		_dense_index_by_slot[moved_slot] = dense_index
		_active_slots.resize(last_index)
	_generation[slot] = 0
	_roles[slot] = Role.NONE
	_shot_timers[slot] = 0.0
	_shot_sequences[slot] = 0
	_reinforcement_timers[slot] = 0.0
	_boss_phases[slot] = 0
	_projectile_enabled[slot] = 0
	_reinforcement_intervals[slot] = 0.0
	_reinforcement_counts[slot] = 0
	_reinforcement_minimum_phases[slot] = 0
	_dense_index_by_slot[slot] = -1
