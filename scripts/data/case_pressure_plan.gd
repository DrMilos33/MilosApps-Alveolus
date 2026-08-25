class_name CasePressurePlan
extends Resource

## Authored, movement-independent schedule for one main-case pressure layer.
##
## The plan deliberately contains no content IDs or save-facing state. The
## integration layer translates a due target-focus event into the existing
## runtime spawn request and supplies intro/boss state to the director.

@export var target_focus_times: PackedFloat32Array = PackedFloat32Array()
@export var projectile_gate_times: PackedFloat32Array = PackedFloat32Array()
@export_range(0, 64, 1) var max_active_targets: int = 0
@export_range(0.0, 4.0, 0.01) var target_movement_speed_multiplier: float = 1.0
@export_range(0.01, 4.0, 0.01) var target_attack_speed_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.01) var target_projectile_width_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.01) var target_projectile_speed_multiplier: float = 1.0
@export var target_projectiles_enabled: bool = true
@export var defense_burst_shooting_lock_seconds: float = EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS
@export_range(0.01, 100.0, 0.01) var target_health_multiplier: float = 1.0
@export var target_visual_id: StringName = &""
@export_range(0.5, 2.0, 0.01) var target_visual_scale: float = 1.0
@export_range(0, 16, 1) var symbolic_health_bar_count: int = 0
@export_range(0.01, 100.0, 0.01) var treatment_line_damage_multiplier: float = 1.0
@export var treatment_line_coverage_scaled: bool = false


static func create(
	target_times: PackedFloat32Array,
	gate_times: PackedFloat32Array,
	active_target_limit: int
) -> CasePressurePlan:
	var plan := CasePressurePlan.new()
	plan.target_focus_times = _normalized_times(target_times)
	plan.projectile_gate_times = _normalized_times(gate_times)
	plan.max_active_targets = maxi(active_target_limit, 0)
	return plan


func configure_target_combat(
	movement_speed_multiplier: float,
	attack_speed_multiplier: float,
	projectile_width_multiplier: float,
	projectile_speed_multiplier: float = 1.0,
	shooting_lock_seconds: float = EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS,
	projectiles_enabled: bool = true
) -> CasePressurePlan:
	target_movement_speed_multiplier = maxf(movement_speed_multiplier, 0.0)
	target_attack_speed_multiplier = maxf(attack_speed_multiplier, 0.01)
	target_projectile_width_multiplier = maxf(projectile_width_multiplier, 0.1)
	target_projectile_speed_multiplier = maxf(projectile_speed_multiplier, 0.1)
	defense_burst_shooting_lock_seconds = shooting_lock_seconds
	target_projectiles_enabled = projectiles_enabled
	return self


func configure_target_presentation(
	visual_id: StringName,
	health_multiplier: float,
	health_bar_count: int,
	line_damage_multiplier: float,
	coverage_scaled: bool = false,
	visual_scale: float = 1.0
) -> CasePressurePlan:
	target_visual_id = visual_id
	target_health_multiplier = maxf(health_multiplier, 0.01)
	symbolic_health_bar_count = clampi(health_bar_count, 0, 16)
	treatment_line_damage_multiplier = maxf(line_damage_multiplier, 0.01)
	treatment_line_coverage_scaled = coverage_scaled
	target_visual_scale = clampf(visual_scale, 0.5, 2.0)
	return self


static func default_for_case_order(case_order: int) -> CasePressurePlan:
	match case_order:
		1:
			return create(
				PackedFloat32Array([60.0, 120.0]),
				PackedFloat32Array(),
				1
			).configure_target_combat(66.0 / 42.0, 1.875, 1.5, 1.95)
		2:
			return create(
				PackedFloat32Array([25.0, 60.0, 95.0, 130.0]),
				PackedFloat32Array(),
				2
			).configure_target_combat(2.0, 1.0, 1.0, 1.0, EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS, false
			).configure_target_presentation(&"bacterial_swarm", 20.0 / 3.0, 1, 20.0, true, 1.12)
		3:
			return create(
				PackedFloat32Array([22.5, 60.0, 97.5, 135.0]),
				PackedFloat32Array(),
				1
			)
		4:
			return create(
				PackedFloat32Array([20.0, 60.0, 100.0, 140.0]),
				PackedFloat32Array(),
				1
			)
		5:
			return create(
				PackedFloat32Array([20.0, 60.0, 100.0, 140.0]),
				PackedFloat32Array([65.0, 105.0]),
				1
			)
		6:
			return create(
				PackedFloat32Array([20.0, 60.0, 100.0, 140.0]),
				PackedFloat32Array([45.0, 85.0, 125.0]),
				1
			)
	return create(PackedFloat32Array(), PackedFloat32Array(), 0)


static func _normalized_times(authored_times: PackedFloat32Array) -> PackedFloat32Array:
	var sorted_times := authored_times.duplicate()
	sorted_times.sort()
	var normalized := PackedFloat32Array()
	for scheduled_time in sorted_times:
		if not is_finite(scheduled_time) or scheduled_time < 0.0:
			continue
		if not normalized.is_empty() and is_equal_approx(normalized[-1], scheduled_time):
			continue
		normalized.append(scheduled_time)
	return normalized
