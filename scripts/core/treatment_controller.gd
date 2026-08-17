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

func configure(
	treatment: TreatmentDefinition,
	build_state: RunBuildState,
	arena_topology: ArenaTopology,
	avatar_node: Node2D,
	provide_enemies: Callable,
	resolver: Object = null
) -> void:
	definition = treatment
	build = build_state
	topology = arena_topology
	avatar = avatar_node
	enemies_provider = provide_enemies
	effect_resolver = resolver
	strategy = _strategy_for(definition.mode if definition != null else TreatmentDefinition.Mode.PRECISE)
	cooldown_remaining = 0.18
	process_mode = Node.PROCESS_MODE_PAUSABLE

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
	var shots := strategy.create_shots(avatar.global_position, facing, candidates, topology, definition, build, effect_resolver)
	if not shots.is_empty():
		shots_requested.emit(shots)
		feedback_requested.emit(definition.id, shots)
		treatment_fired.emit(definition.id)
	return shots

func reset_cooldown(delay: float = 0.18) -> void:
	cooldown_remaining = maxf(delay, 0.0)

func _strategy_for(mode: TreatmentDefinition.Mode) -> TreatmentStrategy:
	match mode:
		TreatmentDefinition.Mode.SPREAD:
			return SpreadTreatmentStrategy.new()
		TreatmentDefinition.Mode.PIERCING:
			return PiercingTreatmentStrategy.new()
	return PreciseTreatmentStrategy.new()
