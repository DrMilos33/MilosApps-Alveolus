class_name ArenaVisualDefinition
extends Resource

@export var level_id: StringName
@export var base_color: Color
@export var tissue_color: Color
@export var membrane_color: Color
@export var capillary_color: Color
@export var inflammation_color: Color
@export var texture_path: String
@export var seed: int
@export_range(0.0, 1.0) var inflammation_intensity: float

static func create(
	id: StringName,
	base: Color,
	tissue: Color,
	membrane: Color,
	capillary: Color,
	inflammation: Color,
	visual_seed: int,
	intensity: float,
	texture: String = "res://assets/vendor/screaming_brain_seamless_abstract/alveolar_base.png"
) -> ArenaVisualDefinition:
	var definition := ArenaVisualDefinition.new()
	definition.level_id = id
	definition.base_color = base
	definition.tissue_color = tissue
	definition.membrane_color = membrane
	definition.capillary_color = capillary
	definition.inflammation_color = inflammation
	definition.texture_path = texture
	definition.seed = visual_seed
	definition.inflammation_intensity = intensity
	return definition
