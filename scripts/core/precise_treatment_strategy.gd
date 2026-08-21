class_name PreciseTreatmentStrategy
extends TreatmentStrategy

func create_shots(origin: Vector2, facing: Vector2, candidates: Array, topology: ArenaTopology, definition: TreatmentDefinition, build: RunBuildState, effect_resolver: Object = null, manual_aim: bool = false) -> Array[TreatmentShot]:
	var result: Array[TreatmentShot] = []
	var max_range := build.value(RunBuildState.TREATMENT_RANGE, definition.base_range, definition.tags)
	var damage := build.value(RunBuildState.TREATMENT_DAMAGE, definition.base_damage, definition.tags)
	var projectile_count := maxi(1, roundi(build.value(RunBuildState.TREATMENT_PROJECTILES, float(definition.base_projectiles), definition.tags)))
	if manual_aim:
		var heading := normalized_facing(facing)
		for _index in range(projectile_count):
			var shot := TreatmentShot.directional(
				origin,
				heading,
				damage_at(damage, topology.wrap_position(origin + heading * max_range), effect_resolver),
				max_range,
				definition.id
			)
			shot.resolve_node_snapshot(candidates, topology)
			if not shot.resolved_targets.is_empty():
				shot.damage = damage_at(damage, (shot.resolved_targets[0] as Node2D).global_position, effect_resolver)
			result.append(shot)
		return result
	var ranked := ranked_targets(origin, candidates, topology, max_range, effect_resolver, projectile_count)
	for index in range(mini(projectile_count, ranked.size())):
		var enemy: Node2D = ranked[index].enemy
		result.append(TreatmentShot.tracking(origin, enemy, damage_at(damage, enemy.global_position, effect_resolver), max_range, definition.id))
	return result
