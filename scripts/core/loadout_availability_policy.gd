class_name LoadoutAvailabilityPolicy
extends RefCounted

## Temporary product-facing availability for the current combat-balancing
## milestone. Ownership through research remains intact and deliberately does
## not bypass this policy.

const AVAILABLE_TREATMENT_IDS: Array[StringName] = [
	&"treatment_precision",
	&"treatment_spread",
	&"treatment_pierce",
]
const AVAILABLE_ABILITY_IDS: Array[StringName] = [
	&"ability_defense_burst",
	&"ability_treatment_line",
]
static func selectable_ids(definitions: Dictionary = {}, research_ranks: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for id in [&"treatment_precision"] + AVAILABLE_ABILITY_IDS:
		if definitions.is_empty() or definitions.has(id):
			result[id] = true
	for id in [&"treatment_spread", &"treatment_pierce"]:
		if not definitions.is_empty() and not definitions.has(id):
			continue
		var research_id := &"unlock_spread_treatment" if id == &"treatment_spread" else &"unlock_piercing_treatment"
		if int(research_ranks.get(research_id, 0)) > 0:
			result[id] = true
	return result


static func is_selectable(id: StringName) -> bool:
	return AVAILABLE_TREATMENT_IDS.has(id) or AVAILABLE_ABILITY_IDS.has(id)


static func unavailable_reason(id: StringName, definitions: Dictionary = {}, research_ranks: Dictionary = {}) -> String:
	if bool(selectable_ids(definitions, research_ranks).get(id, false)):
		return ""
	if id == &"treatment_spread" or id == &"treatment_pierce":
		return "Erfordert die passende Forschung"
	var definition: Variant = definitions.get(id, null)
	if definition is LoadoutModuleDefinition and definition.kind == LoadoutModuleDefinition.Kind.PASSIVE:
		return "Passivmodule vorerst pausiert"
	return "Für später vorgemerkt"


static func research_status(definition: ResearchDefinition, definitions: Dictionary = {}) -> String:
	if definition == null:
		return "Derzeit nicht verfügbar"
	if is_selectable(definition.unlock_module_id):
		return "Im aktuellen Testkatalog enthalten"
	if definition.unlock_module_id != &"":
		return unavailable_reason(definition.unlock_module_id, definitions)
	return "Dauerhafter Forschungsbonus"


static func research_purchase_enabled(definition: ResearchDefinition) -> bool:
	return definition != null


static func sanitized_copy(loadout: PreparedLoadout, definitions: Dictionary = {}, research_ranks: Dictionary = {}) -> PreparedLoadout:
	if loadout == null:
		return PreparedLoadout.default_loadout()
	var available := selectable_ids(definitions, research_ranks)
	var treatment_id := PreparedLoadout.DEFAULT_TREATMENT_ID
	if _valid_id_for_kind(loadout.treatment_id, LoadoutModuleDefinition.Kind.TREATMENT, definitions) and bool(available.get(loadout.treatment_id, false)):
		treatment_id = loadout.treatment_id

	var ability_ids: Array[StringName] = []
	for id in loadout.ability_ids:
		if AVAILABLE_ABILITY_IDS.has(id) and not ability_ids.has(id) and _valid_id_for_kind(id, LoadoutModuleDefinition.Kind.ABILITY, definitions):
			ability_ids.append(id)
			if ability_ids.size() >= LoadoutValidator.MAX_ACTIVE_ABILITIES:
				break

	return PreparedLoadout.create(treatment_id, ability_ids, [], &"")


static func _valid_id_for_kind(id: StringName, expected_kind: int, definitions: Dictionary) -> bool:
	if id == &"":
		return false
	if definitions.is_empty():
		return true
	var definition: Variant = definitions.get(id, null)
	return definition is LoadoutModuleDefinition and definition.kind == expected_kind
