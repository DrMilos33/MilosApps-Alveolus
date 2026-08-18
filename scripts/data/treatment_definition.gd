class_name TreatmentDefinition
extends Resource

enum Mode {
	PRECISE,
	SPREAD,
	PIERCING,
}

@export var id: StringName
@export var display_name: String
@export var medical_name: String
@export_multiline var description: String
@export var mode: Mode = Mode.PRECISE
@export var capacity_cost: int = 2
@export var research_cost: int = 0
@export var base_damage: float = 18.0
@export var base_interval: float = 0.82
@export var base_range: float = 480.0
@export var base_targets: int = 1
@export var base_projectiles: int = 1
@export var max_hits: int = 1
@export var spread_degrees: float = 0.0
@export var tags: PackedStringArray = PackedStringArray()
@export var damage_profile: DamageProfile

static func create(
	definition_id: StringName,
	title: String,
	treatment_mode: Mode,
	damage: float,
	interval: float,
	range_value: float,
	projectiles: int,
	hit_limit: int,
	unlock_cost: int,
	treatment_tags: PackedStringArray,
	text: String = "",
	medical: String = "",
	profile: DamageProfile = null
) -> TreatmentDefinition:
	var definition := TreatmentDefinition.new()
	definition.id = definition_id
	definition.display_name = title
	definition.medical_name = title if medical.is_empty() else medical
	definition.description = text
	definition.mode = treatment_mode
	definition.base_damage = damage
	definition.base_interval = interval
	definition.base_range = CombatDistanceScale.quantize_world(range_value)
	definition.base_projectiles = projectiles
	definition.max_hits = hit_limit
	definition.research_cost = unlock_cost
	definition.tags = CombatTagCatalog.normalize(treatment_tags)
	definition.spread_degrees = 14.0 if treatment_mode == Mode.SPREAD else 0.0
	definition.damage_profile = profile
	return definition


func base_range_stage() -> int:
	return CombatDistanceScale.stage_from_world(base_range)

static func catalog() -> Dictionary:
	return {
		&"treatment_precision": create(
			&"treatment_precision", "Impuls", Mode.PRECISE,
			16.0, 0.82, 480.0, 1, 1, 0,
			PackedStringArray(["treatment", "precise", "tracking"]),
			"Verfolgt automatisch das nächste Ziel.", "Gezielte antibiotische Therapie",
			DamageProfile.single(&"treatment_precision_damage", &"water")
		),
		&"treatment_spread": create(
			&"treatment_spread", "Streuimpuls", Mode.SPREAD,
			5.0, 1.0, 450.0, 3, 1, 60,
			PackedStringArray(["treatment", "spread", "area"]),
			"Drei kurze Impulse decken einen breiten Winkel ab.", "Breit angelegte antibiotische Therapie",
			DamageProfile.single(&"treatment_spread_damage", &"fire")
		),
		&"treatment_pierce": create(
			&"treatment_pierce", "Durchdringender Impuls", Mode.PIERCING,
			9.0, 1.65, 510.0, 1, 4, 100,
			PackedStringArray(["treatment", "piercing", "line"]),
			"Durchdringt bis zu vier Bakterien in einer Linie.", "Gewebegängige antibiotische Therapie",
			DamageProfile.single(&"treatment_pierce_damage", &"wind")
		),
	}
