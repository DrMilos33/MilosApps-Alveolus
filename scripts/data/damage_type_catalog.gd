class_name DamageTypeCatalog
extends RefCounted

## The numeric order is a runtime contract. Profiles compile their authoring
## dictionaries into this fixed seven-value layout so resolving a hit performs
## no dictionary lookups or temporary allocations.
enum Type {
	FIRE,
	WATER,
	EARTH,
	WIND,
	BLOOD,
	HOLY,
	UNDEAD,
	COUNT,
}

const ALL_IDS: Array[StringName] = [
	&"fire",
	&"water",
	&"earth",
	&"wind",
	&"blood",
	&"holy",
	&"undead",
]


static func definitions() -> Array[DamageTypeDefinition]:
	return [
		DamageTypeDefinition.create(&"fire", "Feuer", Type.FIRE),
		DamageTypeDefinition.create(&"water", "Wasser", Type.WATER),
		DamageTypeDefinition.create(&"earth", "Erde", Type.EARTH),
		DamageTypeDefinition.create(&"wind", "Wind", Type.WIND),
		DamageTypeDefinition.create(&"blood", "Blut", Type.BLOOD),
		DamageTypeDefinition.create(&"holy", "Holy", Type.HOLY),
		DamageTypeDefinition.create(&"undead", "Undead", Type.UNDEAD),
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
		&"blood": return Type.BLOOD
		&"holy": return Type.HOLY
		&"undead": return Type.UNDEAD
	return -1


static func id_at(type_index: int) -> StringName:
	return ALL_IDS[type_index] if type_index >= 0 and type_index < ALL_IDS.size() else &""


static func display_name(id: StringName) -> String:
	match id:
		&"fire": return "Feuer"
		&"water": return "Wasser"
		&"earth": return "Erde"
		&"wind": return "Wind"
		&"blood": return "Blut"
		&"holy": return "Holy"
		&"undead": return "Undead"
	return "Unbekannt"
