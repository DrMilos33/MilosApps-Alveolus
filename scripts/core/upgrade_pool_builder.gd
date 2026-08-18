class_name UpgradePoolBuilder
extends RefCounted

const PREPARED_WEIGHT := 3.0
const SYNERGY_WEIGHT := 2.0
const GENERAL_WEIGHT := 1.0

static func choose(
	definitions: Array[UpgradeDefinition],
	levels: Dictionary,
	rng: RandomNumberGenerator,
	prepared_component_ids: Array[StringName],
	prepared_tags: Array[StringName],
	count: int = 3,
	excluded_ids: Array[StringName] = [],
	guarantee_treatment: bool = false
) -> Array[UpgradeDefinition]:
	var candidates: Array[UpgradeDefinition] = []
	for definition in definitions:
		if int(levels.get(definition.id, 0)) >= definition.max_level:
			continue
		if excluded_ids.has(definition.id):
			continue
		if not _upgrade_requirements_met(definition, levels):
			continue
		if not _requirements_met(definition, prepared_component_ids):
			continue
		candidates.append(definition)
	if candidates.size() < count and not excluded_ids.is_empty():
		return choose(definitions, levels, rng, prepared_component_ids, prepared_tags, count, [], guarantee_treatment)

	var selected: Array[UpgradeDefinition] = []
	if guarantee_treatment:
		var prepared_treatment_id := &""
		for component_id in prepared_component_ids:
			if String(component_id).begins_with("treatment_"):
				prepared_treatment_id = component_id
				break
		var treatment_candidates := candidates.filter(func(item: UpgradeDefinition) -> bool:
			return prepared_treatment_id != &"" \
				and item.path == UpgradeDefinition.Path.ANTIBIOTIC \
				and item.required_component_ids.has(prepared_treatment_id)
		)
		if not treatment_candidates.is_empty():
			var guaranteed := _weighted_pick(treatment_candidates, rng, prepared_component_ids, prepared_tags)
			selected.append(guaranteed)
			candidates.erase(guaranteed)

	while selected.size() < count and not candidates.is_empty():
		var picked := _weighted_pick(candidates, rng, prepared_component_ids, prepared_tags)
		selected.append(picked)
		candidates.erase(picked)
	return selected

static func weight_for(definition: UpgradeDefinition, prepared_component_ids: Array[StringName], prepared_tags: Array[StringName]) -> float:
	if _matches_prepared(definition, prepared_component_ids):
		return PREPARED_WEIGHT
	for tag in definition.synergy_tags:
		if prepared_tags.has(tag):
			return SYNERGY_WEIGHT
	return GENERAL_WEIGHT

static func _weighted_pick(
	candidates: Array[UpgradeDefinition],
	rng: RandomNumberGenerator,
	prepared_component_ids: Array[StringName],
	prepared_tags: Array[StringName]
) -> UpgradeDefinition:
	var total := 0.0
	for definition in candidates:
		total += weight_for(definition, prepared_component_ids, prepared_tags)
	var cursor := rng.randf() * maxf(total, 0.001)
	for definition in candidates:
		cursor -= weight_for(definition, prepared_component_ids, prepared_tags)
		if cursor <= 0.0:
			return definition
	return candidates.back()

static func _requirements_met(definition: UpgradeDefinition, prepared_component_ids: Array[StringName]) -> bool:
	if definition.required_component_ids.is_empty():
		return true
	for required_id in definition.required_component_ids:
		if prepared_component_ids.has(required_id):
			return true
	return false

static func _upgrade_requirements_met(definition: UpgradeDefinition, levels: Dictionary) -> bool:
	for required_id in definition.required_upgrade_ids:
		if int(levels.get(required_id, 0)) <= 0:
			return false
	return true

static func _matches_prepared(definition: UpgradeDefinition, prepared_component_ids: Array[StringName]) -> bool:
	for component_id in definition.required_component_ids:
		if prepared_component_ids.has(component_id):
			return true
	return false
