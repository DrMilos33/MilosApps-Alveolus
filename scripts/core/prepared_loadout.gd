class_name PreparedLoadout
extends RefCounted

const DEFAULT_TREATMENT_ID := &"treatment_precision"
const DEFAULT_ABILITY_IDS: Array[StringName] = [&"ability_focus_field", &"ability_emergency_support"]

var treatment_id: StringName = &""
var ability_ids: Array[StringName] = []
var passive_ids: Array[StringName] = []
var reserve_id: StringName = &""

static func create(
	base_treatment_id: StringName,
	active_ability_ids: Array[StringName] = [],
	active_passive_ids: Array[StringName] = [],
	reserve_passive_id: StringName = &""
) -> PreparedLoadout:
	var loadout := PreparedLoadout.new()
	loadout.treatment_id = base_treatment_id
	loadout.ability_ids = active_ability_ids.duplicate()
	loadout.passive_ids = active_passive_ids.duplicate()
	loadout.reserve_id = reserve_passive_id
	return loadout

static func default_loadout(active_passive_ids: Array[StringName] = []) -> PreparedLoadout:
	return create(DEFAULT_TREATMENT_ID, DEFAULT_ABILITY_IDS, active_passive_ids)

func duplicate_loadout() -> PreparedLoadout:
	return create(treatment_id, ability_ids, passive_ids, reserve_id)

func active_component_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if treatment_id != &"":
		ids.append(treatment_id)
	ids.append_array(ability_ids)
	ids.append_array(passive_ids)
	return ids

func all_component_ids() -> Array[StringName]:
	var ids := active_component_ids()
	if reserve_id != &"":
		ids.append(reserve_id)
	return ids

func slot_count() -> int:
	return active_component_ids().size()

func has_component(id: StringName, include_reserve: bool = true) -> bool:
	if active_component_ids().has(id):
		return true
	return include_reserve and reserve_id == id

func to_dict() -> Dictionary:
	return {
		"treatment_id": String(treatment_id),
		"ability_ids": ability_ids.map(func(id: StringName) -> String: return String(id)),
		"passive_ids": passive_ids.map(func(id: StringName) -> String: return String(id)),
		"reserve_id": String(reserve_id),
	}

static func from_dict(data: Dictionary) -> PreparedLoadout:
	var loadout := PreparedLoadout.new()
	loadout.treatment_id = StringName(str(data.get("treatment_id", "")))
	loadout.ability_ids = _string_name_array(data.get("ability_ids", []))
	loadout.passive_ids = _string_name_array(data.get("passive_ids", []))
	loadout.reserve_id = StringName(str(data.get("reserve_id", "")))
	return loadout

static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_id in value:
		var id := StringName(str(raw_id))
		if id != &"":
			result.append(id)
	return result
