class_name TalentDefinition
extends Resource

## Category values stay source-compatible while the visible tree identity is
## carried separately by tree_id/tree_title/tree_icon_id.
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
@export var tree_id: StringName = &"treatment"
@export var tree_title: String = "Behandlungen"
@export var tree_icon_id: StringName = &"treatment"
@export var implemented: bool = true


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


func place_in_tree(
	tier: int,
	lane: int,
	resolved_tree_id: StringName = &"treatment",
	resolved_tree_title: String = "Behandlungen",
	resolved_tree_icon_id: StringName = &"treatment"
) -> TalentDefinition:
	tree_tier = maxi(0, tier)
	tree_lane = clampi(lane, 0, 7)
	tree_id = resolved_tree_id
	tree_title = resolved_tree_title
	tree_icon_id = resolved_tree_icon_id
	return self


func mark_placeholder(selectable_gateway: bool = false) -> TalentDefinition:
	implemented = selectable_gateway
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
		# Upgrades
		create(
			&"upgrade_rarity_training",
			"Seltene Upgrades",
			"Erhöht pro Rang die relative Chance auf ein Magic- oder Rare-Upgrade um 5 %.",
			Category.PLANNING,
			1,
			&"upgrade_rarity_bias",
			0.05,
			PackedStringArray(),
			3,
			PackedInt32Array([1, 1, 1])
		).place_in_tree(0, 1, &"upgrades", "Upgrades", &"research"),
		create(
			&"upgrade_placeholder_left",
			"Platzhalter",
			"Platzhalter · Wirkung folgt später.",
			Category.PLANNING,
			1,
			&"placeholder",
			0.0,
			PackedStringArray(["upgrade_rarity_training"])
		).place_in_tree(1, 0, &"upgrades", "Upgrades", &"research").mark_placeholder(),
		create(
			&"upgrade_placeholder_middle",
			"Platzhalter",
			"Platzhalter · Wirkung folgt später.",
			Category.PLANNING,
			1,
			&"placeholder",
			0.0,
			PackedStringArray(["upgrade_rarity_training"])
		).place_in_tree(1, 1, &"upgrades", "Upgrades", &"research").mark_placeholder(),
		create(
			&"defense_cells_first",
			"Abwehrzellen zuerst",
			"Ab Fall 3 sind Abwehrzellen immer die erste Level-up-Auswahl.",
			Category.PLANNING,
			1,
			&"defense_cells_first",
			1.0,
			PackedStringArray(["upgrade_rarity_training"])
		).place_in_tree(1, 2, &"upgrades", "Upgrades", &"research"),
		create(
			&"defense_cells_placeholder_1",
			"Platzhalter",
			"Platzhalter · Wirkung folgt später.",
			Category.PLANNING,
			1,
			&"placeholder",
			0.0,
			PackedStringArray(["defense_cells_first"])
		).place_in_tree(2, 2, &"upgrades", "Upgrades", &"research").mark_placeholder(),
		create(
			&"defense_cells_placeholder_2",
			"Platzhalter",
			"Platzhalter · Wirkung folgt später.",
			Category.PLANNING,
			1,
			&"placeholder",
			0.0,
			PackedStringArray(["defense_cells_placeholder_1"])
		).place_in_tree(3, 2, &"upgrades", "Upgrades", &"research").mark_placeholder(),

		# Aktive Fähigkeiten
		create(
			&"active_foundation_placeholder",
			"Aktivgrundlage",
			"Platzhalter · Wirkung folgt später. Schaltet die drei Äste für aktive Fähigkeiten frei.",
			Category.DIAGNOSIS,
			1,
			&"placeholder",
			0.0
		).place_in_tree(0, 1, &"active", "Aktive Fähigkeiten", &"ability").mark_placeholder(true),
		create(
			&"active_placeholder_left",
			"Platzhalter",
			"Platzhalter · Wirkung folgt später.",
			Category.DIAGNOSIS,
			1,
			&"placeholder",
			0.0,
			PackedStringArray(["active_foundation_placeholder"])
		).place_in_tree(1, 0, &"active", "Aktive Fähigkeiten", &"ability").mark_placeholder(),
		create(
			&"defense_burst_damage",
			"Stoß verursacht Schaden",
			"Stoß verursacht 20 Schaden und Schadensupgrades für Stoß können beim Level-up erscheinen.",
			Category.DIAGNOSIS,
			1,
			&"defense_burst_damage",
			20.0,
			PackedStringArray(["active_foundation_placeholder"])
		).place_in_tree(1, 1, &"active", "Aktive Fähigkeiten", &"ability"),
		create(
			&"active_placeholder_right",
			"Platzhalter",
			"Platzhalter · Wirkung folgt später.",
			Category.DIAGNOSIS,
			1,
			&"placeholder",
			0.0,
			PackedStringArray(["active_foundation_placeholder"])
		).place_in_tree(1, 2, &"active", "Aktive Fähigkeiten", &"ability").mark_placeholder(),

		# Behandlungen
		create(
			&"treatment_damage_training",
			"Behandlungsgrundlage",
			"Erhöht den Basisschaden aller drei Behandlungen pro Rang um 20 %.",
			Category.DEPLOYMENT,
			1,
			&"treatment_base_damage_percent",
			0.20,
			PackedStringArray(),
			3,
			PackedInt32Array([1, 1, 1])
		).place_in_tree(0, 1, &"treatment", "Behandlungen", &"treatment"),
		create(
			&"manual_treatment_aim",
			"Manuelle Zielsteuerung",
			"Alle Behandlungen schießen in Richtung der Maus statt automatisch auf das nächste Ziel.",
			Category.DEPLOYMENT,
			1,
			&"manual_treatment_aim",
			1.0,
			PackedStringArray(["treatment_damage_training"])
		).place_in_tree(1, 0, &"treatment", "Behandlungen", &"treatment"),
		create(
			&"manual_aim_placeholder_1", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["manual_treatment_aim"])
		).place_in_tree(2, 0, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
		create(
			&"manual_aim_placeholder_2", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["manual_aim_placeholder_1"])
		).place_in_tree(3, 0, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
		create(
			&"spread_shotgun",
			"Schrotwirkung",
			"Mehrere Strahlen derselben Streuimpuls-Salve können dasselbe Ziel treffen.",
			Category.DEPLOYMENT,
			1,
			&"spread_shotgun",
			1.0,
			PackedStringArray(["treatment_damage_training"])
		).place_in_tree(1, 1, &"treatment", "Behandlungen", &"treatment"),
		create(
			&"spread_placeholder_1", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["spread_shotgun"])
		).place_in_tree(2, 1, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
		create(
			&"spread_placeholder_2", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["spread_placeholder_1"])
		).place_in_tree(3, 1, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
		create(
			&"spread_placeholder_3", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["spread_placeholder_2"])
		).place_in_tree(4, 1, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
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
		).place_in_tree(1, 2, &"treatment", "Behandlungen", &"treatment"),
		create(
			&"piercing_placeholder_1", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["piercing_persistence"])
		).place_in_tree(2, 2, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
		create(
			&"piercing_placeholder_2", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["piercing_placeholder_1"])
		).place_in_tree(3, 2, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
		create(
			&"piercing_placeholder_3", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["piercing_placeholder_2"])
		).place_in_tree(4, 2, &"treatment", "Behandlungen", &"treatment").mark_placeholder(),
		create(
			&"impulse_splash",
			"Impulsexplosion",
			"Impuls erzeugt beim Treffer eine kleine Explosion. Nahe Gegner erleiden 10 % des Treffers als Schaden.",
			Category.DEPLOYMENT,
			1,
			&"impulse_splash",
			0.10,
			PackedStringArray(["treatment_damage_training"])
		).place_in_tree(1, 3, &"treatment", "Behandlungen", &"treatment_precision"),
		create(
			&"impulse_placeholder_1", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["impulse_splash"])
		).place_in_tree(2, 3, &"treatment", "Behandlungen", &"treatment_precision").mark_placeholder(),
		create(
			&"impulse_placeholder_2", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["impulse_placeholder_1"])
		).place_in_tree(3, 3, &"treatment", "Behandlungen", &"treatment_precision").mark_placeholder(),
		create(
			&"impulse_placeholder_3", "Platzhalter", "Platzhalter · Wirkung folgt später.",
			Category.DEPLOYMENT, 1, &"placeholder", 0.0, PackedStringArray(["impulse_placeholder_2"])
		).place_in_tree(4, 3, &"treatment", "Behandlungen", &"treatment_precision").mark_placeholder(),
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
