class_name PiercingTreatmentStrategy
extends TreatmentStrategy

func create_shots(origin: Vector2, facing: Vector2, candidates: Array, topology: ArenaTopology, definition: TreatmentDefinition, build: RunBuildState, effect_resolver: Object = null) -> Array[TreatmentShot]:
	var result: Array[TreatmentShot] = []
	var max_range := build.value(RunBuildState.TREATMENT_RANGE, definition.base_range, definition.tags)
	var damage := build.value(RunBuildState.TREATMENT_DAMAGE, definition.base_damage, definition.tags)
	var hit_limit := maxi(1, roundi(build.value(RunBuildState.TREATMENT_MAX_HITS, float(definition.max_hits), definition.tags)))
	var ranked := ranked_targets(origin, candidates, topology, max_range, effect_resolver)
	if ranked.is_empty():
		return result
	var primary: Node2D = ranked[0].enemy
	var heading := topology.shortest_delta(origin, primary.global_position).normalized()
	result.append(TreatmentShot.line(origin, heading, damage_at(damage, primary.global_position, effect_resolver), max_range, hit_limit, definition.id))
	return result

