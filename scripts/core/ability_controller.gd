class_name AbilityController
extends Node

signal ability_used(slot: int, ability_id: StringName, target: Vector2)
signal ability_failed(slot: int, reason: String)
signal command_queued(command: AbilityCommand)
signal execution_completed(result: AbilityExecutionResult)
signal feedback_requested(result: AbilityExecutionResult)
signal cooldown_changed(slot: int, remaining: float, total: float)
signal effect_spawned(effect_id: StringName, center: Vector2, radius: float, duration: float)
signal shield_changed(current: float, maximum: float)
signal finding_progress_requested(amount: float)

const SLOT_Q := 0
const SLOT_E := 1
const MAX_QUEUED_COMMANDS := 16
const PROTECTIVE_STATUS := &"active_protective_field"
const SUPPORTED_EFFECTS: Array[StringName] = [
	&"focus_field",
	&"emergency_support",
	&"defense_burst",
	&"treatment_line",
	&"protective_field",
	&"sample_pull",
]

var build: RunBuildState
var topology: ArenaTopology
var avatar: Node2D
var enemies_provider: Callable
var pickups_provider: Callable
var run_state: Object
var slots: Dictionary = {}
var combat_query: CombatQuery
var pickup_query: CombatQuery
var zone_world := GameplayZoneWorld.new()
## Read-only compatibility views for telemetry written before GameplayZoneWorld.
## New gameplay code must use [member zone_world] and generation-safe handles.
var zones: Array[AbilityEffectZone] = []
var shield: float = 0.0
var shield_maximum: float = 0.0
var _protective_status_active: bool = false
var _command_queue: Array[AbilityCommand] = []
var _queued_sequences: Dictionary = {}
var _next_command_sequence: int = 1
var _last_dequeued_sequence: int = 0

func configure(
	build_state: RunBuildState,
	arena_topology: ArenaTopology,
	avatar_node: Node2D,
	provide_enemies: Callable,
	provide_pickups: Callable = Callable(),
	state: Object = null
) -> void:
	clear()
	build = build_state
	topology = arena_topology
	avatar = avatar_node
	enemies_provider = provide_enemies
	pickups_provider = provide_pickups
	run_state = state
	combat_query = null
	pickup_query = null
	zone_world.configure(topology)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure_queries(enemy_query: CombatQuery, floor_pickup_query: CombatQuery = null) -> void:
	combat_query = enemy_query
	pickup_query = floor_pickup_query
	zone_world.set_combat_query(combat_query)

func equip(slot: int, definition: AbilityDefinition) -> bool:
	if slot not in [SLOT_Q, SLOT_E] or definition == null:
		return false
	var runtime := AbilityRuntime.new(definition)
	runtime.cooldown_changed.connect(func(remaining: float, total: float) -> void:
		cooldown_changed.emit(slot, remaining, total)
	)
	slots[slot] = runtime
	cooldown_changed.emit(slot, 0.0, definition.cooldown)
	return true

func unequip(slot: int) -> void:
	slots.erase(slot)

func runtime(slot: int) -> AbilityRuntime:
	return slots.get(slot) as AbilityRuntime

func ability_state(slot: int) -> Dictionary:
	var current := runtime(slot)
	return current.state() if current != null else {"id": &"", "ready": false, "remaining": 0.0, "total": 0.0}

func use_slot(slot: int, requested_target: Vector2) -> bool:
	var command := AbilityCommand.create(slot, requested_target, _claim_sequence())
	return execute_command(command).success

## Queues a command without mutating gameplay state. RunSession should drain
## this queue in its COMBAT phase after CombatQuery has published the tick's
## spatial index.
func enqueue_command(command: AbilityCommand) -> bool:
	if command == null or not command.is_valid():
		return false
	if _command_queue.size() >= MAX_QUEUED_COMMANDS:
		return false
	if command.sequence <= 0:
		command.sequence = _claim_sequence()
	else:
		_next_command_sequence = maxi(_next_command_sequence, command.sequence + 1)
	if command.sequence <= _last_dequeued_sequence or _queued_sequences.has(command.sequence):
		return false
	_queued_sequences[command.sequence] = true
	_command_queue.append(command.duplicate_command())
	_command_queue.sort_custom(func(left: AbilityCommand, right: AbilityCommand) -> bool:
		if left.sequence != right.sequence:
			return left.sequence < right.sequence
		if left.issued_tick != right.issued_tick:
			return left.issued_tick < right.issued_tick
		return left.slot < right.slot
	)
	command_queued.emit(command)
	return true

