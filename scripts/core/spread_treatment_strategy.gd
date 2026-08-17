class_name SpreadTreatmentStrategy
extends TreatmentStrategy

func create_shots(origin: Vector2, facing: Vector2, candidates: Array, topology: ArenaTopology, definition: TreatmentDefinition, build: RunBuildState, effect_resolver: Object = null) -> Array[TreatmentShot]:
	var result: Array[TreatmentShot] = []
	var max_range := build.value(RunBuildState.TREATMENT_RANGE, definition.base_range, definition.tags)
	var damage := build.value(RunBuildState.TREATMENT_DAMAGE, definition.base_damage, definition.tags)
	var projectile_count := maxi(1, roundi(build.value(RunBuildState.TREATMENT_PROJECTILES, float(definition.base_projectiles), definition.tags)))
	var spread_degrees := build.value(RunBuildState.TREATMENT_SPREAD, definition.spread_degrees, definition.tags)
	var ranked := ranked_targets(origin, candidates, topology, max_range, effect_resolver)
	if ranked.is_empty():
		return result
	var primary: Node2D = ranked[0].enemy
	var heading := topology.shortest_delta(origin, primary.global_position).normalized()
	if heading.length_squared() < 0.0001:
		heading = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.RIGHT
	var half := float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var angle_offset := deg_to_rad(spread_degrees) * (float(index) - half)
		result.append(TreatmentShot.line(origin, heading.rotated(angle_offset), damage_at(damage, primary.global_position, effect_resolver), max_range, 1, definition.id))
	return result
