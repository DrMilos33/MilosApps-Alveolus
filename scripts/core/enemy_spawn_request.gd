class_name EnemySpawnRequest
extends RefCounted

enum Priority {
	REGULAR,
	CRITICAL,
}

var definition_id: StringName = &""
var visual_id: StringName = &""
var position: Vector2 = Vector2.ZERO
var health_scale: float = 1.0
var movement_scale: float = 1.0
var contact_scale: float = 1.0
var boss_phases: PackedInt32Array = PackedInt32Array()
var source_id: StringName = &"spawn_director"
var priority: Priority = Priority.REGULAR
var metadata: Dictionary = {}

static func create(
	definition: StringName,
	spawn_position: Vector2,
	visual: StringName = &"",
	health_multiplier: float = 1.0,
	movement_multiplier: float = 1.0,
	contact_multiplier: float = 1.0,
	phases: PackedInt32Array = PackedInt32Array(),
	request_priority: Priority = Priority.REGULAR,
	source: StringName = &"spawn_director"
) -> EnemySpawnRequest:
	var request := EnemySpawnRequest.new()
	request.definition_id = definition
	request.visual_id = visual
	request.position = spawn_position
	request.health_scale = maxf(health_multiplier, 0.001)
	request.movement_scale = maxf(movement_multiplier, 0.0)
	request.contact_scale = maxf(contact_multiplier, 0.0)
	request.boss_phases = phases.duplicate()
	request.priority = request_priority
	request.source_id = source
	return request

func is_valid() -> bool:
	return definition_id != &"" and health_scale > 0.0 and movement_scale >= 0.0 and contact_scale >= 0.0

func is_critical() -> bool:
	return priority == Priority.CRITICAL

func resolved_visual_id() -> StringName:
	return definition_id if visual_id == &"" else visual_id

func duplicate_request() -> EnemySpawnRequest:
	var copy := EnemySpawnRequest.create(
		definition_id,
		position,
		visual_id,
		health_scale,
		movement_scale,
		contact_scale,
		boss_phases,
		priority,
		source_id
	)
	copy.metadata = metadata.duplicate(true)
	return copy

func reset() -> void:
	definition_id = &""
	visual_id = &""
	position = Vector2.ZERO
	health_scale = 1.0
	movement_scale = 1.0
	contact_scale = 1.0
	boss_phases = PackedInt32Array()
	source_id = &"spawn_director"
	priority = Priority.REGULAR
	metadata.clear()
