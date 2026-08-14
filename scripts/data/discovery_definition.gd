class_name DiscoveryDefinition
extends Resource

@export var id: StringName
@export var trigger: StringName
@export var title: String
@export_multiline var medical_text: String
@export_multiline var gameplay_text: String
@export var target_type: StringName
@export var priority: int = 0
@export var category: StringName = &"mechanic"

static func create(
	discovery_id: StringName,
	discovery_trigger: StringName,
	display_title: String,
	medical: String,
	gameplay: String,
	target: StringName,
	discovery_priority: int,
	discovery_category: StringName
) -> DiscoveryDefinition:
	var definition := DiscoveryDefinition.new()
	definition.id = discovery_id
	definition.trigger = discovery_trigger
	definition.title = display_title
	definition.medical_text = medical
	definition.gameplay_text = gameplay
	definition.target_type = target
	definition.priority = discovery_priority
	definition.category = discovery_category
	return definition
