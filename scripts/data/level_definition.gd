class_name LevelDefinition
extends Resource

const DEFAULT_SPAWN_CADENCE_DELAY := 0.30

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
@export var spawn_ramp_seconds: float = 300.0
@export_range(0, 64, 1) var initial_small_enemy_count: int = 3
@export_range(0, 64, 1) var initial_cluster_enemy_count: int = 0
@export var automatic_boss_enabled: bool = true
@export_range(0.0, 0.9, 0.01) var spawn_cadence_delay: float = DEFAULT_SPAWN_CADENCE_DELAY
@export var enemy_health_start: float
@export var enemy_health_end: float
@export var enemy_speed_multiplier: float
@export var contact_damage_multiplier: float
@export var cluster_chance_start: float
@export var cluster_chance_end: float
@export var boss_health_multiplier: float
@export var boss_speed_multiplier: float = 1.0
@export var boss_enemy_id: StringName = &"infection_focus"
@export var boss_ranged_enabled: bool = false
@export var boss_projectile_damage_multiplier: float = 1.0
@export var boss_projectile_attack_speed_multiplier: float = 1.0
@export var boss_projectile_speed_multiplier: float = 1.0
@export var boss_projectiles_require_empty_aura: bool = false
@export var boss_wave_amplitude: float = 44.0
@export var boss_phase_minions: PackedInt32Array
@export_range(0.0, 2.0, 0.01) var boss_aura_screen_diameter_fraction: float = 0.0
@export var boss_aura_speed_multiplier: float = 1.0
@export var boss_aura_damage_multiplier: float = 1.0
@export var boss_reinforcement_interval: float = 0.0
@export_range(0, 64, 1) var boss_reinforcement_count: int = 0
@export_range(0, 2, 1) var boss_reinforcement_minimum_phase: int = 0
@export var boss_add_defense_burst_shooting_lock_seconds: float = EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS
@export var boss_add_projectile_attack_speed_multiplier: float = 1.0
@export var reward_multiplier: float
@export_multiline var briefing_text: String
@export_multiline var victory_text: String
@export_multiline var failure_text: String
@export var visible_trait_ids: Array[StringName] = []
@export var hidden_finding_ids: Array[StringName] = []
@export var finding_progress_target: int = 0
@export var case_pressure_targets_stationary: bool = false
@export var case_pressure_target_health_multiplier: float = 1.0
## Optional authored pressure schedule. Runtime configuration receives its own
## deep copy so a run cannot mutate the catalog definition.
@export var case_pressure_plan: CasePressurePlan

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


func configure_case_pressure(plan: CasePressurePlan) -> LevelDefinition:
	case_pressure_plan = plan.duplicate(true) as CasePressurePlan if plan != null else null
	return self


func configure_spawn_cadence(delay_strength: float) -> LevelDefinition:
	spawn_cadence_delay = clampf(delay_strength, 0.0, 0.9)
	return self


func configure_runtime(
	initial_small_count: int,
	initial_cluster_count: int = 0,
	ramp_seconds: float = 300.0,
	automatic_boss: bool = true
) -> LevelDefinition:
	initial_small_enemy_count = maxi(initial_small_count, 0)
	initial_cluster_enemy_count = maxi(initial_cluster_count, 0)
	spawn_ramp_seconds = maxf(ramp_seconds, 0.0)
	automatic_boss_enabled = automatic_boss
	return self


func configure_case_pressure_targets(stationary: bool, health_multiplier: float = 1.0) -> LevelDefinition:
	case_pressure_targets_stationary = stationary
	case_pressure_target_health_multiplier = maxf(health_multiplier, 0.01)
	return self


func configure_boss_behavior(speed_multiplier: float) -> LevelDefinition:
	boss_speed_multiplier = maxf(speed_multiplier, 0.0)
	return self


func configure_boss_aura(
	screen_diameter_fraction: float,
	movement_multiplier: float,
	damage_multiplier: float
) -> LevelDefinition:
	boss_aura_screen_diameter_fraction = clampf(screen_diameter_fraction, 0.0, 2.0)
	boss_aura_speed_multiplier = maxf(movement_multiplier, 0.0)
	boss_aura_damage_multiplier = maxf(damage_multiplier, 0.0)
	return self


func configure_boss_reinforcements(
	interval_seconds: float,
	count: int,
	minimum_phase: int = 0
) -> LevelDefinition:
	boss_reinforcement_interval = maxf(interval_seconds, 0.0)
	boss_reinforcement_count = maxi(count, 0)
	boss_reinforcement_minimum_phase = clampi(minimum_phase, 0, 2)
	return self


func configure_boss_projectile_contract(
	attack_speed_multiplier: float,
	add_shooting_lock_seconds: float = EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS,
	projectile_speed_multiplier: float = 1.0,
	require_empty_aura: bool = false,
	add_attack_speed_multiplier: float = 1.0
) -> LevelDefinition:
	boss_projectile_attack_speed_multiplier = maxf(attack_speed_multiplier, 0.01)
	boss_add_defense_burst_shooting_lock_seconds = add_shooting_lock_seconds
	boss_projectile_speed_multiplier = maxf(projectile_speed_multiplier, 0.1)
	boss_projectiles_require_empty_aura = require_empty_aura
	boss_add_projectile_attack_speed_multiplier = maxf(add_attack_speed_multiplier, 0.01)
	return self

func configure_boss(
	enemy_id: StringName,
	ranged_enabled: bool,
	projectile_damage_multiplier: float = 1.0,
	wave_amplitude: float = 44.0
) -> LevelDefinition:
	boss_enemy_id = enemy_id if enemy_id != &"" else &"infection_focus"
	boss_ranged_enabled = ranged_enabled
	boss_projectile_damage_multiplier = maxf(projectile_damage_multiplier, 0.0)
	boss_wave_amplitude = maxf(wave_amplitude, 0.0)
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
