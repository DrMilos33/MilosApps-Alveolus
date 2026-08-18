class_name DamageTypeCatalog
extends RefCounted

## The numeric order is a runtime contract. Profiles compile their authoring
## dictionaries into this fixed four-value layout so resolving a hit performs
## no dictionary lookups or temporary allocations.
enum Type {
	FIRE,
	WATER,
	EARTH,
	WIND,
	COUNT,
}

const ALL_IDS: Array[StringName] = [
	&"fire",
	&"water",
	&"earth",
	&"wind",
]

const RETIRED_LEGACY_IDS: Array[StringName] = [&"blood", &"holy", &"undead"]


static func definitions() -> Array[DamageTypeDefinition]:
	return [
		DamageTypeDefinition.create(&"fire", "Feuer", Type.FIRE),
		DamageTypeDefinition.create(&"water", "Wasser", Type.WATER),
		DamageTypeDefinition.create(&"earth", "Erde", Type.EARTH),
		DamageTypeDefinition.create(&"wind", "Wind", Type.WIND),
	]


static func catalog() -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions():
		result[definition.id] = definition
	return result


static func count() -> int:
	return Type.COUNT


static func is_valid_id(id: StringName) -> bool:
	return index_of(id) >= 0


static func index_of(id: StringName) -> int:
	match id:
		&"fire": return Type.FIRE
		&"water": return Type.WATER
		&"earth": return Type.EARTH
		&"wind": return Type.WIND
	return -1


static func id_at(type_index: int) -> StringName:
	return ALL_IDS[type_index] if type_index >= 0 and type_index < ALL_IDS.size() else &""


static func display_name(id: StringName) -> String:
	match id:
		&"fire": return "Feuer"
		&"water": return "Wasser"
		&"earth": return "Erde"
		&"wind": return "Wind"
	return "Unbekannt"


static func is_retired_legacy_id(id: StringName) -> bool:
	return RETIRED_LEGACY_IDS.has(id)


static func canonicalize_legacy_authoring_id(id: StringName) -> StringName:
	## This is deliberately not part of index_of(). New authoring data must use
	## one of the four active IDs; only explicit legacy import paths may call it.
	match id:
		&"blood": return &"fire"
		&"holy": return &"water"
		&"undead": return &"wind"
	return id
