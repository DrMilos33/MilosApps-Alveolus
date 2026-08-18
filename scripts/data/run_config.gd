class_name RunConfig
extends Resource

@export var run_duration_seconds: float = 45.0
@export var final_deadline_seconds: float = 60.0
@export var initial_stability: float = 120.0
@export var arena_size: Vector2 = Vector2(2400.0, 1350.0)
@export var initial_spawn_interval: float = 1.10
@export var final_spawn_interval: float = 0.55
@export var random_seed: int = 20260809
@export var level_id: StringName = &"intro"
@export var enemy_health_start: float = 0.55
@export var enemy_health_end: float = 0.70
@export var enemy_speed_multiplier: float = 0.80
@export var contact_damage_multiplier: float = 0.50
@export var cluster_chance_start: float = 0.0
@export var cluster_chance_end: float = 0.05
@export var boss_health_multiplier: float = 0.18
@export var boss_phase_minions: PackedInt32Array = PackedInt32Array()
@export var reward_multiplier: float = 1.0
@export var event_driven_intro: bool = false
@export var enemy_resistance_effective_bonus: float = 0.0
@export var enemy_defense: float = 0.0
@export var boss_count: int = 1
@export var spawn_rate_multiplier: float = 1.0
@export var experience_gain_multiplier: float = 1.0

func arena_rect() -> Rect2:
	return Rect2(-arena_size * 0.5, arena_size)

func has_deadline() -> bool:
	return final_deadline_seconds > 0.0

static func from_level(level: LevelDefinition, quick_run: bool = false) -> RunConfig:
	var config := RunConfig.new()
	config.level_id = level.id
	config.run_duration_seconds = level.boss_spawn_seconds
	config.final_deadline_seconds = level.total_seconds
	config.initial_stability = level.initial_stability
	config.initial_spawn_interval = level.initial_spawn_interval
	config.final_spawn_interval = level.final_spawn_interval
	config.enemy_health_start = level.enemy_health_start
	config.enemy_health_end = level.enemy_health_end
	config.enemy_speed_multiplier = level.enemy_speed_multiplier
	config.contact_damage_multiplier = level.contact_damage_multiplier
	config.cluster_chance_start = level.cluster_chance_start
	config.cluster_chance_end = level.cluster_chance_end
	config.boss_health_multiplier = level.boss_health_multiplier
	config.boss_phase_minions = level.boss_phase_minions
	config.reward_multiplier = level.reward_multiplier
	config.random_seed += level.order * 101
	config.event_driven_intro = level.is_tutorial
	if quick_run:
		config.run_duration_seconds = 12.0
		config.final_deadline_seconds = 22.0
		config.initial_spawn_interval = 0.35
		config.final_spawn_interval = 0.12
		config.boss_health_multiplier = 0.20
	return config
