class_name CombatCapacity
extends RefCounted

## Central, explicit limits for the combat runtime. Simulation limits and
## purely visual limits are deliberately separate so load shedding can never
## change damage, cooldowns, rewards, or spawn RNG.

const DEFAULT_MAX_ENEMIES := 640
const DEFAULT_REGULAR_ENEMIES := 600
const DEFAULT_CRITICAL_RESERVE := 40
const DEFAULT_PICKUP_STACKS := 360
const DEFAULT_PROJECTILE_STATES := 512
const DEFAULT_PROJECTILE_VISUALS := 512
const DEFAULT_FEEDBACK_VISUALS := 80

var max_enemies: int = DEFAULT_MAX_ENEMIES
var max_regular_enemies: int = DEFAULT_REGULAR_ENEMIES
var critical_enemy_reserve: int = DEFAULT_CRITICAL_RESERVE
var max_pickup_stacks: int = DEFAULT_PICKUP_STACKS
var max_projectile_states: int = DEFAULT_PROJECTILE_STATES
var max_projectile_visuals: int = DEFAULT_PROJECTILE_VISUALS
var max_feedback_visuals: int = DEFAULT_FEEDBACK_VISUALS

static func defaults() -> CombatCapacity:
	return CombatCapacity.new()

func configure(
	enemy_limit: int = DEFAULT_MAX_ENEMIES,
	regular_enemy_limit: int = DEFAULT_REGULAR_ENEMIES,
	pickup_limit: int = DEFAULT_PICKUP_STACKS,
	projectile_state_limit: int = DEFAULT_PROJECTILE_STATES,
	projectile_visual_limit: int = DEFAULT_PROJECTILE_VISUALS,
	feedback_visual_limit: int = DEFAULT_FEEDBACK_VISUALS
) -> CombatCapacity:
	max_enemies = maxi(1, enemy_limit)
	max_regular_enemies = clampi(regular_enemy_limit, 0, max_enemies)
	critical_enemy_reserve = max_enemies - max_regular_enemies
	max_pickup_stacks = maxi(1, pickup_limit)
	max_projectile_states = maxi(1, projectile_state_limit)
	max_projectile_visuals = clampi(projectile_visual_limit, 0, max_projectile_states)
	max_feedback_visuals = maxi(0, feedback_visual_limit)
	return self

func can_allocate_enemy(active_regular: int, active_critical: int, critical: bool = false) -> bool:
	var regular := maxi(active_regular, 0)
	var reserved := maxi(active_critical, 0)
	if regular + reserved >= max_enemies:
		return false
	if critical:
		return true
	return regular < max_regular_enemies

func available_enemy_slots(active_regular: int, active_critical: int, critical: bool = false) -> int:
	var total_available := maxi(0, max_enemies - maxi(active_regular, 0) - maxi(active_critical, 0))
	if critical:
		return total_available
	return mini(total_available, maxi(0, max_regular_enemies - maxi(active_regular, 0)))

func is_valid() -> bool:
	return (
		max_enemies > 0
		and max_regular_enemies >= 0
		and max_regular_enemies <= max_enemies
		and critical_enemy_reserve == max_enemies - max_regular_enemies
		and max_pickup_stacks > 0
		and max_projectile_states > 0
		and max_projectile_visuals >= 0
		and max_projectile_visuals <= max_projectile_states
		and max_feedback_visuals >= 0
	)

func to_dictionary() -> Dictionary:
	return {
		"max_enemies": max_enemies,
		"max_regular_enemies": max_regular_enemies,
		"critical_enemy_reserve": critical_enemy_reserve,
		"max_pickup_stacks": max_pickup_stacks,
		"max_projectile_states": max_projectile_states,
		"max_projectile_visuals": max_projectile_visuals,
		"max_feedback_visuals": max_feedback_visuals,
	}
