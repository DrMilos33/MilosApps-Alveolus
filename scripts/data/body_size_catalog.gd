class_name BodySizeCatalog
extends RefCounted

enum SizeClass {
	SMALL,
	MEDIUM,
	LARGE,
	BOSS,
}

const IDS: Array[StringName] = [&"small", &"medium", &"large", &"boss"]
const REFERENCE_RADII: Array[float] = [18.0, 30.0, 38.0, 72.0]


static func class_for_radius(radius: float) -> SizeClass:
	var value := maxf(radius, 0.0)
	if value <= REFERENCE_RADII[SizeClass.SMALL]:
		return SizeClass.SMALL
	if value <= REFERENCE_RADII[SizeClass.MEDIUM]:
		return SizeClass.MEDIUM
	if value <= REFERENCE_RADII[SizeClass.LARGE]:
		return SizeClass.LARGE
	return SizeClass.BOSS


static func id_for_class(size_class: SizeClass) -> StringName:
	return IDS[size_class] if size_class >= 0 and size_class < IDS.size() else &""


static func display_name(size_class: SizeClass) -> String:
	match size_class:
		SizeClass.SMALL: return "Klein"
		SizeClass.MEDIUM: return "Mittel"
		SizeClass.LARGE: return "Groß"
		SizeClass.BOSS: return "Boss"
	return "Unbekannt"


static func reference_radius(size_class: SizeClass) -> float:
	return float(REFERENCE_RADII[size_class]) if size_class >= 0 and size_class < REFERENCE_RADII.size() else 0.0


static func maximum_radius(definitions: Dictionary) -> float:
	var result := 0.0
	for value in definitions.values():
		var definition := value as EnemyDefinition
		if definition != null:
			result = maxf(result, definition.radius)
	return result
