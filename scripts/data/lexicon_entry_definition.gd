class_name LexiconEntryDefinition
extends Resource

const CATEGORY_MONSTERS: StringName = &"monsters"
const CATEGORY_CHARACTER: StringName = &"character"
const CATEGORY_GAMEPLAY: StringName = &"gameplay"
const CATEGORY_TERMS: StringName = &"terms"

const SOURCE_ENEMY: StringName = &"enemy"
const SOURCE_PLAYER: StringName = &"player"
const SOURCE_DISCOVERY: StringName = &"discovery"
const SOURCE_TERMINOLOGY: StringName = &"terminology"

@export var id: StringName
@export var category: StringName
@export var display_name: String
@export var medical_name: String
@export_multiline var summary: String
@export_multiline var gameplay_text: String
@export_multiline var medical_text: String
@export var visual_id: StringName
@export var discovery_id: StringName
@export var source_kind: StringName
@export var source_id: StringName
@export var related_ids: Array[StringName] = []
@export var unlocked_by_default: bool = false

static func create(
	entry_id: StringName,
	entry_category: StringName,
	title: String,
	medical: String,
	short_summary: String,
	gameplay_explanation: String,
	medical_explanation: String,
	illustration_id: StringName,
	value_source_kind: StringName,
	value_source_id: StringName,
	discovery: StringName = &"",
	default_unlocked: bool = false,
	related: Array[StringName] = []
) -> LexiconEntryDefinition:
	var definition := LexiconEntryDefinition.new()
	definition.id = entry_id
	definition.category = entry_category
	definition.display_name = title
	definition.medical_name = medical
	definition.summary = short_summary
	definition.gameplay_text = gameplay_explanation
	definition.medical_text = medical_explanation
	definition.visual_id = illustration_id
	definition.source_kind = value_source_kind
	definition.source_id = value_source_id
	definition.discovery_id = discovery
	definition.unlocked_by_default = default_unlocked
	definition.related_ids.assign(related)
	return definition
