class_name LevelDefinition
extends Resource

@export var id: StringName
@export var order: int
@export var title: String
@export var subtitle: String
@export var is_tutorial: bool
@export var total_seconds: float
@export var boss_spawn_seconds: float
@export var initial_stability: float
@export var initial_spawn_interval: float
@export var final_spawn_interval: float
@export var enemy_health_start: float
@export var enemy_health_end: float
@export var enemy_speed_multiplier: float
@export var contact_damage_multiplier: float
@export var cluster_chance_start: float
@export var cluster_chance_end: float
@export var boss_health_multiplier: float
@export var boss_speed_multiplier: float = 1.0
@export var boss_phase_minions: PackedInt32Array
@export var reward_multiplier: float
@export_multiline var briefing_text: String
@export_multiline var victory_text: String
@export_multiline var failure_text: String
@export var visible_trait_ids: Array[StringName] = []
@export var hidden_finding_ids: Array[StringName] = []
@export var finding_progress_target: int = 0

static func create(
	level_id: StringName,
	level_order: int,
	display_title: String,
	display_subtitle: String,
	tutorial: bool,
	duration: float,
	boss_time: float,
	stability: float,
	spawn_start: float,
	spawn_end: float,
	health_start: float,
	health_end: float,
	speed_multiplier: float,
	damage_multiplier: float,
	cluster_start: float,
	cluster_end: float,
	boss_multiplier: float,
	phase_minions: PackedInt32Array,
	research_multiplier: float,
	briefing: String,
	victory: String,
	failure: String
) -> LevelDefinition:
	var definition := LevelDefinition.new()
	definition.id = level_id
	definition.order = level_order
	definition.title = display_title
	definition.subtitle = display_subtitle
	definition.is_tutorial = tutorial
	definition.total_seconds = duration
	definition.boss_spawn_seconds = boss_time
	definition.initial_stability = stability
	definition.initial_spawn_interval = spawn_start
	definition.final_spawn_interval = spawn_end
	definition.enemy_health_start = health_start
	definition.enemy_health_end = health_end
	definition.enemy_speed_multiplier = speed_multiplier
	definition.contact_damage_multiplier = damage_multiplier
	definition.cluster_chance_start = cluster_start
	definition.cluster_chance_end = cluster_end
	definition.boss_health_multiplier = boss_multiplier
	definition.boss_phase_minions = phase_minions
	definition.reward_multiplier = research_multiplier
	definition.briefing_text = briefing
	definition.victory_text = victory
	definition.failure_text = failure
	return definition

func configure_case_variation(
	traits: Array[StringName],
	findings: Array[StringName],
	finding_target: int
) -> LevelDefinition:
	visible_trait_ids = traits.duplicate()
	hidden_finding_ids = findings.duplicate()
	finding_progress_target = maxi(0, finding_target)
	return self


func configure_boss_behavior(speed_multiplier: float) -> LevelDefinition:
	boss_speed_multiplier = maxf(speed_multiplier, 0.0)
	return self

func duration_text() -> String:
	if is_tutorial:
		return "∞"
	if not has_deadline():
		return "Ohne Zeitlimit"
	return _time_text(total_seconds)

func has_deadline() -> bool:
	return total_seconds > 0.0

func boss_time_text() -> String:
	if is_tutorial:
		return "nach Lektion 3"
	return _time_text(boss_spawn_seconds)

func _time_text(value: float) -> String:
	var seconds := floori(value)
	return "%d:%02d Min." % [seconds / 60, seconds % 60]
