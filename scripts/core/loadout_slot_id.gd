class_name LoadoutSlotId
extends RefCounted

const TREATMENT: StringName = &"treatment"
const ACTIVE_1: StringName = &"active_1"
const ACTIVE_2: StringName = &"active_2"
const PASSIVE_1: StringName = &"passive_1"
const PASSIVE_2: StringName = &"passive_2"
const RESERVE: StringName = &"reserve"


static func all() -> Array[StringName]:
	return [TREATMENT, ACTIVE_1, ACTIVE_2, PASSIVE_1, PASSIVE_2, RESERVE]


static func active() -> Array[StringName]:
	return [TREATMENT, ACTIVE_1, ACTIVE_2, PASSIVE_1, PASSIVE_2]


## Slots exposed by the current preparation milestone. Passive slot IDs remain
## part of the save schema, but are deliberately absent from the playable UI.
static func planning() -> Array[StringName]:
	return [TREATMENT, ACTIVE_1, ACTIVE_2]


static func abilities() -> Array[StringName]:
	return [ACTIVE_1, ACTIVE_2]


static func passives(include_reserve: bool = false) -> Array[StringName]:
	var result: Array[StringName] = [PASSIVE_1, PASSIVE_2]
	if include_reserve:
		result.append(RESERVE)
	return result


static func is_valid(slot_id: StringName) -> bool:
	return all().has(slot_id)


static func expected_kind(slot_id: StringName) -> StringName:
	match slot_id:
		TREATMENT:
			return &"treatment"
		ACTIVE_1, ACTIVE_2:
			return &"ability"
		PASSIVE_1, PASSIVE_2, RESERVE:
			return &"passive"
	return &""


static func default_equip_slots(component_kind: StringName) -> Array[StringName]:
	match component_kind:
		&"treatment":
			return [TREATMENT]
		&"ability":
			return abilities()
		&"passive":
			# Reserve is deliberately separate. A catalog click must never silently
			# turn an active module into the held reserve.
			return passives(false)
	return []


static func counts_towards_capacity(slot_id: StringName) -> bool:
	return active().has(slot_id)
