class_name TalentDefinition
extends Resource

enum Category { PLANNING, DIAGNOSIS, DEPLOYMENT }

const IMMEDIATE_MEASURE_DURATION_SECONDS := 10.0
const IMMEDIATE_MEASURE_BONUS_FRACTION := 0.50
const ALTERNATING_RHYTHM_WINDOW_SECONDS := 4.0

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var category: Category
@export var cost: int = 1
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
	requirements: PackedStringArray = PackedStringArray()
) -> TalentDefinition:
	var definition := TalentDefinition.new()
	definition.id = definition_id
	definition.title = display_title
	definition.description = text
	definition.category = talent_category
	definition.cost = point_cost
	definition.effect_id = effect
	definition.magnitude = value
	definition.required_ids = requirements
	return definition

func place_in_tree(tier: int, lane: int) -> TalentDefinition:
	tree_tier = maxi(0, tier)
	tree_lane = clampi(lane, 0, 2)
	return self

static func definitions() -> Array[TalentDefinition]:
	return [
		create(&"organization_1", "Organisation I", "+1 Vorbereitungskapazität.", Category.PLANNING, 2, &"loadout_capacity", 1.0).place_in_tree(0, 1),
		create(&"organization_2", "Organisation II", "Nochmals +1 Vorbereitungskapazität.", Category.PLANNING, 2, &"loadout_capacity", 1.0, PackedStringArray(["organization_1"])).place_in_tree(1, 1),
		create(&"hold_card", "Karte halten", "Beim Neuwürfeln darf eine Karte behalten werden.", Category.PLANNING, 1, &"hold_reroll_card", 0.0, PackedStringArray(["organization_2"])).place_in_tree(2, 0),
		create(&"guided_choice", "Gezielte Auswahl", "Jeder dritte Levelaufstieg garantiert eine passende Planoption.", Category.PLANNING, 2, &"guaranteed_synergy", 3.0, PackedStringArray(["organization_2"])).place_in_tree(2, 2),
		create(&"early_classification", "Frühe Einordnung", "Die Befundkategorie ist bereits in der Einsatzplanung sichtbar.", Category.DIAGNOSIS, 2, &"reveal_finding_category").place_in_tree(0, 1),
		create(&"rapid_evaluation", "Schnellauswertung", "20 % weniger Befundfortschritt nötig.", Category.DIAGNOSIS, 1, &"finding_threshold_multiplier", 0.8, PackedStringArray(["early_classification"])).place_in_tree(1, 1),
		create(&"broader_perspective", "Weitere Perspektive", "Ersetzt eine Befundreaktion durch Flexible Anpassung.", Category.DIAGNOSIS, 2, &"finding_reaction_count", 1.0, PackedStringArray(["rapid_evaluation"])).place_in_tree(2, 0),
		create(
			&"immediate_measure",
			"Sofortmaßnahme",
			"Befundreaktionen wirken 10 Sekunden lang 50 % stärker; einmaliger Schutz steigt sofort um 50 %.",
			Category.DIAGNOSIS,
			1,
			&"reaction_boost_seconds",
			IMMEDIATE_MEASURE_DURATION_SECONDS,
			PackedStringArray(["rapid_evaluation"])
		).place_in_tree(2, 2),
		create(&"alternating_rhythm", "Wechselrhythmus", "Ein Fähigkeitswechsel binnen 4 s verkürzt die zweite Abklingzeit um 25 %.", Category.DEPLOYMENT, 1, &"alternating_cooldown_multiplier", 0.75).place_in_tree(0, 1),
		create(&"linked_deployment", "Gekoppelter Einsatz", "Eine Fähigkeit reduziert die Restzeit der anderen um zwei Sekunden.", Category.DEPLOYMENT, 2, &"linked_cooldown_reduction", 2.0, PackedStringArray(["alternating_rhythm"])).place_in_tree(1, 1),
		create(&"finding_readiness", "Befundbereitschaft", "Die Befundaufdeckung halbiert beide Restzeiten.", Category.DEPLOYMENT, 1, &"finding_cooldown_multiplier", 0.5, PackedStringArray(["linked_deployment"])).place_in_tree(2, 0),
		create(&"emergency_window", "Notfallfenster", "Unter 25 % Zustand werden beide Fähigkeiten einmal pro Run zurückgesetzt.", Category.DEPLOYMENT, 2, &"emergency_cooldown_reset", 0.25, PackedStringArray(["linked_deployment"])).place_in_tree(2, 2),
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
		total += definition.cost
	return total
