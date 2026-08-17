class_name LoadoutModuleDefinition
extends Resource

enum Kind {
	TREATMENT,
	ABILITY,
	PASSIVE,
}

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var kind: Kind
@export var capacity_cost: int = 1
@export var tags: Array[StringName] = []
@export var unlock_research_id: StringName = &""
@export var visual_id: StringName = &""
@export var starter: bool = false

static func create(
	module_id: StringName,
	display_title: String,
	text: String,
	module_kind: Kind,
	cost: int,
	module_tags: Array[StringName],
	research_id: StringName = &"",
	is_starter: bool = false
) -> LoadoutModuleDefinition:
	var definition := LoadoutModuleDefinition.new()
	definition.id = module_id
	definition.title = display_title
	definition.description = text
	definition.kind = module_kind
	definition.capacity_cost = maxi(0, cost)
	definition.tags = module_tags.duplicate()
	definition.unlock_research_id = research_id
	definition.visual_id = module_id
	definition.starter = is_starter
	return definition

func kind_name() -> String:
	match kind:
		Kind.TREATMENT:
			return "GRUNDBEHANDLUNG"
		Kind.ABILITY:
			return "AKTIVE FÄHIGKEIT"
		Kind.PASSIVE:
			return "MODUL"
	return "KOMPONENTE"
