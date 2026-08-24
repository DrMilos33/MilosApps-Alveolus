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
	value: float = 0.0,
	points: int = 1
) -> MasteryObjectiveDefinition:
	var definition := MasteryObjectiveDefinition.new()
	definition.id = definition_id
	definition.level_id = case_level_id
	definition.title = display_title
	definition.description = text
	definition.condition = condition_id
	definition.threshold = value
	definition.reward_points = maxi(points, 0)
	return definition

static func definitions() -> Array[MasteryObjectiveDefinition]:
	return [
		create(&"intro_complete", &"intro", "Grundlagen abgeschlossen", "Das Intro regulär abschließen.", &"victory", 0.0, 0),
		create(&"fall_1_first_victory", &"early_localized_focus", "Erster Erfolg", "Fall 1 gewinnen.", &"victory", 0.0, 0),
		create(&"fall_1_early_finding", &"early_localized_focus", "Früher Befund", "Den Befund vor dem Boss abschließen und gewinnen.", &"finding_before_boss", 0.0, 0),
		create(&"fall_1_healthy_win", &"early_localized_focus", "Stabiler Abschluss", "Mit mindestens 50 % Leben gewinnen.", &"final_stability_ratio", 0.5, 0),
		create(&"fall_2_first_victory", &"localized_focus", "Erster Erfolg", "Fall 2 gewinnen.", &"victory"),
		# Stable ID retained while the Reserve feature is dormant. The mastery stays
		# achievable and existing completed saves keep their earned point.
		create(&"fall_2_reserve_win", &"localized_focus", "Angepasster Plan", "Beide Aktivfähigkeiten einsetzen und gewinnen.", &"ability_uses_each", 1.0),
		create(&"fall_2_active_usage", &"localized_focus", "Aktiver Einsatz", "Beide Aktivfähigkeiten mindestens viermal einsetzen und gewinnen.", &"ability_uses_each", 4.0),
		create(&"fall_3_first_victory", &"severe_pneumonia", "Erster Erfolg", "Fall 6 gewinnen.", &"victory"),
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