func queue_slot(
	slot: int,
	requested_target: Vector2,
	device: AbilityCommand.InputDevice = AbilityCommand.InputDevice.UNKNOWN,
	issued_tick: int = 0
) -> AbilityCommand:
	var command := AbilityCommand.create(slot, requested_target, _claim_sequence(), device, issued_tick)
	return command if enqueue_command(command) else null

func queued_command_count() -> int:
	return _command_queue.size()

func process_command_queue(maximum_commands: int = -1) -> Array[AbilityExecutionResult]:
	var results: Array[AbilityExecutionResult] = []
	var count := _command_queue.size() if maximum_commands < 0 else mini(maximum_commands, _command_queue.size())
	for _index in range(count):
		var command: AbilityCommand = _command_queue.pop_front()
		_queued_sequences.erase(command.sequence)
		_last_dequeued_sequence = maxi(_last_dequeued_sequence, command.sequence)
		results.append(execute_command(command))
	return results

func execute_command(command: AbilityCommand) -> AbilityExecutionResult:
	if command == null or not command.is_valid():
		return _complete_failure(command, AbilityExecutionResult.Code.INVALID_COMMAND, "Ungültige Fähigkeitseingabe.")
	var current := runtime(command.slot)
	if current == null:
		return _complete_failure(command, AbilityExecutionResult.Code.EMPTY_SLOT, "Kein Eingriff vorbereitet.")
	if not current.is_ready():
		return _complete_failure(command, AbilityExecutionResult.Code.COOLDOWN, "Der Eingriff ist noch nicht bereit.", current.definition)
	if build == null or topology == null or not is_instance_valid(avatar):
		return _complete_failure(command, AbilityExecutionResult.Code.NOT_CONFIGURED, "Der Eingriff ist nicht vollständig konfiguriert.", current.definition)
	var definition := current.definition
	if definition == null or definition.effect_id not in SUPPORTED_EFFECTS:
		return _complete_failure(command, AbilityExecutionResult.Code.UNKNOWN_HANDLER, "Für diesen Eingriff fehlt die Ausführung.", definition)
	var target := avatar.global_position if definition.target_mode == AbilityDefinition.TargetMode.SELF else topology.wrap_position(command.requested_target)
	var result := _execute_effect(command, definition, target)
	if not result.success:
		return _complete_result(result)
	var cooldown_multiplier := maxf(0.1, build.value(RunBuildState.ACTIVE_COOLDOWN, 1.0, definition.tags))
	current.start_cooldown(cooldown_multiplier)
	ability_used.emit(command.slot, definition.id, target)
	return _complete_result(result)

func _physics_process(delta: float) -> void:
	step_fixed(delta)

func step(delta: float) -> void:
	step_fixed(delta)

func step_fixed(delta: float, _session: RunSession = null) -> void:
	for slot in slots:
		(runtime(int(slot))).tick(delta)
	zone_world.step_fixed(delta)
	_sync_compatibility_zones()
	_update_legacy_protective_statuses()
	process_command_queue()

func treatment_target_priority_bonus(position: Vector2) -> float:
	return zone_world.focus_priority_bonus(position)

func treatment_damage_multiplier(position: Vector2) -> float:
	return zone_world.focus_damage_multiplier(position)

## Called by the contact-pressure integration before RunState is damaged.
## Returns the unabsorbed amount; shield feedback stays fully encapsulated.
func absorb_pressure(amount: float) -> float:
	var incoming := maxf(amount, 0.0)
	if shield <= 0.0:
		return incoming
	var absorbed := minf(incoming, shield)
	shield -= absorbed
	shield_changed.emit(shield, shield_maximum)
	return incoming - absorbed

func grant_shield(amount: float, replace_maximum: bool = false) -> void:
	var granted := maxf(amount, 0.0)
	if replace_maximum:
		shield_maximum = granted
	else:
		shield_maximum = maxf(shield_maximum, granted)
	shield = minf(shield_maximum, shield + granted)
	shield_changed.emit(shield, shield_maximum)

## Adds shield in small increments while reserving a stable upper limit. This
## differs from grant_shield(), whose amount also defines the source capacity.
## Regeneration uses this path so several small overheal pulses can really build
## the Reservepuffer up to its advertised cap.
func grant_shield_capped(amount: float, capacity: float) -> void:
	var cap := maxf(capacity, 0.0)
	var granted := maxf(amount, 0.0)
	if cap <= 0.0 or granted <= 0.0:
		return
	shield_maximum = maxf(shield_maximum, cap)
	shield = minf(shield_maximum, shield + granted)
	shield_changed.emit(shield, shield_maximum)

