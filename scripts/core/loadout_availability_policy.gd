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
const FIRST_CASE_LEVEL_ID := &"localized_focus"
const SECOND_ACTIVE_SLOT_ID := &"active_2"
const TREATMENT_LINE_ID := &"ability_treatment_line"
const TREATMENT_LINE_RESEARCH_ID := &"unlock_treatment_line"
const TREATMENT_LINE_MILESTONE_COPY := "Wird nach Abschluss von Fall 1 freigeschaltet."


## `first_case_complete` is deliberately a derived progression fact instead of
## another saved ownership bit. Keeping it optional preserves every existing
## caller while allowing Game to pass the authoritative LevelRecord milestone.
static func selectable_ids(
	definitions: Dictionary = {},
	research_ranks: Dictionary = {},
	first_case_complete: bool = false
) -> Dictionary:
	var result: Dictionary = {}
	for id in [&"treatment_precision"]:
		if definitions.is_empty() or definitions.has(id):
			result[id] = true
	for id in [&"treatment_spread", &"treatment_pierce"]:
		if not definitions.is_empty() and not definitions.has(id):
			continue
		var research_id := &"unlock_spread_treatment" if id == &"treatment_spread" else &"unlock_piercing_treatment"
		if int(research_ranks.get(research_id, 0)) > 0:
			result[id] = true
	for id in AVAILABLE_ABILITY_IDS:
		if not definitions.is_empty() and not definitions.has(id):
			continue
		if id == TREATMENT_LINE_ID:
			if first_case_complete:
				result[id] = true
			continue
		var research_id := &"unlock_defense_burst"
		if int(research_ranks.get(research_id, 0)) > 0:
			result[id] = true
	return result


static func is_selectable(id: StringName) -> bool:
	return AVAILABLE_TREATMENT_IDS.has(id) or AVAILABLE_ABILITY_IDS.has(id)


static func unavailable_reason(
	id: StringName,
	definitions: Dictionary = {},
	research_ranks: Dictionary = {},
	first_case_complete: bool = false
) -> String:
	if bool(selectable_ids(definitions, research_ranks, first_case_complete).get(id, false)):
		return ""
	if id == TREATMENT_LINE_ID:
		return TREATMENT_LINE_MILESTONE_COPY
	if id == &"treatment_spread" or id == &"treatment_pierce":
		return "Erfordert die passende Forschung"
	if AVAILABLE_ABILITY_IDS.has(id):
		return "Erfordert die passende Forschung"
	var definition: Variant = definitions.get(id, null)
	if definition is LoadoutModuleDefinition and definition.kind == LoadoutModuleDefinition.Kind.PASSIVE:
		return "Passivmodule vorerst pausiert"
	return "Für später vorgemerkt"


static func research_status(
	definition: ResearchDefinition,
	definitions: Dictionary = {},
	first_case_complete: bool = false
) -> String:
	if definition == null:
		return "Derzeit nicht verfügbar"
	if definition.id == TREATMENT_LINE_RESEARCH_ID:
		return "Nach Abschluss von Fall 1 freigeschaltet" if first_case_complete else TREATMENT_LINE_MILESTONE_COPY
	if is_selectable(definition.unlock_module_id):
		return "Im aktuellen Testkatalog enthalten"
	if definition.unlock_module_id != &"":
		return unavailable_reason(definition.unlock_module_id, definitions)
	return "Dauerhafter Forschungsbonus"


static func research_purchase_enabled(definition: ResearchDefinition, _first_case_complete: bool = false) -> bool:
	return definition != null and definition.id != TREATMENT_LINE_RESEARCH_ID


## Presentation helpers keep the milestone node out of raw research ownership.
## A legacy stored rank remains untouched/refundable, but no longer bypasses the
## case milestone and is never required to represent its completed state.
static func research_effective_rank(
	definition: ResearchDefinition,
	stored_rank: int,
	first_case_complete: bool = false
) -> int:
	if definition == null:
		return 0
	if definition.id == TREATMENT_LINE_RESEARCH_ID:
		return definition.max_level if first_case_complete else 0
	return clampi(stored_rank, 0, definition.max_level)


static func research_icon_kind(definition: ResearchDefinition, first_case_complete: bool = false) -> StringName:
	if definition == null:
		return &"question"
	if definition.id == TREATMENT_LINE_RESEARCH_ID and not first_case_complete:
		return &"question"
	return definition.id


static func active_ability_slot_limit(first_case_complete: bool = false) -> int:
	return LoadoutValidator.MAX_ACTIVE_ABILITIES if first_case_complete else 1


static func slot_is_available(slot_id: StringName, first_case_complete: bool = false) -> bool:
	return slot_id != SECOND_ACTIVE_SLOT_ID or first_case_complete


static func slot_unavailable_reason(slot_id: StringName, first_case_complete: bool = false) -> String:
	return "" if slot_is_available(slot_id, first_case_complete) else TREATMENT_LINE_MILESTONE_COPY


static func sanitized_copy(
	loadout: PreparedLoadout,
	definitions: Dictionary = {},
	research_ranks: Dictionary = {},
	first_case_complete: bool = false
) -> PreparedLoadout:
	if loadout == null:
		loadout = PreparedLoadout.default_loadout()
	var available := selectable_ids(definitions, research_ranks, first_case_complete)
	var treatment_id := PreparedLoadout.DEFAULT_TREATMENT_ID
	if _valid_id_for_kind(loadout.treatment_id, LoadoutModuleDefinition.Kind.TREATMENT, definitions) and bool(available.get(loadout.treatment_id, false)):
		treatment_id = loadout.treatment_id

	var ability_ids: Array[StringName] = []
	for id in loadout.ability_ids:
		if bool(available.get(id, false)) and AVAILABLE_ABILITY_IDS.has(id) and not ability_ids.has(id) and _valid_id_for_kind(id, LoadoutModuleDefinition.Kind.ABILITY, definitions):
			ability_ids.append(id)
			if ability_ids.size() >= active_ability_slot_limit(first_case_complete):
				break

	return PreparedLoadout.create(treatment_id, ability_ids, [], &"")


static func _valid_id_for_kind(id: StringName, expected_kind: int, definitions: Dictionary) -> bool:
	if id == &"":
		return false
	if definitions.is_empty():
		return true
	var definition: Variant = definitions.get(id, null)
	return definition is LoadoutModuleDefinition and definition.kind == expected_kind
