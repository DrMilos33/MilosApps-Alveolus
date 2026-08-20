class_name ResearchDefinition
extends Resource

@export var id: StringName
@export var title: String
@export var description: String
@export var max_level: int
@export var costs: PackedInt32Array
@export var effect: StringName
@export var magnitude: float
@export var unlock_module_id: StringName = &""
@export var category: StringName = &"passive"

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

func configure_unlock(module_id: StringName, research_category: StringName = &"module") -> ResearchDefinition:
	unlock_module_id = module_id
	category = research_category
	return self

func cost_for_rank(current_rank: int) -> int:
	if current_rank < 0 or current_rank >= costs.size():
		return 0
	return costs[current_rank]


func total_value_for_rank(rank: int) -> float:
	var resolved_rank := clampi(rank, 0, max_level)
	if effect == &"unlock":
		return 1.0 if resolved_rank > 0 else 0.0
	return magnitude * float(resolved_rank)


func total_effect_text(rank: int) -> String:
	var total := total_value_for_rank(rank)
	match effect:
		&"max_health":
			return "+%s Leben" % _number(total)
		&"damage_multiplier":
			return "+%s %% Schaden" % _number(total * 100.0)
		&"damage_flat":
			return "+%s Schaden" % _number(total)
		&"experience_multiplier":
			return "+%s %% Erfahrung" % _number(total * 100.0)
		&"defense":
			return "+%s Verteidigung" % _number(total)
		&"life_regeneration":
			return "+%s/s" % _number(total, 2)
		&"movement_speed_multiplier":
			return "+%s %% Galopp" % _number(total * 100.0)
		&"unlock":
			return "Freigeschaltet" if total > 0.0 else "Noch nicht freigeschaltet"
	return _number(total)


func total_effect_presentation(rank: int) -> Dictionary:
	return {
		"stable_id": id,
		"value": total_value_for_rank(rank),
		"formatted_value": total_effect_text(rank),
		"semantic_role": &"positive" if rank > 0 else &"neutral",
	}


func _number(value: float, maximum_decimals: int = 1) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	var digits := maxi(1, maximum_decimals)
	var text := ("%.*f" % [digits, value]).replace(".", ",")
	while text.ends_with("0"):
		text = text.left(-1)
	return text.trim_suffix(",")
