class_name UpgradeDefinition
extends Resource

enum Path {
	ANTIBIOTIC,
	IMMUNE,
	SUPPORT
}

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var path: Path
@export var max_level: int
@export var effect: StringName
@export var magnitude: float

static func create(
	definition_id: StringName,
	display_title: String,
	text: String,
	upgrade_path: Path,
	levels: int,
	effect_id: StringName,
	value: float
) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.id = definition_id
	definition.title = display_title
	definition.description = text
	definition.path = upgrade_path
	definition.max_level = levels
	definition.effect = effect_id
	definition.magnitude = value
	return definition

func path_name() -> String:
	match path:
		Path.ANTIBIOTIC:
			return "ANTIBIOTISCHE THERAPIE"
		Path.IMMUNE:
			return "IMMUNUNTERSTÜTZUNG"
		Path.SUPPORT:
			return "SUPPORTIVE THERAPIE"
	return "THERAPIE"

func accent_color() -> Color:
	match path:
		Path.ANTIBIOTIC:
			return Color("56d6c9")
		Path.IMMUNE:
			return Color("f2bd68")
		Path.SUPPORT:
			return Color("75a8ff")
	return Color.WHITE

