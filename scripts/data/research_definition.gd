class_name ResearchDefinition
extends Resource

@export var id: StringName
@export var title: String
@export var description: String
@export var max_level: int
@export var costs: PackedInt32Array
@export var effect: StringName
@export var magnitude: float

static func create(
	definition_id: StringName,
	display_title: String,
	text: String,
	level_costs: PackedInt32Array,
	effect_id: StringName,
	value: float
) -> ResearchDefinition:
	var definition := ResearchDefinition.new()
	definition.id = definition_id
	definition.title = display_title
	definition.description = text
	definition.costs = level_costs
	definition.max_level = level_costs.size()
	definition.effect = effect_id
	definition.magnitude = value
	return definition

func cost_for_rank(current_rank: int) -> int:
	if current_rank < 0 or current_rank >= costs.size():
		return 0
	return costs[current_rank]

