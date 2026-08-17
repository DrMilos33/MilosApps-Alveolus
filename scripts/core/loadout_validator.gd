class_name LoadoutValidator
extends RefCounted

const DEFAULT_CAPACITY := 8
const MAX_COMPONENTS := 5
const MAX_ACTIVE_ABILITIES := 2

static func validate(
	loadout: PreparedLoadout,
	definitions: Dictionary,
	unlocked_ids: Dictionary = {},
	capacity: int = DEFAULT_CAPACITY
) -> LoadoutValidationResult:
	var errors := PackedStringArray()
	if loadout == null:
		errors.append("Kein Behandlungsplan gewählt.")
		return LoadoutValidationResult.create(errors, 0, maxi(0, capacity))

	if loadout.treatment_id == &"":
		errors.append("Genau eine Grundbehandlung ist erforderlich.")
	if loadout.ability_ids.size() > MAX_ACTIVE_ABILITIES:
		errors.append("Es sind höchstens zwei aktive Fähigkeiten erlaubt.")
	if loadout.slot_count() > MAX_COMPONENTS:
		errors.append("Der Plan darf höchstens fünf aktive Komponenten enthalten.")

	var seen: Dictionary = {}
	var capacity_used := 0
	_validate_component(loadout.treatment_id, &"treatment", definitions, unlocked_ids, seen, errors)
	capacity_used += _capacity_cost(loadout.treatment_id, definitions)
	for id in loadout.ability_ids:
		_validate_component(id, &"ability", definitions, unlocked_ids, seen, errors)
		capacity_used += _capacity_cost(id, definitions)
	for id in loadout.passive_ids:
		_validate_component(id, &"passive", definitions, unlocked_ids, seen, errors)
		capacity_used += _capacity_cost(id, definitions)
	if loadout.reserve_id != &"":
		_validate_component(loadout.reserve_id, &"passive", definitions, unlocked_ids, seen, errors)

	var safe_capacity := maxi(0, capacity)
	if capacity_used > safe_capacity:
		errors.append("Der Plan benötigt %d von %d Kapazität." % [capacity_used, safe_capacity])
	return LoadoutValidationResult.create(errors, capacity_used, safe_capacity)

static func validate_reserve_swap(
	loadout: PreparedLoadout,
	outgoing_passive_id: StringName,
	definitions: Dictionary,
	unlocked_ids: Dictionary = {},
	capacity: int = DEFAULT_CAPACITY
) -> LoadoutValidationResult:
	if loadout == null:
		return validate(loadout, definitions, unlocked_ids, capacity)
	var swapped := loadout.duplicate_loadout()
	var outgoing_index := swapped.passive_ids.find(outgoing_passive_id)
	if swapped.reserve_id == &"" or outgoing_index < 0:
		var errors := PackedStringArray(["Für den Wechsel müssen Reserve und aktives Modul gewählt sein."])
		return LoadoutValidationResult.create(errors, 0, maxi(0, capacity))
	var incoming_id := swapped.reserve_id
	swapped.passive_ids[outgoing_index] = incoming_id
	swapped.reserve_id = outgoing_passive_id
	return validate(swapped, definitions, unlocked_ids, capacity)

static func apply_reserve_swap(loadout: PreparedLoadout, outgoing_passive_id: StringName) -> PreparedLoadout:
	if loadout == null:
		return null
	var swapped := loadout.duplicate_loadout()
	var outgoing_index := swapped.passive_ids.find(outgoing_passive_id)
	if swapped.reserve_id == &"" or outgoing_index < 0:
		return swapped
	var incoming_id := swapped.reserve_id
	swapped.passive_ids[outgoing_index] = incoming_id
	swapped.reserve_id = outgoing_passive_id
	return swapped

static func _validate_component(
	id: StringName,
	expected_kind: StringName,
	definitions: Dictionary,
	unlocked_ids: Dictionary,
	seen: Dictionary,
	errors: PackedStringArray
) -> void:
	if id == &"":
		return
	if seen.has(id):
		errors.append("%s ist mehrfach im Plan enthalten." % String(id))
		return
	seen[id] = true
	if not definitions.has(id):
		errors.append("Unbekannte Komponente: %s." % String(id))
		return
	if not unlocked_ids.is_empty() and not bool(unlocked_ids.get(id, unlocked_ids.get(String(id), false))):
		errors.append("Noch nicht freigeschaltet: %s." % String(id))
	var actual_kind := _definition_kind(definitions[id])
	if actual_kind != expected_kind:
		errors.append("%s ist kein gültiger Platz für %s." % [String(id), String(expected_kind)])

static func _capacity_cost(id: StringName, definitions: Dictionary) -> int:
	if id == &"" or not definitions.has(id):
		return 0
	var definition: Variant = definitions[id]
	if definition is Dictionary:
		return maxi(0, int(definition.get("capacity_cost", 0)))
	if definition is Object:
		var value: Variant = definition.get("capacity_cost")
		return maxi(0, int(value))
	return 0

static func _definition_kind(definition: Variant) -> StringName:
	if definition is Dictionary:
		return _normalized_kind(definition.get("kind", definition.get("component_type", "")))
	if definition is Object:
		var value: Variant = definition.get("kind")
		if value == null:
			value = definition.get("component_type")
		return _normalized_kind(value)
	return &""

static func _normalized_kind(value: Variant) -> StringName:
	if typeof(value) == TYPE_INT:
		match int(value):
			LoadoutModuleDefinition.Kind.TREATMENT:
				return &"treatment"
			LoadoutModuleDefinition.Kind.ABILITY:
				return &"ability"
			LoadoutModuleDefinition.Kind.PASSIVE:
				return &"passive"
	return StringName(str(value).to_lower())
