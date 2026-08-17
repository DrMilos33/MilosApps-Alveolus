class_name FindingDefinition
extends Resource

enum Behavior {
	GROUPING,
	ACCELERATION,
	PRESSURE_SURGES,
	HIDDEN_NESTS,
}

@export var id: StringName
@export var title: String
@export_multiline var medical_text: String
@export_multiline var gameplay_text: String
@export var behavior: Behavior
@export var magnitude: float
@export var reaction_ids: Array[StringName] = []
@export var eligible_level_ids: Array[StringName] = []

static func create(
	finding_id: StringName,
	display_title: String,
	medical: String,
	gameplay: String,
	behavior_type: Behavior,
	value: float,
	reactions: Array[StringName],
	levels: Array[StringName]
) -> FindingDefinition:
	var definition := FindingDefinition.new()
	definition.id = finding_id
	definition.title = display_title
	definition.medical_text = medical
	definition.gameplay_text = gameplay
	definition.behavior = behavior_type
	definition.magnitude = value
	definition.reaction_ids = reactions.duplicate()
	definition.eligible_level_ids = levels.duplicate()
	return definition

func is_available_for(level_id: StringName) -> bool:
	return eligible_level_ids.is_empty() or eligible_level_ids.has(level_id)
