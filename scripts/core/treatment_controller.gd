class_name TreatmentController
extends Node

signal shots_requested(shots: Array[TreatmentShot])
signal treatment_fired(treatment_id: StringName)
signal feedback_requested(treatment_id: StringName, shots: Array[TreatmentShot])

var definition: TreatmentDefinition
var build: RunBuildState
var topology: ArenaTopology
var avatar: Node2D
var enemies_provider: Callable
var effect_resolver: Object
var enabled: bool = true
var cooldown_remaining: float = 0.18
var strategy: TreatmentStrategy
var manual_aim_enabled: bool = false
var aim_position_provider: Callable
var aim_provider_returns_direction: bool = false
var _manual_aim_sample: Vector2 = Vector2.RIGHT
var _manual_aim_sample_is_direction: bool = true
var _manual_aim_sample_valid: bool = false

func configure(
	treatment: TreatmentDefinition,
	build_state: RunBuildState,
	arena_topology: ArenaTopology,
	avatar_node: Node2D,
	provide_enemies: Callable,
	resolver: Object = null,
	provide_aim_position: Callable = Callable()
) -> void:
	definition = treatment
	build = build_state
	topology = arena_topology
	avatar = avatar_node
	enemies_provider = provide_enemies
	effect_resolver = resolver
	aim_position_provider = provide_aim_position
	aim_provider_returns_direction = false
	manual_aim_enabled = false
	_manual_aim_sample_valid = false
	strategy = _strategy_for(definition.mode if definition != null else TreatmentDefinition.Mode.PRECISE)
	cooldown_remaining = 0.18
	process_mode = Node.PROCESS_MODE_PAUSABLE

## The provider is sampled exactly once on a firing tick. It may return a
## world-space position (default) or a normalized/unscaled direction.
func configure_manual_aim(provider: Callable, enabled_value: bool = true, provider_returns_direction: bool = false) -> void:
	aim_position_provider = provider
	manual_aim_enabled = enabled_value
	aim_provider_returns_direction = provider_returns_direction

## Setter variants are useful to let the input layer publish one deterministic
## fixed-tick sample instead of reading mouse state from this controller.
func set_manual_aim_position(world_position: Vector2) -> void:
	_manual_aim_sample = world_position
	_manual_aim_sample_is_direction = false
	_manual_aim_sample_valid = true

func set_manual_aim_direction(direction: Vector2) -> void:
	_manual_aim_sample = direction
	_manual_aim_sample_is_direction = true
	_manual_aim_sample_valid = true

func clear_manual_aim_sample() -> void:
	_manual_aim_sample_valid = false

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> Array[TreatmentShot]:
	if not enabled or definition == null or build == null or topology == null or not is_instance_valid(avatar):
		return []
	cooldown_remaining -= maxf(delta, 0.0)
	if cooldown_remaining > 0.0:
		return []
	var interval := maxf(0.05, build.value(RunBuildState.TREATMENT_INTERVAL, definition.base_interval, definition.tags))
	# Preserve overshoot so a low frame rate does not silently reduce DPS.
	cooldown_remaining += interval
	var candidates: Array = enemies_provider.call() if enemies_provider.is_valid() else []
	var facing := Vector2.RIGHT
	var facing_value: Variant = avatar.get("last_facing")
	if typeof(facing_value) == TYPE_VECTOR2:
		facing = facing_value
	var use_manual_aim := _manual_aim_active()
	if use_manual_aim:
		facing = _sample_manual_facing(avatar.global_position, facing)
	var shots := strategy.create_shots(avatar.global_position, facing, candidates, topology, definition, build, effect_resolver, use_manual_aim)
	if not shots.is_empty():
		shots_requested.emit(shots)
		feedback_requested.emit(definition.id, shots)
		treatment_fired.emit(definition.id)
	return shots

func reset_cooldown(delay: float = 0.18) -> void:
	cooldown_remaining = maxf(delay, 0.0)

func _manual_aim_active() -> bool:
	if manual_aim_enabled:
		return true
	return build != null and build.value(RunBuildState.TREATMENT_MANUAL_AIM, 0.0, definition.tags if definition != null else PackedStringArray()) >= 0.5

func _sample_manual_facing(origin: Vector2, fallback: Vector2) -> Vector2:
	var sample := _manual_aim_sample
	var sample_is_direction := _manual_aim_sample_is_direction
	if aim_position_provider.is_valid():
		var provided: Variant = aim_position_provider.call()
		if typeof(provided) == TYPE_VECTOR2:
			sample = provided
			sample_is_direction = aim_provider_returns_direction
	elif not _manual_aim_sample_valid:
		return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector2.RIGHT
	var direction := sample if sample_is_direction else topology.shortest_delta(origin, sample)
	return direction.normalized() if direction.length_squared() > 0.0001 else (fallback.normalized() if fallback.length_squared() > 0.0001 else Vector2.RIGHT)

func _strategy_for(mode: TreatmentDefinition.Mode) -> TreatmentStrategy:
	match mode:
		TreatmentDefinition.Mode.SPREAD:
			return SpreadTreatmentStrategy.new()
		TreatmentDefinition.Mode.PIERCING:
			return PiercingTreatmentStrategy.new()
	return PreciseTreatmentStrategy.new()