func reduce_other_cooldown(used_slot: int, seconds: float) -> void:
	for slot in slots:
		if int(slot) != used_slot:
			(runtime(int(slot))).reduce(seconds)

func halve_all_cooldowns() -> void:
	for slot in slots:
		(runtime(int(slot))).scale_remaining(0.5)

func reset_all_cooldowns() -> void:
	for slot in slots:
		(runtime(int(slot))).reset()

func clear() -> void:
	_clear_legacy_protective_statuses()
	zone_world.clear()
	zones.clear()
	slots.clear()
	_command_queue.clear()
	_queued_sequences.clear()
	_next_command_sequence = 1
	_last_dequeued_sequence = 0
	shield = 0.0
	shield_maximum = 0.0
	_protective_status_active = false

func _execute_effect(command: AbilityCommand, definition: AbilityDefinition, target: Vector2) -> AbilityExecutionResult:
	var result := AbilityExecutionResult.succeeded(command, definition)
	result.origin = avatar.global_position
	result.target = target
	var values := definition.parameters
	match definition.effect_id:
		&"focus_field":
			var focus_zone := _spawn_zone(definition.effect_id, target, values, definition.tags)
			if not EntityHandle.is_valid(focus_zone):
				return AbilityExecutionResult.failed(command, AbilityExecutionResult.Code.CAPACITY_REACHED, "Es sind bereits zu viele Felder aktiv.", definition)
			var focus_state := zone_world.resolve(focus_zone)
			result.zone_handle = focus_zone
			result.radius = focus_state.radius
			result.duration = focus_state.total_duration
			result.values = focus_state.parameters.duplicate(true)
		&"emergency_support":
			var recovery := build.value(RunBuildState.ABILITY_RECOVERY, float(values.get("recovery", 14.0)), definition.tags)
			recovery *= build.value(RunBuildState.SUPPORT_EFFECT, 1.0, definition.tags)
			if run_state != null and run_state.has_method("change_stability"):
				run_state.change_stability(recovery)
			var shield_amount := build.value(RunBuildState.ABILITY_SHIELD, float(values.get("shield", 8.0)), definition.tags)
			grant_shield(shield_amount)
			result.radius = 92.0
			result.duration = 0.48
			result.values = {"recovery": recovery, "shield": shield_amount}
		&"defense_burst":
			var burst_radius := build.value(RunBuildState.ABILITY_RADIUS, float(values.get("radius", 150.0)), definition.tags)
			var burst_damage := build.value(RunBuildState.ABILITY_DAMAGE, float(values.get("damage", 42.0)), definition.tags)
			var knockback := build.value(RunBuildState.ABILITY_KNOCKBACK, float(values.get("knockback", 75.0)), definition.tags)
			result.affected_handles = _damage_circle(target, burst_radius, burst_damage, definition.id, knockback, definition.damage_profile)
			result.radius = burst_radius
			result.duration = 0.34
			result.values = {"damage": burst_damage, "knockback": knockback}
		&"treatment_line":
			var line_result := _damage_line(target, values, definition.id, definition.damage_profile)
			result.direction = line_result.direction
			result.length = line_result.length
			result.width = line_result.width
			result.duration = 0.22
			result.affected_handles = line_result.handles
			result.values = {"damage": line_result.damage}
		&"protective_field":
			var protection_zone := _spawn_zone(definition.effect_id, target, values, definition.tags)
			if not EntityHandle.is_valid(protection_zone):
				return AbilityExecutionResult.failed(command, AbilityExecutionResult.Code.CAPACITY_REACHED, "Es sind bereits zu viele Felder aktiv.", definition)
			var protection_state := zone_world.resolve(protection_zone)
			result.zone_handle = protection_zone
			result.radius = protection_state.radius
			result.duration = protection_state.total_duration
			result.values = protection_state.parameters.duplicate(true)
		&"sample_pull":
			var pull_radius := build.value(RunBuildState.ABILITY_RADIUS, float(values.get("radius", 230.0)), definition.tags)
			var pull_result := _pull_samples(target, pull_radius)
			var finding_multiplier := build.value(RunBuildState.FINDING_PROGRESS, 1.0, definition.tags)
			var finding_progress := float(values.get("finding_progress", 6.0)) * finding_multiplier
			finding_progress_requested.emit(finding_progress)
			result.radius = pull_radius
			result.duration = 0.52
			result.affected_handles = pull_result.handles
			result.visual_points = pull_result.points
			result.values = {"finding_progress": finding_progress}
	return result

