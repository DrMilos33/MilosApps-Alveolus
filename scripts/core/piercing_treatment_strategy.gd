class_name PiercingTreatmentStrategy
extends TreatmentStrategy

func create_shots(origin: Vector2, facing: Vector2, candidates: Array, topology: ArenaTopology, definition: TreatmentDefinition, build: RunBuildState, effect_resolver: Object = null, manual_aim: bool = false) -> Array[TreatmentShot]:
	var result: Array[TreatmentShot] = []
	var max_range := build.value(RunBuildState.TREATMENT_RANGE, definition.base_range, definition.tags)
	var damage := build.value(RunBuildState.TREATMENT_DAMAGE, definition.base_damage, definition.tags)
	var hit_limit := maxi(1, roundi(build.value(RunBuildState.TREATMENT_MAX_HITS, float(definition.max_hits), definition.tags)))
	var heading := normalized_facing(facing)
	var damage_position := topology.wrap_position(origin + heading * max_range)
	if not manual_aim:
		var ranked := ranked_targets(origin, candidates, topology, max_range, effect_resolver)
		if ranked.is_empty():
			return result
		var primary: Node2D = ranked[0].enemy
		heading = normalized_facing(topology.shortest_delta(origin, primary.global_position))
		damage_position = primary.global_position
	var shot := TreatmentShot.line(origin, heading, damage_at(damage, damage_position, effect_resolver), max_range, hit_limit, definition.id)
	shot.resolve_node_snapshot(candidates, topology)
	if not shot.resolved_targets.is_empty():
		shot.damage = damage_at(damage, (shot.resolved_targets[0] as Node2D).global_position, effect_resolver)
	result.append(shot)
	return result
