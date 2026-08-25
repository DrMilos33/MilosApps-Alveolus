class_name TalentDefinition
extends Resource

## Category values stay source-compatible until the progression view moves to
## its single treatment tree. All current definitions use DEPLOYMENT.
enum Category { PLANNING, DIAGNOSIS, DEPLOYMENT }

## Temporary source-compatibility constants for the still-unmigrated Game
## facade. Their former talents are not part of definitions() or catalog().
const IMMEDIATE_MEASURE_DURATION_SECONDS := 10.0
const IMMEDIATE_MEASURE_BONUS_FRACTION := 0.50
const ALTERNATING_RHYTHM_WINDOW_SECONDS := 4.0

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var category: Category
@export var cost: int = 1
@export var max_rank: int = 1
@export var rank_costs: PackedInt32Array = PackedInt32Array([1])
@export var required_ids: PackedStringArray = PackedStringArray()
@export var effect_id: StringName
@export var magnitude: float = 0.0
@export var tree_tier: int = 0
@export var tree_lane: int = 1


static func create(
	definition_id: StringName,
	display_title: String,
	text: String,
	talent_category: Category,
	point_cost: int,
	effect: StringName,
	value: float = 0.0,
	requirements: PackedStringArray = PackedStringArray(),
	rank_limit: int = 1,
	per_rank_costs: PackedInt32Array = PackedInt32Array()
) -> TalentDefinition:
	var definition := TalentDefinition.new()
	definition.id = definition_id
	definition.title = display_title
	definition.description = text
	definition.category = talent_category
	definition.max_rank = maxi(1, rank_limit)
	definition.rank_costs = per_rank_costs.duplicate()
	if definition.rank_costs.is_empty():
		definition.rank_costs.resize(definition.max_rank)
		definition.rank_costs.fill(maxi(0, point_cost))
	elif definition.rank_costs.size() != definition.max_rank:
		definition.rank_costs.resize(definition.max_rank)
		for rank_index in range(definition.rank_costs.size()):
			if definition.rank_costs[rank_index] <= 0:
				definition.rank_costs[rank_index] = maxi(0, point_cost)
	definition.cost = definition.rank_costs[0]
	definition.effect_id = effect
	definition.magnitude = value
	definition.required_ids = requirements
	return definition


func place_in_tree(tier: int, lane: int) -> TalentDefinition:
	tree_tier = maxi(0, tier)
	tree_lane = clampi(lane, 0, 2)
	return self


func cost_for_rank(current_rank: int) -> int:
	return rank_costs[current_rank] if current_rank >= 0 and current_rank < rank_costs.size() else 0


func total_rank_cost() -> int:
	var total := 0
	for rank_cost in rank_costs:
		total += rank_cost
	return total


static func definitions() -> Array[TalentDefinition]:
	return [
		create(
			&"treatment_damage_training",
			"Behandlungsgrundlage",
			"Erhöht den Schaden aller drei Behandlungen um 2.",
			Category.DEPLOYMENT,
			1,
			&"treatment_damage_flat",
			2.0
		).place_in_tree(0, 1),
		create(
			&"spread_shotgun",
			"Schrotwirkung",
			"Mehrere Strahlen derselben Streuimpuls-Salve können dasselbe Ziel treffen.",
			Category.DEPLOYMENT,
			1,
			&"spread_shotgun",
			1.0,
			PackedStringArray(["treatment_damage_training"])
		).place_in_tree(1, 0),
		create(
			&"manual_treatment_aim",
			"Manuelle Zielsteuerung",
			"Alle Behandlungen schießen in Richtung der Maus statt automatisch auf das nächste Ziel.",
			Category.DEPLOYMENT,
			1,
			&"manual_treatment_aim",
			1.0,
			PackedStringArray(["treatment_damage_training"])
		).place_in_tree(1, 1),
		create(
			&"piercing_persistence",
			"Anhaltender Laser",
			"Der durchdringende Laser bleibt pro Rang 0,5 Sekunden bestehen und trifft alle 0,25 Sekunden.",
			Category.DEPLOYMENT,
			1,
			&"piercing_duration_per_rank",
			0.5,
			PackedStringArray(["treatment_damage_training"]),
			2,
			PackedInt32Array([1, 1])
		).place_in_tree(1, 2),
	]


static func catalog() -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions():
		result[definition.id] = definition
	return result


static func magnitude_for(talent_id: StringName, fallback: float = 0.0) -> float:
	var definition: TalentDefinition = catalog().get(talent_id)
	return definition.magnitude if definition != null else fallback


static func total_cost() -> int:
	var total := 0
	for definition in definitions():
		total += definition.total_rank_cost()
	return total
