class_name ResistanceProfile
extends Resource

const MIN_RESISTANCE := -1.0
const MAX_RESISTANCE := 0.95

@export var id: StringName
@export var values: PackedFloat32Array = PackedFloat32Array()


static func from_components(profile_id: StringName, components: Dictionary = {}) -> ResistanceProfile:
	var profile := ResistanceProfile.new()
	profile.id = profile_id
	profile.values.resize(DamageTypeCatalog.count())
	profile.values.fill(0.0)
	for type_id_value in components:
		var type_index := DamageTypeCatalog.index_of(StringName(str(type_id_value)))
		if type_index < 0:
			continue
		profile.values[type_index] = clampf(float(components[type_id_value]), MIN_RESISTANCE, MAX_RESISTANCE)
	return profile


static func neutral(profile_id: StringName = &"neutral") -> ResistanceProfile:
	return from_components(profile_id)


func is_valid() -> bool:
	return id != &"" and values.size() == DamageTypeCatalog.count()


func resistance_at(type_index: int) -> float:
	return float(values[type_index]) if type_index >= 0 and type_index < values.size() else 0.0


func resistance_for_type(type_id: StringName) -> float:
	return resistance_at(DamageTypeCatalog.index_of(type_id))


func is_neutral() -> bool:
	for value in values:
		if not is_zero_approx(value):
			return false
	return true
