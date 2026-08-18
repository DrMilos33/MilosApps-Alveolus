class_name CombatDistanceScale
extends RefCounted

const WORLD_POINTS_PER_STAGE := 30.0


static func stage_from_world(world_value: float) -> int:
	return maxi(0, roundi(maxf(world_value, 0.0) / WORLD_POINTS_PER_STAGE))


static func world_from_stage(stage: int) -> float:
	return float(maxi(stage, 0)) * WORLD_POINTS_PER_STAGE


static func quantize_world(world_value: float) -> float:
	return world_from_stage(stage_from_world(world_value))


static func is_staged_stat(stat_id: StringName) -> bool:
	return stat_id in [
		&"therapy_range",
		&"defense_cell_radius",
		&"ability_radius",
		&"ability_range",
		&"pickup_range",
	]
