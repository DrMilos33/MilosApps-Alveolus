class_name LoadoutSlotSaveAdapter
extends RefCounted

const META_SAVE_VERSION := 5
const SLOT_SCHEMA_VERSION := 1


static func serialize_loadout(loadout: PreparedLoadout) -> Dictionary:
	var safe_loadout := loadout if loadout != null else PreparedLoadout.new()
	var slots := LoadoutDraft.from_prepared(safe_loadout, {}).slot_snapshot()
	var serialized_slots: Dictionary = {}
	for slot_id in LoadoutSlotId.all():
		serialized_slots[String(slot_id)] = String(slots.get(slot_id, &""))
	return {
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slots": serialized_slots,
	}


static func serialize_draft(draft: LoadoutDraft) -> Dictionary:
	return serialize_loadout(draft.to_prepared() if draft != null else null)


static func deserialize_loadout(payload: Dictionary) -> PreparedLoadout:
	if _is_slot_payload(payload):
		var slots_value: Variant = payload.get("slots", {})
		if typeof(slots_value) == TYPE_DICTIONARY:
			return _prepared_from_slots(slots_value)
	# Save-v4 embedded loadout representation.
	return PreparedLoadout.from_dict(payload)


static func deserialize_draft(
	payload: Dictionary,
	definitions: Dictionary,
	unlocked_ids: Dictionary = {},
	capacity: int = LoadoutValidator.DEFAULT_CAPACITY
) -> LoadoutDraft:
	return LoadoutDraft.from_prepared(
		deserialize_loadout(payload),
		definitions,
		unlocked_ids,
		capacity
	)


static func migrate_v4_loadout(payload: Dictionary) -> Dictionary:
	return serialize_loadout(PreparedLoadout.from_dict(payload))


static func migrate_v4_save(save_data: Dictionary) -> Dictionary:
	var migrated := save_data.duplicate(true)
	if int(migrated.get("version", -1)) != 4:
		return migrated
	migrated["version"] = META_SAVE_VERSION
	var source_loadouts: Variant = migrated.get("prepared_loadouts", {})
	var serialized_loadouts: Dictionary = {}
	if typeof(source_loadouts) == TYPE_DICTIONARY:
		for level_id in source_loadouts:
			var raw_loadout: Variant = source_loadouts[level_id]
			if typeof(raw_loadout) == TYPE_DICTIONARY:
				serialized_loadouts[String(level_id)] = migrate_v4_loadout(raw_loadout)
	migrated["prepared_loadouts"] = serialized_loadouts
	return migrated


static func deserialize_prepared_loadouts(serialized: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(serialized) != TYPE_DICTIONARY:
		return result
	for level_id in serialized:
		var payload: Variant = serialized[level_id]
		if typeof(payload) == TYPE_DICTIONARY:
			result[StringName(str(level_id))] = deserialize_loadout(payload)
	return result


static func _prepared_from_slots(slots: Dictionary) -> PreparedLoadout:
	var ability_ids: Array[StringName] = []
	for slot_id in LoadoutSlotId.abilities():
		var ability_id := _slot_value(slots, slot_id)
		if ability_id != &"":
			ability_ids.append(ability_id)
	var passive_ids: Array[StringName] = []
	for slot_id in LoadoutSlotId.passives(false):
		var passive_id := _slot_value(slots, slot_id)
		if passive_id != &"":
			passive_ids.append(passive_id)
	return PreparedLoadout.create(
		_slot_value(slots, LoadoutSlotId.TREATMENT),
		ability_ids,
		passive_ids,
		_slot_value(slots, LoadoutSlotId.RESERVE)
	)


static func _slot_value(slots: Dictionary, slot_id: StringName) -> StringName:
	return StringName(str(slots.get(slot_id, slots.get(String(slot_id), ""))))


static func _is_slot_payload(payload: Dictionary) -> bool:
	return int(payload.get("slot_schema_version", 0)) == SLOT_SCHEMA_VERSION and typeof(payload.get("slots", null)) == TYPE_DICTIONARY
