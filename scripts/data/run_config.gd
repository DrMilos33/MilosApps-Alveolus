class_name RunConfig
extends Resource

const SPAWN_INTERVAL_CURVE_EXPONENT := 0.82

@export var run_duration_seconds: float = 45.0
@export var final_deadline_seconds: float = 60.0
@export var initial_stability: float = 120.0
@export var arena_size: Vector2 = Vector2(8640.0, 4860.0)
@export var initial_spawn_interval: float = 1.10
@export var final_spawn_interval: float = 0.55
@export var spawn_ramp_seconds: float = 300.0
@export var initial_small_enemy_count: int = 3
@export var initial_cluster_enemy_count: int = 0
@export var automatic_boss_enabled: bool = true
@export var regular_spawns_enabled: bool = true
@export_range(0, 600, 1) var regular_spawn_weight_cap: int = 145
@export_range(0.0, 0.9, 0.01) var spawn_cadence_delay: float = LevelDefinition.DEFAULT_SPAWN_CADENCE_DELAY
@export var random_seed: int = 20260809
@export var level_id: StringName = &"intro"
@export var enemy_health_start: float = 0.55
@export var enemy_health_end: float = 0.70
@export var enemy_speed_multiplier: float = 0.80
@export var contact_damage_multiplier: float = 0.50
@export var cluster_chance_start: float = 0.0
@export var cluster_chance_end: float = 0.05
@export var boss_health_multiplier: float = 0.18
@export var boss_speed_multiplier: float = 1.0
@export var boss_enemy_id: StringName = &"infection_focus"
@export var boss_ranged_enabled: bool = false
@export var boss_projectile_damage_multiplier: float = 1.0
@export var boss_wave_amplitude: float = 44.0
@export var boss_phase_minions: PackedInt32Array = PackedInt32Array()
@export_range(0.0, 1.0, 0.01) var boss_aura_screen_diameter_fraction: float = 0.0
@export var boss_aura_speed_multiplier: float = 1.0
@export var boss_aura_damage_multiplier: float = 1.0
@export var boss_reinforcement_interval: float = 0.0
@export var boss_reinforcement_count: int = 0
@export var boss_reinforcement_minimum_phase: int = 0
@export var reward_multiplier: float = 1.0
@export var event_driven_intro: bool = false
@export var enemy_resistance_effective_bonus: float = 0.0
@export var enemy_defense: float = 0.0
@export var boss_count: int = 1
@export var spawn_rate_multiplier: float = 1.0
@export var experience_gain_multiplier: float = 1.0
@export var case_pressure_targets_stationary: bool = false
@export var case_pressure_target_health_multiplier: float = 1.0
## A run owns a detached pressure plan; catalog resources remain immutable while
## gameplay consumes its deterministic schedule.
@export var case_pressure_plan: CasePressurePlan

func arena_rect() -> Rect2:
	return Rect2(-arena_size * 0.5, arena_size)

func has_deadline() -> bool:
	return final_deadline_seconds > 0.0


## Maps real run progress onto the authored density curve. A positive delay
## keeps early packets smaller and catches their density up smoothly near the
## boss horizon without changing health or group interpolation.
func regular_spawn_progress(elapsed_seconds: float) -> float:
	if spawn_ramp_seconds <= 0.0:
		return 0.0
	return delayed_spawn_progress(
		clampf(elapsed_seconds / spawn_ramp_seconds, 0.0, 1.0),
		spawn_cadence_delay
	)


func regular_spawn_interval(spawn_progress: float) -> float:
	var curved_progress := pow(clampf(spawn_progress, 0.0, 1.0), SPAWN_INTERVAL_CURVE_EXPONENT)
	var interval := lerpf(initial_spawn_interval, final_spawn_interval, curved_progress)
	return interval / maxf(spawn_rate_multiplier, 0.01)


static func delayed_spawn_progress(real_progress: float, delay_strength: float) -> float:
	var progress := clampf(real_progress, 0.0, 1.0)
	var delay := clampf(delay_strength, 0.0, 0.9)
	if delay <= 0.000001:
		return progress
	# real = legacy + delay * legacy * (1 - legacy). This stable form
	# evaluates the smaller inverse root without subtractive cancellation.
	var coefficient := 1.0 + delay
	var discriminant := maxf(coefficient * coefficient - 4.0 * delay * progress, 0.0)
	return clampf(2.0 * progress / (coefficient + sqrt(discriminant)), 0.0, 1.0)


static func from_level(level: LevelDefinition, quick_run: bool = false) -> RunConfig:
	var config := RunConfig.new()
	config.level_id = level.id
	config.run_duration_seconds = level.boss_spawn_seconds
	config.final_deadline_seconds = level.total_seconds
	config.initial_stability = level.initial_stability
	config.initial_spawn_interval = level.initial_spawn_interval
	config.final_spawn_interval = level.final_spawn_interval
	config.spawn_ramp_seconds = level.spawn_ramp_seconds
	config.initial_small_enemy_count = level.initial_small_enemy_count
	config.initial_cluster_enemy_count = level.initial_cluster_enemy_count
	config.automatic_boss_enabled = level.automatic_boss_enabled
	config.spawn_cadence_delay = level.spawn_cadence_delay
	config.enemy_health_start = level.enemy_health_start
	config.enemy_health_end = level.enemy_health_end
	config.enemy_speed_multiplier = level.enemy_speed_multiplier
	config.contact_damage_multiplier = level.contact_damage_multiplier
	config.cluster_chance_start = level.cluster_chance_start
	config.cluster_chance_end = level.cluster_chance_end
	config.boss_health_multiplier = level.boss_health_multiplier
	config.boss_speed_multiplier = level.boss_speed_multiplier
	config.boss_enemy_id = level.boss_enemy_id
	config.boss_ranged_enabled = level.boss_ranged_enabled
	config.boss_projectile_damage_multiplier = level.boss_projectile_damage_multiplier
	config.boss_wave_amplitude = level.boss_wave_amplitude
	config.boss_phase_minions = level.boss_phase_minions
	config.boss_aura_screen_diameter_fraction = level.boss_aura_screen_diameter_fraction
	config.boss_aura_speed_multiplier = level.boss_aura_speed_multiplier
	config.boss_aura_damage_multiplier = level.boss_aura_damage_multiplier
	config.boss_reinforcement_interval = level.boss_reinforcement_interval
	config.boss_reinforcement_count = level.boss_reinforcement_count
	config.boss_reinforcement_minimum_phase = level.boss_reinforcement_minimum_phase
	config.reward_multiplier = level.reward_multiplier
	config.case_pressure_plan = level.case_pressure_plan.duplicate(true) as CasePressurePlan if level.case_pressure_plan != null else null
	config.case_pressure_targets_stationary = level.case_pressure_targets_stationary
	config.case_pressure_target_health_multiplier = level.case_pressure_target_health_multiplier
	config.random_seed += level.order * 101
	config.event_driven_intro = level.is_tutorial
	if quick_run:
		config.run_duration_seconds = 12.0
		config.spawn_ramp_seconds = 12.0
		config.final_deadline_seconds = 22.0
		config.initial_spawn_interval = 0.35
		config.final_spawn_interval = 0.12
		config.boss_health_multiplier = 0.20
	return config
