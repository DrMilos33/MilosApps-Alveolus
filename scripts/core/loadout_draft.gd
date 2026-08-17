class_name LoadoutDraft
extends RefCounted

var _slots: Dictionary = {}
var _definitions: Dictionary = {}
var _unlocked_ids: Dictionary = {}
var _capacity_limit: int = LoadoutValidator.DEFAULT_CAPACITY


static func create_empty(
	definitions: Dictionary,
	unlocked_ids: Dictionary = {},
	capacity: int = LoadoutValidator.DEFAULT_CAPACITY
) -> LoadoutDraft:
	var draft := LoadoutDraft.new()
	draft._definitions = definitions
	draft._unlocked_ids = unlocked_ids
	draft._capacity_limit = maxi(0, capacity)
	for slot_id in LoadoutSlotId.all():
		draft._slots[slot_id] = &""
	return draft


static func from_prepared(
	loadout: PreparedLoadout,
	definitions: Dictionary,
	unlocked_ids: Dictionary = {},
	capacity: int = LoadoutValidator.DEFAULT_CAPACITY
) -> LoadoutDraft:
	var draft := create_empty(definitions, unlocked_ids, capacity)
	if loadout == null:
		return draft
	draft._slots[LoadoutSlotId.TREATMENT] = loadout.treatment_id
	if loadout.ability_ids.size() > 0:
		draft._slots[LoadoutSlotId.ACTIVE_1] = loadout.ability_ids[0]
	if loadout.ability_ids.size() > 1:
		draft._slots[LoadoutSlotId.ACTIVE_2] = loadout.ability_ids[1]
	if loadout.passive_ids.size() > 0:
		draft._slots[LoadoutSlotId.PASSIVE_1] = loadout.passive_ids[0]
	if loadout.passive_ids.size() > 1:
		draft._slots[LoadoutSlotId.PASSIVE_2] = loadout.passive_ids[1]
	draft._slots[LoadoutSlotId.RESERVE] = loadout.reserve_id
	return draft


static func from_slots(
	slots: Dictionary,
	definitions: Dictionary,
	unlocked_ids: Dictionary = {},
	capacity: int = LoadoutValidator.DEFAULT_CAPACITY
) -> LoadoutDraft:
	var draft := create_empty(definitions, unlocked_ids, capacity)
	for slot_id in LoadoutSlotId.all():
		var raw_value: Variant = slots.get(slot_id, slots.get(String(slot_id), ""))
		draft._slots[slot_id] = StringName(str(raw_value))
	return draft


func duplicate_draft() -> LoadoutDraft:
	return from_slots(_slots, _definitions, _unlocked_ids, _capacity_limit)


func component_at(slot_id: StringName) -> StringName:
	if not LoadoutSlotId.is_valid(slot_id):
		return &""
	return StringName(_slots.get(slot_id, &""))


func slot_for_component(component_id: StringName) -> StringName:
	if component_id == &"":
		return &""
	for slot_id in LoadoutSlotId.all():
		if component_at(slot_id) == component_id:
			return slot_id
	return &""


func slot_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for slot_id in LoadoutSlotId.all():
		result[slot_id] = component_at(slot_id)
	return result


func to_prepared() -> PreparedLoadout:
	var abilities: Array[StringName] = []
	for slot_id in LoadoutSlotId.abilities():
		var component_id := component_at(slot_id)
		if component_id != &"":
			abilities.append(component_id)
	var passives: Array[StringName] = []
	for slot_id in LoadoutSlotId.passives(false):
		var component_id := component_at(slot_id)
		if component_id != &"":
			passives.append(component_id)
	return PreparedLoadout.create(
		component_at(LoadoutSlotId.TREATMENT),
		abilities,
		passives,
		component_at(LoadoutSlotId.RESERVE)
	)


func validate() -> LoadoutValidationResult:
	return LoadoutValidator.validate(to_prepared(), _definitions, _unlocked_ids, _capacity_limit)


func capacity_limit() -> int:
	return _capacity_limit


func capacity_used() -> int:
	return validate().capacity_used


