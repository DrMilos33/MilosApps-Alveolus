class_name UpgradePoolBuilder
extends RefCounted

const PREPARED_WEIGHT := 3.0
const SYNERGY_WEIGHT := 2.0
const GENERAL_WEIGHT := 1.0
const COMMON_FREQUENCY := 1.0
const MAGIC_FREQUENCY := 25.0 / 70.0
const RARE_FREQUENCY := 5.0 / 70.0


static func choose(
	definitions: Array[UpgradeDefinition],
	levels: Dictionary,
	rng: RandomNumberGenerator,
	prepared_component_ids: Array[StringName],
	prepared_tags: Array[StringName],
	count: int = 3,
	excluded_ids: Array[StringName] = [],
	guarantee_treatment: bool = false,
	campaign_case_order: int = -1
) -> Array[UpgradeDefinition]:
	var prepared_treatment_id := _prepared_treatment_id(prepared_component_ids)
	var family_counts := _resolved_family_counts(definitions, levels, prepared_treatment_id)
	var excluded_families: Dictionary = {}
	for definition in definitions:
		if excluded_ids.has(definition.id):
			excluded_families[definition.resolved_family_key(prepared_treatment_id)] = true

	var candidates: Array[UpgradeDefinition] = []
	for definition in definitions:
		if campaign_case_order >= 0 and definition.minimum_case_order > campaign_case_order:
			continue
		var family_key := definition.resolved_family_key(prepared_treatment_id)
		var family_count := int(family_counts.get(family_key, 0))
		var variant_count := int(levels.get(definition.id, 0))
		if not definition.can_offer(family_count, variant_count):
			continue
		if excluded_families.has(family_key):
			continue
		if not _upgrade_requirements_met(definition, levels):
			continue
		if not _requirements_met(definition, prepared_component_ids):
			continue
		candidates.append(definition)
	if _unique_family_count(candidates, prepared_treatment_id) < count and not excluded_ids.is_empty():
		return choose(definitions, levels, rng, prepared_component_ids, prepared_tags, count, [], guarantee_treatment, campaign_case_order)

	var selected: Array[UpgradeDefinition] = []
	if guarantee_treatment and prepared_treatment_id != &"":
		var treatment_candidates: Array[UpgradeDefinition] = []
		for item in candidates:
			if item.path == UpgradeDefinition.Path.ANTIBIOTIC and item.required_component_ids.has(prepared_treatment_id):
				treatment_candidates.append(item)
		if not treatment_candidates.is_empty():
			var guaranteed := _weighted_family_pick(
				treatment_candidates,
				rng,
				prepared_component_ids,
				prepared_tags,
				family_counts,
				prepared_treatment_id
			)
			selected.append(guaranteed)
			_erase_family(candidates, guaranteed.resolved_family_key(prepared_treatment_id), prepared_treatment_id)

	while selected.size() < count and not candidates.is_empty():
		var picked := _weighted_family_pick(
			candidates,
			rng,
			prepared_component_ids,
			prepared_tags,
			family_counts,
			prepared_treatment_id
		)
		selected.append(picked)
		_erase_family(candidates, picked.resolved_family_key(prepared_treatment_id), prepared_treatment_id)
	return selected


static func weight_for(
	definition: UpgradeDefinition,
	prepared_component_ids: Array[StringName],
	prepared_tags: Array[StringName],
	family_pick_count: int = 0
) -> float:
	var result := GENERAL_WEIGHT
	if _matches_prepared(definition, prepared_component_ids):
		result = PREPARED_WEIGHT
	else:
		for tag in definition.synergy_tags:
			if prepared_tags.has(tag):
				result = SYNERGY_WEIGHT
				break
	return result * pow(definition.repeat_weight_decay, maxf(float(family_pick_count), 0.0))


