class_name PreciseTreatmentStrategy
extends TreatmentStrategy

func create_shots(origin: Vector2, facing: Vector2, candidates: Array, topology: ArenaTopology, definition: TreatmentDefinition, build: RunBuildState, effect_resolver: Object = null) -> Array[TreatmentShot]:
	var result: Array[TreatmentShot] = []
	var max_range := build.value(RunBuildState.TREATMENT_RANGE, definition.base_range, definition.tags)
	var damage := build.value(RunBuildState.TREATMENT_DAMAGE, definition.base_damage, definition.tags)
	var target_count := maxi(1, roundi(build.value(RunBuildState.TREATMENT_TARGETS, float(definition.base_targets), definition.tags)))
	var ranked := ranked_targets(origin, candidates, topology, max_range, effect_resolver, target_count)
	for index in range(mini(target_count, ranked.size())):
		var enemy: Node2D = ranked[index].enemy
		result.append(TreatmentShot.tracking(origin, enemy, damage_at(damage, enemy.global_position, effect_resolver), max_range, definition.id))
	return result
