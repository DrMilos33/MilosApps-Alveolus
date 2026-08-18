class_name DamageProfile
extends Resource

@export var id: StringName
@export var weights: PackedFloat32Array = PackedFloat32Array()
@export var validation_errors: PackedStringArray = PackedStringArray()


static func from_components(profile_id: StringName, components: Dictionary) -> DamageProfile:
	return _compile(profile_id, components, false)


static func from_legacy_authoring_components(profile_id: StringName, components: Dictionary) -> DamageProfile:
	return _compile(profile_id, components, true)


static func _compile(profile_id: StringName, components: Dictionary, canonicalize_legacy: bool) -> DamageProfile:
	var profile := DamageProfile.new()
	profile.id = profile_id
	profile.weights.resize(DamageTypeCatalog.count())
	profile.weights.fill(0.0)
	var total := 0.0
	for type_id_value in components:
		var type_id := StringName(str(type_id_value))
		if canonicalize_legacy:
			type_id = DamageTypeCatalog.canonicalize_legacy_authoring_id(type_id)
		var type_index := DamageTypeCatalog.index_of(type_id)
		if type_index < 0:
			profile.validation_errors.append("unknown_damage_type:%s" % String(type_id_value))
			continue
		var weight := maxf(float(components[type_id_value]), 0.0)
		profile.weights[type_index] += weight
		total += weight
	if total > 0.0:
		for type_index in range(profile.weights.size()):
			profile.weights[type_index] /= total
	return profile


static func single(profile_id: StringName, type_id: StringName) -> DamageProfile:
	return from_components(profile_id, {type_id: 1.0})


func is_valid() -> bool:
	if id == &"" or not validation_errors.is_empty() or weights.size() != DamageTypeCatalog.count():
		return false
	var total := 0.0
	for weight in weights:
		if weight < 0.0:
			return false
		total += weight
	return is_equal_approx(total, 1.0)


func weight_at(type_index: int) -> float:
	return float(weights[type_index]) if type_index >= 0 and type_index < weights.size() else 0.0


func weight_for_type(type_id: StringName) -> float:
	return weight_at(DamageTypeCatalog.index_of(type_id))


func dominant_type_id() -> StringName:
	var best_index := -1
	var best_weight := 0.0
	for type_index in range(weights.size()):
		var weight := float(weights[type_index])
		if weight > best_weight:
			best_weight = weight
			best_index = type_index
	return DamageTypeCatalog.id_at(best_index)
