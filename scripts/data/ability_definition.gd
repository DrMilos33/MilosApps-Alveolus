class_name AbilityDefinition
extends Resource

enum TargetMode {
	SELF,
	CURSOR_AREA,
	CURSOR_DIRECTION,
}

@export var id: StringName
@export var display_name: String
@export var medical_name: String
@export_multiline var description: String
@export var target_mode: TargetMode = TargetMode.CURSOR_AREA
@export var cooldown: float = 16.0
@export var capacity_cost: int = 2
@export var research_cost: int = 0
@export var effect_id: StringName
@export var parameters: Dictionary = {}
@export var tags: PackedStringArray = PackedStringArray()

static func create(
	definition_id: StringName,
	title: String,
	mode: TargetMode,
	base_cooldown: float,
	effect: StringName,
	values: Dictionary,
	unlock_cost: int = 0,
	ability_tags: PackedStringArray = PackedStringArray(),
	text: String = "",
	medical: String = ""
) -> AbilityDefinition:
	var definition := AbilityDefinition.new()
	definition.id = definition_id
	definition.display_name = title
	definition.medical_name = title if medical.is_empty() else medical
	definition.target_mode = mode
	definition.cooldown = base_cooldown
	definition.effect_id = effect
	definition.parameters = values.duplicate(true)
	definition.research_cost = unlock_cost
	definition.tags = CombatTagCatalog.normalize(ability_tags)
	definition.description = text
	return definition

static func catalog() -> Dictionary:
	return {
		&"ability_focus_field": create(
			&"ability_focus_field", "Fokusfeld", TargetMode.CURSOR_AREA, 16.0, &"focus_field",
			{"radius": 165.0, "duration": 7.0, "damage_multiplier": 1.25}, 0,
			PackedStringArray(["active", "control", "precise", "focus", "marked"]),
			"Behandlung im Zielgebiet verursacht 25 % mehr Schaden."
		),
		&"ability_emergency_support": create(
			&"ability_emergency_support", "Notfallhilfe", TargetMode.SELF, 28.0, &"emergency_support",
			{"recovery": 14.0, "shield": 8.0}, 0,
			PackedStringArray(["active", "support", "defensive"]),
			"Stellt 14 Zustand wieder her und gewährt 8 Schutz."
		),
		&"ability_defense_burst": create(
			&"ability_defense_burst", "Abwehrstoß", TargetMode.CURSOR_AREA, 14.0, &"defense_burst",
			{"damage": 42.0, "radius": 150.0, "knockback": 75.0}, 50,
			PackedStringArray(["active", "defense", "area", "control"]),
			"42 AoE-Schaden und Rückstoß im Zielbereich."
		),
		&"ability_treatment_line": create(
			&"ability_treatment_line", "Behandlungslinie", TargetMode.CURSOR_DIRECTION, 18.0, &"treatment_line",
			{"damage": 55.0, "range": 620.0, "width": 38.0}, 80,
			PackedStringArray(["active", "treatment", "line", "precise"]),
			"55 Schaden in einer durchdringenden Linie."
		),
		&"ability_protection_field": create(
			&"ability_protection_field", "Schutzfeld", TargetMode.CURSOR_AREA, 20.0, &"protective_field",
			{"radius": 185.0, "duration": 6.0, "speed_multiplier": 0.65, "contact_multiplier": 0.65}, 70,
			PackedStringArray(["active", "support", "area", "control"]),
			"Gegner im Feld: −35 % Tempo und Kontaktschaden."
		),
		&"ability_sample_pull": create(
			&"ability_sample_pull", "Probenzug", TargetMode.CURSOR_AREA, 18.0, &"sample_pull",
			{"radius": 230.0, "finding_progress": 6.0}, 70,
			PackedStringArray(["active", "sample", "diagnosis"]),
			"Zieht Proben im Zielgebiet an und beschleunigt den Befund."
		),
	}