func _spawn_zone(effect_id: StringName, center: Vector2, values: Dictionary, tags: PackedStringArray) -> int:
	var radius := build.value(RunBuildState.ABILITY_RADIUS, float(values.get("radius", 160.0)), tags)
	var duration := build.value(RunBuildState.ABILITY_DURATION, float(values.get("duration", 6.0)), tags)
	var resolved_values := values.duplicate(true)
	if effect_id == &"focus_field":
		resolved_values["damage_multiplier"] = build.value(
			RunBuildState.MARKED_DAMAGE,
			float(values.get("damage_multiplier", 1.25)),
			PackedStringArray(["focus", "marked"])
		)
	elif effect_id == &"protective_field":
		resolved_values["speed_multiplier"] = build.value(RunBuildState.ABILITY_ENEMY_SPEED, float(values.get("speed_multiplier", 0.65)), tags)
		resolved_values["contact_multiplier"] = build.value(RunBuildState.ABILITY_CONTACT, float(values.get("contact_multiplier", 0.65)), tags)
	var handle := zone_world.spawn(effect_id, center, radius, duration, resolved_values, tags)
	if EntityHandle.is_valid(handle):
		zones.append(AbilityEffectZone.create(handle, effect_id, topology.wrap_position(center), radius, duration, resolved_values))
	return handle

func _damage_circle(
	center: Vector2,
	radius: float,
	amount: float,
	source: StringName,
	knockback: float = 0.0,
	damage_profile: DamageProfile = null
) -> PackedInt64Array:
	var affected := PackedInt64Array()
	if combat_query != null:
		for handle in combat_query.circle(center, radius):
			var enemy: Variant = combat_query.resolve(handle)
			if not _targetable(enemy):
				continue
			_apply_damage_and_displacement(enemy, center, amount, source, knockback, damage_profile)
			affected.append(handle)
		return affected
	for enemy in _enemies():
		if not _targetable(enemy):
			continue
		var body_radius := _enemy_radius(enemy)
		if topology.distance_squared(center, enemy.global_position) > pow(radius + body_radius, 2.0):
			continue
		_apply_damage_and_displacement(enemy, center, amount, source, knockback, damage_profile)
	return affected

func _damage_line(target: Vector2, values: Dictionary, source: StringName, damage_profile: DamageProfile = null) -> Dictionary:
	var direction := topology.shortest_delta(avatar.global_position, target).normalized()
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	var tags := PackedStringArray(["active", "treatment", "line"])
	var shot := TreatmentShot.line(
		avatar.global_position,
		direction,
		build.value(RunBuildState.ABILITY_DAMAGE, float(values.get("damage", 55.0)), tags),
		build.value(RunBuildState.ABILITY_RANGE, float(values.get("range", 620.0)), tags),
		2147483647,
		source
	)
	shot.hit_radius = build.value(RunBuildState.ABILITY_WIDTH, float(values.get("width", 38.0)), tags) * 0.5
	var affected := PackedInt64Array()
	if combat_query != null:
		for handle in combat_query.line(shot.origin, shot.direction, shot.range_value, shot.hit_radius):
			var enemy: Variant = combat_query.resolve(handle)
			if not _targetable(enemy):
				continue
			_apply_damage_and_displacement(enemy, shot.origin, shot.damage, source, 0.0, damage_profile)
			affected.append(handle)
	else:
		for enemy in shot.resolve_line_hits(_enemies(), topology):
			_apply_damage_and_displacement(enemy, shot.origin, shot.damage, source, 0.0, damage_profile)
	return {
		"direction": shot.direction,
		"length": shot.range_value,
		"width": shot.hit_radius * 2.0,
		"damage": shot.damage,
		"handles": affected,
	}

func _pull_samples(center: Vector2, radius: float) -> Dictionary:
	var affected := PackedInt64Array()
	var points := PackedVector2Array()
	if pickup_query != null:
		for handle in pickup_query.circle(center, radius):
			var pickup: Variant = pickup_query.resolve(handle)
			if not is_instance_valid(pickup) or not pickup is Node2D:
				continue
			points.append(pickup.global_position)
			pickup.set("guided_to_target", true)
			affected.append(handle)
		return {"handles": affected, "points": points}
	var pickups: Array = pickups_provider.call() if pickups_provider.is_valid() else []
	for pickup in pickups:
		if not is_instance_valid(pickup) or not pickup is Node2D:
			continue
		if topology.distance_squared(center, pickup.global_position) <= radius * radius:
			points.append(pickup.global_position)
			pickup.set("guided_to_target", true)
	return {"handles": affected, "points": points}