func equip(component_id: StringName, preferred_slot: StringName = &"") -> LoadoutChangeResult:
	var before := capacity_used()
	if component_id == &"":
		return _invalid("Keine Komponente gewählt.", before, before)
	var existing_slot := slot_for_component(component_id)
	if existing_slot != &"":
		return _noop(LoadoutChangeResult.ALREADY_EQUIPPED, component_id, existing_slot, before)
	var component_kind := _definition_kind(component_id)
	if component_kind == &"":
		return _invalid("Unbekannte Komponente: %s." % String(component_id), before, before, component_id)

	var eligible_slots := LoadoutSlotId.default_equip_slots(component_kind)
	if preferred_slot != &"":
		if not LoadoutSlotId.is_valid(preferred_slot):
			return _invalid("Unbekannter Planplatz: %s." % String(preferred_slot), before, before, component_id)
		if LoadoutSlotId.expected_kind(preferred_slot) != component_kind:
			return _invalid("Die Komponente passt nicht in diesen Planplatz.", before, before, component_id, preferred_slot)
		eligible_slots = [preferred_slot]

	for slot_id in eligible_slots:
		if component_at(slot_id) == &"":
			return _apply_component(component_id, slot_id, &"", before)

	return _replacement_required(component_id, eligible_slots, before)


func replace(component_id: StringName, target_slot: StringName) -> LoadoutChangeResult:
	var before := capacity_used()
	if not LoadoutSlotId.is_valid(target_slot):
		return _invalid("Unbekannter Planplatz: %s." % String(target_slot), before, before, component_id)
	if component_id == &"":
		return _invalid("Keine Komponente gewählt.", before, before, component_id, target_slot)
	var existing_slot := slot_for_component(component_id)
	if existing_slot != &"":
		return _noop(LoadoutChangeResult.ALREADY_EQUIPPED, component_id, existing_slot, before)
	var component_kind := _definition_kind(component_id)
	if component_kind == &"":
		return _invalid("Unbekannte Komponente: %s." % String(component_id), before, before, component_id, target_slot)
	if LoadoutSlotId.expected_kind(target_slot) != component_kind:
		return _invalid("Die Komponente passt nicht in diesen Planplatz.", before, before, component_id, target_slot)
	return _apply_component(component_id, target_slot, component_at(target_slot), before)


func confirm_replacement(component_id: StringName, target_slot: StringName) -> LoadoutChangeResult:
	return replace(component_id, target_slot)


func remove(slot_id: StringName) -> LoadoutChangeResult:
	var before := capacity_used()
	if not LoadoutSlotId.is_valid(slot_id):
		return _invalid("Unbekannter Planplatz: %s." % String(slot_id), before, before)
	if slot_id == LoadoutSlotId.TREATMENT:
		return _invalid("Die Grundbehandlung kann nur ersetzt werden.", before, before, component_at(slot_id), slot_id)
	var outgoing_id := component_at(slot_id)
	if outgoing_id == &"":
		return _noop(LoadoutChangeResult.NO_CHANGE, &"", slot_id, before)
	var candidate := duplicate_draft()
	candidate._slots[slot_id] = &""
	return _commit_candidate(candidate, outgoing_id, slot_id, outgoing_id, before)


func swap_slots(first_slot: StringName, second_slot: StringName) -> LoadoutChangeResult:
	var before := capacity_used()
	if not LoadoutSlotId.is_valid(first_slot) or not LoadoutSlotId.is_valid(second_slot):
		return _invalid("Mindestens ein Planplatz ist unbekannt.", before, before)
	if first_slot == second_slot:
		return _noop(LoadoutChangeResult.NO_CHANGE, component_at(first_slot), first_slot, before)
	if LoadoutSlotId.expected_kind(first_slot) != LoadoutSlotId.expected_kind(second_slot):
		return _invalid("Nur gleichartige Planplätze können getauscht werden.", before, before)
	var first_id := component_at(first_slot)
	var second_id := component_at(second_slot)
	if first_id == second_id:
		return _noop(LoadoutChangeResult.NO_CHANGE, first_id, first_slot, before)
	var candidate := duplicate_draft()
	candidate._slots[first_slot] = second_id
	candidate._slots[second_slot] = first_id
	var result := _commit_candidate(candidate, second_id, first_slot, first_id, before)
	result.secondary_slot = second_slot
	return result


