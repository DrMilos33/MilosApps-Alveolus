class_name ResistanceProfile
extends Resource

@export var id: StringName
@export var ratings: PackedFloat32Array = PackedFloat32Array()
@export var effective_percentages: PackedFloat32Array = PackedFloat32Array()
@export var multipliers: PackedFloat32Array = PackedFloat32Array()
@export var validation_errors: PackedStringArray = PackedStringArray()


static func from_components(profile_id: StringName, components: Dictionary = {}) -> ResistanceProfile:
	return _compile(profile_id, components, false)


static func from_legacy_authoring_components(profile_id: StringName, components: Dictionary = {}) -> ResistanceProfile:
	return _compile(profile_id, components, true)


static func _compile(profile_id: StringName, components: Dictionary, canonicalize_legacy: bool) -> ResistanceProfile:
	var profile := ResistanceProfile.new()
	profile.id = profile_id
	profile.ratings.resize(DamageTypeCatalog.count())
	profile.ratings.fill(0.0)
	for type_id_value in components:
		var type_id := StringName(str(type_id_value))
		if canonicalize_legacy:
			type_id = DamageTypeCatalog.canonicalize_legacy_authoring_id(type_id)
		var type_index := DamageTypeCatalog.index_of(type_id)
		if type_index < 0:
			profile.validation_errors.append("unknown_damage_type:%s" % String(type_id_value))
			continue
		profile.ratings[type_index] = maxf(float(components[type_id_value]), MitigationCurve.MIN_RESISTANCE_RATING)
	profile._compile_effective_values()
	return profile


static func neutral(profile_id: StringName = &"neutral") -> ResistanceProfile:
	return from_components(profile_id)


func is_valid() -> bool:
	return (
		id != &""
		and validation_errors.is_empty()
		and ratings.size() == DamageTypeCatalog.count()
		and effective_percentages.size() == DamageTypeCatalog.count()
		and multipliers.size() == DamageTypeCatalog.count()
	)


func rating_at(type_index: int) -> float:
	return float(ratings[type_index]) if type_index >= 0 and type_index < ratings.size() else 0.0


func rating_for_type(type_id: StringName) -> float:
	return rating_at(DamageTypeCatalog.index_of(type_id))


func effective_percent_at(type_index: int) -> float:
	return float(effective_percentages[type_index]) if type_index >= 0 and type_index < effective_percentages.size() else 0.0


func effective_percent_for_type(type_id: StringName) -> float:
	return effective_percent_at(DamageTypeCatalog.index_of(type_id))


func multiplier_at(type_index: int) -> float:
	return float(multipliers[type_index]) if type_index >= 0 and type_index < multipliers.size() else 1.0


func is_neutral() -> bool:
	for value in ratings:
		if not is_zero_approx(value):
			return false
	return true


func _compile_effective_values() -> void:
	effective_percentages.resize(DamageTypeCatalog.count())
	multipliers.resize(DamageTypeCatalog.count())
	for type_index in range(DamageTypeCatalog.count()):
		var rating := float(ratings[type_index])
		effective_percentages[type_index] = MitigationCurve.resistance_effective_percent(rating)
		multipliers[type_index] = MitigationCurve.resistance_multiplier(rating)
