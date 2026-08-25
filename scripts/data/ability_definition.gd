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
@export var damage_profile: DamageProfile

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
	medical: String = "",
	profile: DamageProfile = null
) -> AbilityDefinition:
	var definition := AbilityDefinition.new()
	definition.id = definition_id
	definition.display_name = title
	definition.medical_name = title if medical.is_empty() else medical
	definition.target_mode = mode
	definition.cooldown = base_cooldown
	definition.effect_id = effect
	definition.parameters = _normalized_parameters(values)
	definition.research_cost = unlock_cost
	definition.tags = CombatTagCatalog.normalize(ability_tags)
	definition.description = text
	definition.damage_profile = profile
	return definition


func parameter_stage(parameter_id: StringName) -> int:
	return CombatDistanceScale.stage_from_world(float(parameters.get(parameter_id, 0.0)))


static func _normalized_parameters(values: Dictionary) -> Dictionary:
	var result := values.duplicate(true)
	if result.has("damage"):
		result["damage"] = float(roundi(float(result["damage"])))
	for key in [&"radius", &"range"]:
		if result.has(key):
			result[key] = CombatDistanceScale.quantize_world(float(result[key]))
	return result

static func catalog() -> Dictionary:
	return {
		&"ability_focus_field": create(
			&"ability_focus_field", "Fokusfeld", TargetMode.CURSOR_AREA, 16.0, &"focus_field",
			{"radius": 180.0, "duration": 7.0, "damage_multiplier": 1.25}, 0,
			PackedStringArray(["active", "control", "precise", "focus", "marked"]),
			"Behandlung im Zielgebiet verursacht 25 % mehr Schaden."
		),
		&"ability_emergency_support": create(
			&"ability_emergency_support", "Notfallhilfe", TargetMode.SELF, 28.0, &"emergency_support",
			{"recovery": 14.0, "shield": 8.0}, 0,
			PackedStringArray(["active", "support", "defensive"]),
			"Stellt 14 Leben wieder her und gewährt 8 Schild."
		),
		&"ability_defense_burst": create(
			&"ability_defense_burst", "Stoß", TargetMode.CURSOR_AREA, 14.0, &"defense_burst",
			{"damage": 0.0, "radius": 150.0, "knockback": 120.0, "stun_duration": 1.0}, 50,
			PackedStringArray(["active", "defense", "area", "control"]),
			"Stößt Gegner sichtbar zurück und betäubt sie für 1 Sekunde. Schießende Nichtbosse können danach nicht mehr feuern.", "",
			DamageProfile.single(&"ability_defense_burst_damage", &"earth")
		),
		&"ability_treatment_line": create(
			&"ability_treatment_line", "Fetter lazer", TargetMode.CURSOR_DIRECTION, 18.0, &"treatment_line",
			{"damage": 30.0, "range": 630.0, "width": 38.0}, 80,
			PackedStringArray(["active", "treatment", "line", "precise"]),
			"30 Schaden in einer durchdringenden Linie.", "",
			DamageProfile.single(&"ability_treatment_line_damage", &"water")
		),
		&"ability_protection_field": create(
			&"ability_protection_field", "Schildfeld", TargetMode.CURSOR_AREA, 20.0, &"protective_field",
			{"radius": 180.0, "duration": 6.0, "speed_multiplier": 0.65, "contact_multiplier": 0.65}, 70,
			PackedStringArray(["active", "support", "area", "control"]),
			"Gegner im Feld: −35 % Geschwindigkeit und Schaden."
		),
		&"ability_sample_pull": create(
			&"ability_sample_pull", "Erfahrungszug", TargetMode.CURSOR_AREA, 18.0, &"sample_pull",
			{"radius": 240.0, "finding_progress": 6.0}, 70,
			PackedStringArray(["active", "sample", "diagnosis"]),
			"Zieht Erfahrung im Zielgebiet an und beschleunigt den Befund."
		),
	}