func _apply_component(
	component_id: StringName,
	target_slot: StringName,
	displaced_id: StringName,
	before: int
) -> LoadoutChangeResult:
	var candidate := duplicate_draft()
	candidate._slots[target_slot] = component_id
	return _commit_candidate(candidate, component_id, target_slot, displaced_id, before)


func _commit_candidate(
	candidate: LoadoutDraft,
	component_id: StringName,
	target_slot: StringName,
	displaced_id: StringName,
	before: int
) -> LoadoutChangeResult:
	var validation_result := candidate.validate()
	if not validation_result.valid:
		var failed := LoadoutChangeResult.new()
		failed.status = LoadoutChangeResult.INVALID
		failed.component_id = component_id
		failed.target_slot = target_slot
		failed.displaced_component_id = displaced_id
		failed.errors = validation_result.errors.duplicate()
		failed.capacity_before = before
		failed.capacity_after = validation_result.capacity_used
		failed.capacity_delta = failed.capacity_after - before
		failed.snapshot = slot_snapshot()
		failed.validation = validation_result
		return failed
	_slots = candidate._slots.duplicate()
	var result := LoadoutChangeResult.new()
	result.status = LoadoutChangeResult.APPLIED
	result.applied = true
	result.component_id = component_id
	result.target_slot = target_slot
	result.displaced_component_id = displaced_id
	result.capacity_before = before
	result.capacity_after = validation_result.capacity_used
	result.capacity_delta = result.capacity_after - before
	result.snapshot = slot_snapshot()
	result.validation = validation_result
	return result


func _replacement_required(
	component_id: StringName,
	eligible_slots: Array[StringName],
	before: int
) -> LoadoutChangeResult:
	var result := LoadoutChangeResult.new()
	result.status = LoadoutChangeResult.REQUIRES_REPLACEMENT
	result.component_id = component_id
	result.replacement_slots = eligible_slots.duplicate()
	result.capacity_before = before
	result.capacity_after = before
	result.snapshot = slot_snapshot()
	return result


func _noop(
	status: StringName,
	component_id: StringName,
	focus_slot: StringName,
	before: int
) -> LoadoutChangeResult:
	var result := LoadoutChangeResult.new()
	result.status = status
	result.component_id = component_id
	result.focus_slot = focus_slot
	result.capacity_before = before
	result.capacity_after = before
	result.snapshot = slot_snapshot()
	return result


func _invalid(
	message: String,
	before: int,
	after: int,
	component_id: StringName = &"",
	target_slot: StringName = &""
) -> LoadoutChangeResult:
	var result := LoadoutChangeResult.new()
	result.status = LoadoutChangeResult.INVALID
	result.component_id = component_id
	result.target_slot = target_slot
	result.errors = PackedStringArray([message])
	result.capacity_before = before
	result.capacity_after = after
	result.capacity_delta = after - before
	result.snapshot = slot_snapshot()
	return result


func _definition_kind(component_id: StringName) -> StringName:
	var definition: Variant = _definition_for(component_id)
	if definition == null:
		return &""
	var raw_kind: Variant
	if definition is Dictionary:
		raw_kind = definition.get("kind", definition.get("component_type", ""))
	elif definition is Object:
		raw_kind = definition.get("kind")
		if raw_kind == null:
			raw_kind = definition.get("component_type")
	else:
		return &""
	if typeof(raw_kind) == TYPE_INT:
		match int(raw_kind):
			LoadoutModuleDefinition.Kind.TREATMENT:
				return &"treatment"
			LoadoutModuleDefinition.Kind.ABILITY:
				return &"ability"
			LoadoutModuleDefinition.Kind.PASSIVE:
				return &"passive"
	return StringName(str(raw_kind).to_lower())


func _definition_for(component_id: StringName) -> Variant:
	if _definitions.has(component_id):
		return _definitions[component_id]
	var text_id := String(component_id)
	if _definitions.has(text_id):
		return _definitions[text_id]
	return null

