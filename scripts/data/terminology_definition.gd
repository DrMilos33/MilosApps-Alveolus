class_name TerminologyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var medical_name: String
@export_multiline var summary: String
@export_multiline var gameplay_text: String
@export var unit: String
@export var related_ids: Array[StringName] = []
@export var visual_id: StringName

static func create(
	definition_id: StringName,
	title: String,
	medical: String,
	short_summary: String,
	gameplay_explanation: String,
	related: Array[StringName] = [],
	value_unit: String = "",
	illustration_id: StringName = &"automatic_therapy"
) -> TerminologyDefinition:
	var definition := TerminologyDefinition.new()
	definition.id = definition_id
	definition.display_name = title
	definition.medical_name = medical
	definition.summary = short_summary
	definition.gameplay_text = gameplay_explanation
	definition.related_ids.assign(related)
	definition.unit = value_unit
	definition.visual_id = illustration_id
	return definition
