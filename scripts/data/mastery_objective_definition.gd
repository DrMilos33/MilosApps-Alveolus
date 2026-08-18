class_name MasteryObjectiveDefinition
extends Resource

@export var id: StringName
@export var level_id: StringName
@export var title: String
@export_multiline var description: String
@export var condition: StringName
@export var threshold: float = 0.0
@export var reward_points: int = 1

static func create(
	definition_id: StringName,
	case_level_id: StringName,
	display_title: String,
	text: String,
	condition_id: StringName,
	value: float = 0.0
) -> MasteryObjectiveDefinition:
	var definition := MasteryObjectiveDefinition.new()
	definition.id = definition_id
	definition.level_id = case_level_id
	definition.title = display_title
	definition.description = text
	definition.condition = condition_id
	definition.threshold = value
	return definition

static func definitions() -> Array[MasteryObjectiveDefinition]:
	return [
		create(&"intro_complete", &"intro", "Grundlagen abgeschlossen", "Das Intro regulär abschließen.", &"victory"),
		create(&"fall_1_first_victory", &"localized_focus", "Erster Erfolg", "Fall 1 gewinnen.", &"victory"),
		create(&"fall_1_early_finding", &"localized_focus", "Früher Befund", "Den Befund vor dem Boss abschließen und gewinnen.", &"finding_before_boss"),
		create(&"fall_1_healthy_win", &"localized_focus", "Stabiler Abschluss", "Mit mindestens 50 % Leben gewinnen.", &"final_stability_ratio", 0.5),
		create(&"fall_2_first_victory", &"spreading_infection", "Erster Erfolg", "Fall 2 gewinnen.", &"victory"),
		# Stable ID retained while the Reserve feature is dormant. The mastery stays
		# achievable and existing completed saves keep their earned point.
		create(&"fall_2_reserve_win", &"spreading_infection", "Angepasster Plan", "Beide Aktivfähigkeiten einsetzen und gewinnen.", &"ability_uses_each", 1.0),
		create(&"fall_2_active_usage", &"spreading_infection", "Aktiver Einsatz", "Beide Aktivfähigkeiten mindestens viermal einsetzen und gewinnen.", &"ability_uses_each", 4.0),
		create(&"fall_3_first_victory", &"severe_pneumonia", "Erster Erfolg", "Fall 3 gewinnen.", &"victory"),
		create(&"fall_3_fast_boss", &"severe_pneumonia", "Schnelle Kontrolle", "Den Boss innerhalb von 45 Sekunden kontrollieren.", &"boss_defeat_window", 45.0),
		create(&"fall_3_safe_condition", &"severe_pneumonia", "Sicherer Verlauf", "Im gesamten Run nie unter 25 % Leben fallen.", &"minimum_stability_ratio", 0.25),
	]

static func catalog() -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions():
		result[definition.id] = definition
	return result

static func total_reward_points() -> int:
	var total := 0
	for definition in definitions():
		total += definition.reward_points
	return total