static func _weighted_family_pick(
	candidates: Array[UpgradeDefinition],
	rng: RandomNumberGenerator,
	prepared_component_ids: Array[StringName],
	prepared_tags: Array[StringName],
	family_counts: Dictionary,
	prepared_treatment_id: StringName
) -> UpgradeDefinition:
	var family_keys: Array[StringName] = []
	var family_weights := PackedFloat32Array()
	var total := 0.0
	for definition in candidates:
		var family_key := definition.resolved_family_key(prepared_treatment_id)
		if family_keys.has(family_key):
			continue
		var family_weight := weight_for(
			definition,
			prepared_component_ids,
			prepared_tags,
			int(family_counts.get(family_key, 0))
		) * _family_rarity_frequency(candidates, family_key, prepared_treatment_id)
		family_keys.append(family_key)
		family_weights.append(family_weight)
		total += family_weight
	var cursor := rng.randf() * maxf(total, 0.001)
	var selected_family: StringName = family_keys.back()
	for index in range(family_keys.size()):
		cursor -= family_weights[index]
		if cursor <= 0.0:
			selected_family = family_keys[index]
			break
	return _weighted_rarity_pick(candidates, selected_family, rng, prepared_treatment_id)


static func _weighted_rarity_pick(
	candidates: Array[UpgradeDefinition],
	family_key: StringName,
	rng: RandomNumberGenerator,
	prepared_treatment_id: StringName
) -> UpgradeDefinition:
	var variants: Array[UpgradeDefinition] = []
	var total := 0.0
	for definition in candidates:
		if definition.resolved_family_key(prepared_treatment_id) != family_key:
			continue
		variants.append(definition)
		total += maxf(definition.rarity_weight, 0.001)
	var cursor := rng.randf() * maxf(total, 0.001)
	for definition in variants:
		cursor -= maxf(definition.rarity_weight, 0.001)
		if cursor <= 0.0:
			return definition
	return variants.back()


static func rarity_frequency(rarity: UpgradeDefinition.Rarity) -> float:
	match rarity:
		UpgradeDefinition.Rarity.MAGIC:
			return MAGIC_FREQUENCY
		UpgradeDefinition.Rarity.RARE:
			return RARE_FREQUENCY
	return COMMON_FREQUENCY


static func _family_rarity_frequency(
	candidates: Array[UpgradeDefinition],
	family_key: StringName,
	prepared_treatment_id: StringName
) -> float:
	# A complete Common/Magic/Rare family remains a normal offer family and
	# resolves its tier through rarity_weight. A singleton Magic or Rare family
	# is itself less common, so a rare-only projectile card cannot appear as
	# often as a common-only card.
	var frequency := 0.0
	for definition in candidates:
		if definition.resolved_family_key(prepared_treatment_id) == family_key:
			frequency = maxf(frequency, rarity_frequency(definition.rarity))
	return maxf(frequency, RARE_FREQUENCY)


static func _erase_family(
	candidates: Array[UpgradeDefinition],
	family_key: StringName,
	prepared_treatment_id: StringName
) -> void:
	for index in range(candidates.size() - 1, -1, -1):
		if candidates[index].resolved_family_key(prepared_treatment_id) == family_key:
			candidates.remove_at(index)


static func _resolved_family_counts(
	definitions: Array[UpgradeDefinition],
	levels: Dictionary,
	prepared_treatment_id: StringName
) -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions:
		var picks := maxi(0, int(levels.get(definition.id, 0)))
		if picks <= 0:
			continue
		var family_key := definition.resolved_family_key(prepared_treatment_id)
		result[family_key] = int(result.get(family_key, 0)) + picks
	return result


static func _unique_family_count(candidates: Array[UpgradeDefinition], prepared_treatment_id: StringName) -> int:
	var seen: Dictionary = {}
	for definition in candidates:
		seen[definition.resolved_family_key(prepared_treatment_id)] = true
	return seen.size()


static func _prepared_treatment_id(prepared_component_ids: Array[StringName]) -> StringName:
	for component_id in prepared_component_ids:
		if String(component_id).begins_with("treatment_"):
			return component_id
	return &""


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
