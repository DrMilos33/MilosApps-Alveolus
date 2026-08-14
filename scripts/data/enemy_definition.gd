class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var max_health: float
@export var speed: float
@export var contact_damage: float
@export var analysis_value: int
@export var radius: float
@export var color: Color
@export var is_boss: bool = false
@export var discovery_id: StringName

static func create(
	definition_id: StringName,
	name: String,
	health: float,
	move_speed: float,
	damage: float,
	analysis: int,
	body_radius: float,
	body_color: Color,
	boss: bool = false,
	discovery: StringName = &""
) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.id = definition_id
	definition.display_name = name
	definition.max_health = health
	definition.speed = move_speed
	definition.contact_damage = damage
	definition.analysis_value = analysis
	definition.radius = body_radius
	definition.color = body_color
	definition.is_boss = boss
	definition.discovery_id = discovery
	return definition
