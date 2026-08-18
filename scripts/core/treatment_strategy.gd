class_name TreatmentStrategy
extends RefCounted

func create_shots(
	origin: Vector2,
	facing: Vector2,
	candidates: Array,
	topology: ArenaTopology,
	definition: TreatmentDefinition,
	build: RunBuildState,
	effect_resolver: Object = null,
	manual_aim: bool = false
) -> Array[TreatmentShot]:
	return []

func normalized_facing(facing: Vector2) -> Vector2:
	return facing.normalized() if facing.length_squared() > 0.0001 else Vector2.RIGHT

func ranked_targets(
	origin: Vector2,
	candidates: Array,
	topology: ArenaTopology,
	max_range: float,
	effect_resolver: Object = null,
	limit: int = 1
) -> Array:
	var ranked: Array[Dictionary] = []
	var maximum_results := maxi(1, limit)
	for enemy in candidates:
		if not is_instance_valid(enemy) or not enemy.has_method("is_targetable") or not enemy.is_targetable():
			continue
		var center_distance := sqrt(topology.distance_squared(origin, enemy.global_position))
		var body_radius := maxf(float(enemy.definition.radius), 0.0) if enemy.definition != null else 0.0
		var surface_distance := maxf(0.0, center_distance - body_radius)
		if surface_distance > max_range:
			continue
		var priority_bonus := 0.0
		if effect_resolver != null and effect_resolver.has_method("treatment_target_priority_bonus"):
			priority_bonus = float(effect_resolver.treatment_target_priority_bonus(enemy.global_position))
		var score := surface_distance * surface_distance - priority_bonus
		var insertion_index := 0
		while insertion_index < ranked.size() and float(ranked[insertion_index].score) <= score:
			insertion_index += 1
		if insertion_index >= maximum_results:
			continue
		ranked.insert(insertion_index, {"enemy": enemy, "score": score})
		if ranked.size() > maximum_results:
			ranked.resize(maximum_results)
	return ranked

func damage_at(amount: float, position: Vector2, effect_resolver: Object) -> float:
	if effect_resolver != null and effect_resolver.has_method("treatment_damage_multiplier"):
		return amount * float(effect_resolver.treatment_damage_multiplier(position))
	return amount
