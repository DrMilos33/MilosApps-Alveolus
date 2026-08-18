class_name CaseTraitDefinition
extends Resource

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var modifiers: Array[Dictionary] = []
@export var eligible_level_ids: Array[StringName] = []
@export var semantic_role: StringName = &"negative"

static func create(
	trait_id: StringName,
	display_title: String,
	text: String,
	stat_modifiers: Array[Dictionary],
	levels: Array[StringName],
	role: StringName = &"negative"
) -> CaseTraitDefinition:
	var definition := CaseTraitDefinition.new()
	definition.id = trait_id
	definition.title = display_title
	definition.description = text
	definition.modifiers = stat_modifiers.duplicate(true)
	definition.eligible_level_ids = levels.duplicate()
	definition.semantic_role = role if role in [&"negative", &"mixed", &"positive"] else &"negative"
	return definition

func is_available_for(level_id: StringName) -> bool:
	return eligible_level_ids.is_empty() or eligible_level_ids.has(level_id)