func _update_legacy_protective_statuses() -> void:
	if combat_query != null:
		return
	var protection_zones := zone_world.zones_for_effect(&"protective_field")
	var has_protection_zone := not protection_zones.is_empty()
	# This used to allocate a filtered array and scan every active enemy on every
	# physics tick, even in builds without a protective field. Only enter the
	# O(enemies) path while the mechanic is active or once to clear an expired
	# field's status.
	if not has_protection_zone:
		if _protective_status_active:
			_clear_legacy_protective_statuses()
			_protective_status_active = false
		return
	_protective_status_active = true
	for enemy in _enemies():
		if not is_instance_valid(enemy):
			continue
		var active_zone: GameplayZoneState = null
		for zone in protection_zones:
			if zone.contains(enemy.global_position, topology):
				active_zone = zone
				break
		if active_zone != null and enemy.has_method("set_status_modifier"):
			enemy.set_status_modifier(
				PROTECTIVE_STATUS,
				float(active_zone.parameters.get("speed_multiplier", 0.65)),
				float(active_zone.parameters.get("contact_multiplier", 0.65))
			)
		elif enemy.has_method("clear_status_modifier"):
			enemy.clear_status_modifier(PROTECTIVE_STATUS)

func _clear_legacy_protective_statuses() -> void:
	for enemy in _enemies():
		if is_instance_valid(enemy) and enemy.has_method("clear_status_modifier"):
			enemy.clear_status_modifier(PROTECTIVE_STATUS)

func _enemies() -> Array:
	return enemies_provider.call() if enemies_provider.is_valid() else []

func _targetable(enemy: Object) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("is_targetable") and enemy.is_targetable() and enemy.has_method("take_damage")

func _enemy_radius(enemy: Object) -> float:
	if enemy.get("definition") != null:
		return float(enemy.definition.radius)
	return 0.0

func _enemy_definition_id(enemy: Object) -> StringName:
	if enemy == null:
		return &""
	var definition_value: Variant = enemy.get("definition")
	if definition_value == null or not definition_value is Object:
		return &""
	var id_value: Variant = (definition_value as Object).get("id")
	return StringName(str(id_value)) if id_value != null else &""

func _apply_damage_and_displacement(
	enemy: Object,
	center: Vector2,
	amount: float,
	source: StringName,
	knockback: float,
	damage_profile: DamageProfile = null
) -> void:
	var resolved_amount := amount
	if _enemy_definition_id(enemy) == &"bacterial_cluster":
		resolved_amount *= build.value(&"group_area_effect", 1.0)
	var enemy_definition: Variant = enemy.get("definition")
	if enemy_definition is Object:
		var resistance_value: Variant = (enemy_definition as Object).get("resistance_profile")
		var resistance_profile := resistance_value as ResistanceProfile
		resolved_amount = CombatDamageResolver.resolve(resolved_amount, damage_profile, resistance_profile, 0.0)
	enemy.take_damage(resolved_amount, source)
	if knockback > 0.0 and enemy.has_method("apply_displacement"):
		var direction := topology.shortest_delta(center, enemy.global_position).normalized()
		enemy.apply_displacement(direction * knockback)

func _complete_failure(
	command: AbilityCommand,
	code: AbilityExecutionResult.Code,
	reason: String,
	definition: AbilityDefinition = null
) -> AbilityExecutionResult:
	return _complete_result(AbilityExecutionResult.failed(command, code, reason, definition))

func _complete_result(result: AbilityExecutionResult) -> AbilityExecutionResult:
	if result.success:
		effect_spawned.emit(result.effect_id, result.target, result.radius if result.radius > 0.0 else result.length, result.duration)
		feedback_requested.emit(result)
	else:
		ability_failed.emit(result.slot, result.reason)
	execution_completed.emit(result)
	return result

func _claim_sequence() -> int:
	var result := _next_command_sequence
	_next_command_sequence += 1
	return result

func _sync_compatibility_zones() -> void:
	for index in range(zones.size() - 1, -1, -1):
		var view := zones[index]
		var state := zone_world.resolve(view.id)
		if state == null:
			zones.remove_at(index)
			continue
		view.center = state.center
		view.radius = state.radius
		view.remaining = state.remaining
		view.total_duration = state.total_duration
		view.parameters = state.parameters

func _exit_tree() -> void:
	clear()
