class_name ReactionDefinition
extends Resource

@export var id: StringName
@export var finding_id: StringName
@export var title: String
@export_multiline var description: String
@export var modifiers: Array[Dictionary] = []
@export var tags: Array[StringName] = []

static func create(
	reaction_id: StringName,
	parent_finding_id: StringName,
	display_title: String,
	text: String,
	stat_modifiers: Array[Dictionary],
	reaction_tags: Array[StringName] = []
) -> ReactionDefinition:
	var definition := ReactionDefinition.new()
	definition.id = reaction_id
	definition.finding_id = parent_finding_id
	definition.title = display_title
	definition.description = text
	definition.modifiers = stat_modifiers.duplicate(true)
	definition.tags = reaction_tags.duplicate()
	return definition
